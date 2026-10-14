//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import BipeKit
import SwiftUI

typealias BipeSignupScreenViewModelType = StateStoreViewModelV2<BipeSignupScreenViewState, BipeSignupScreenViewAction>

/// Device-first sign-up (ADR 0057, ADR 0059): name, optional handle and email, invite, App Attest and an 8-digit PIN.
/// The API returns a hidden password and a recovery token once. The app keeps both in the keychain and signs in
/// with the password (`m.login.password`), so no browser opens.
class BipeSignupScreenViewModel: BipeSignupScreenViewModelType, BipeSignupScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let signIn: BipeAccountSignIn
    private let appLockService: AppLockServiceProtocol?
    private let userIndicatorController: UserIndicatorControllerProtocol

    private let handleChecker: BipeHandleAvailabilityChecker
    /// The new account's PIN, kept in memory until the sign-in succeeds. Then it becomes the app lock PIN.
    private var pendingAppLockPIN: String?

    private let actionsSubject: PassthroughSubject<BipeSignupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSignupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(inviteCode: BipeInviteCode? = nil,
         apiClient: BipeAPIClient,
         signIn: BipeAccountSignIn,
         appLockService: AppLockServiceProtocol?,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.signIn = signIn
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController
        handleChecker = BipeHandleAvailabilityChecker(apiClient: apiClient)

        var initialState = BipeSignupScreenViewState()
        initialState.bindings.inviteCode = inviteCode?.value ?? ""
        super.init(initialViewState: initialState)

        if let inviteCode {
            Task { await loadInvitePreview(inviteCode) }
        }
    }

    override func process(viewAction: BipeSignupScreenViewAction) {
        switch viewAction {
        case .handleChanged:
            state.handleError = nil
            handleChecker.check(state.bindings.handle) { [weak self] status in
                self?.state.handleStatus = status
            }
        case .inviteCodeChanged:
            state.inviteCodeError = nil
            state.inviterHandle = nil
            // A pasted link or message becomes the bare code; a complete code shows who invited.
            if let code = state.inviteCode {
                if state.bindings.inviteCode != code.value { state.bindings.inviteCode = code.value }
                Task { await loadInvitePreview(code) }
            }
        case .clearFieldErrors:
            state.emailError = nil
            state.pinError = nil
            let pin = BipePIN.sanitize(state.bindings.pin)
            if pin != state.bindings.pin { state.bindings.pin = pin }
            let confirmation = BipePIN.sanitize(state.bindings.pinConfirmation)
            if confirmation != state.bindings.pinConfirmation { state.bindings.pinConfirmation = confirmation }
        case .submit:
            Task { await submit() }
        }
    }

    // MARK: - Private

    private func submit() async {
        guard state.canSubmit else { return }

        startLoading()
        defer { stopLoading() }

        if !state.isAccountCreated {
            guard let (credentials, pin) = await createAccount() else { return }
            pendingAppLockPIN = pin
            state.bindings.pin = ""
            state.bindings.pinConfirmation = ""
            await finishSignIn(signIn.signIn(with: credentials))
        } else if let result = await signIn.signInWithStoredPassword() {
            await finishSignIn(result)
        } else {
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }

    /// The new account's credentials and the PIN it really has. On a retry after a lost answer the server returns the
    /// account of the first try (ADR 0094), so the PIN is the one that try sent.
    private func createAccount() async -> (BipeCredentials, String)? {
        let handle = BipeHandle.sanitize(state.bindings.handle)
        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = state.trimmedEmail
        let credentialStore = signIn.credentialStore
        // Stored before the first request goes out, so a lost answer can be fetched again (ADR 0094).
        var pending = credentialStore.pendingSignup(pin: state.bindings.pin)
        if pending.pin == nil {
            credentialStore.updatePendingSignupPIN(state.bindings.pin)
            pending.pin = state.bindings.pin
        }
        let pin = pending.pin ?? state.bindings.pin

        do {
            let response = try await signupRetryingLostAnswers { () async throws(BipeAPIError) -> BipeSignupRequest in
                // A new attestation for every try: the server spends each challenge once.
                // Unsupported (simulator): sign up without it and let the server decide. A failure on a supported device stops sign-up.
                var attestation: BipeAttestation?
                if BipeAppAttest.isSupported {
                    attestation = try await BipeAppAttest.attestation(api: apiClient)
                }
                return BipeSignupRequest(inviteCode: state.inviteCode?.value,
                                         email: email.isEmpty ? nil : email,
                                         pin: pin,
                                         handle: handle.isEmpty ? nil : handle,
                                         displayName: displayName.isEmpty ? nil : displayName,
                                         attestation: attestation,
                                         signupKey: pending.key)
            }
            MXLog.info("Bipe sign-up created \(response.userId)")
            guard let credentials = response.credentials else {
                MXLog.error("Bipe sign-up returned no device-first credentials")
                state.bindings.alertInfo = AlertInfo(id: .error)
                return nil
            }
            state.isAccountCreated = true
            if let inviterUserID = response.inviterUserId {
                actionsSubject.send(.createdWithInvite(inviterUserID: inviterUserID))
            }
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.signupDeviceSuccess, icon: \.checkCircle))
            return (credentials, pin)
        } catch {
            MXLog.error("Bipe sign-up failed: \(error)")
            if case .server(let code, let reason, _) = error, !(code == .rateLimited && reason == "signup_in_progress") {
                // The server answered and made nothing, so the next try takes the PIN from the form again.
                credentialStore.updatePendingSignupPIN(nil)
            }
            show(error)
            return nil
        }
    }

    /// Mobile data drops often. A try without an answer may still have made the account, and the same key returns it,
    /// so a few quiet retries are safe (ADR 0094).
    private func signupRetryingLostAnswers(_ makeRequest: () async throws(BipeAPIError) -> BipeSignupRequest) async throws(BipeAPIError) -> BipeSignupResponse {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await apiClient.signup(makeRequest())
            } catch {
                let retryable = switch error {
                case .network, .unexpectedResponse: true
                case .server(.rateLimited, let reason, _): reason == "signup_in_progress"
                case .server(.internal, _, _): true
                default: false
                }
                guard retryable, attempt < 4 else { throw error }
                MXLog.info("Bipe sign-up try \(attempt) got no answer, trying again")
                try? await Task.sleep(for: .seconds(2 * attempt))
            }
        }
    }

    private func finishSignIn(_ result: Result<UserSessionProtocol, AuthenticationServiceError>) async {
        switch result {
        case .success(let userSession):
            if let pin = pendingAppLockPIN.take() {
                appLockService?.bipeUseAccountPIN(pin)
            }
            signIn.credentialStore.deletePendingSignup()
            actionsSubject.send(.signedIn(userSession))
        case .failure(let error):
            MXLog.error("Bipe sign-in after sign-up failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }

    /// Shows who invited the user, or marks a code that no longer works. Failures stay silent: sign-up checks the code again.
    private func loadInvitePreview(_ code: BipeInviteCode) async {
        guard let preview = try? await apiClient.invitePreview(code: code.value) else { return }
        guard state.inviteCode == code else { return }
        if preview.valid {
            state.inviterHandle = preview.inviterHandle
        } else {
            state.inviteCodeError = BipeStrings.errorInviteInvalid
        }
    }

    private func show(_ error: BipeAPIError) {
        let message = error.localizedMessage

        if case .server(let code, _, _) = error {
            switch code {
            case .emailTaken:
                state.emailError = message
                return
            case .pinWeak:
                state.pinError = message
                return
            case .handleTaken, .handleInvalid:
                state.handleError = message
                return
            case .inviteInvalid:
                state.inviteCodeError = message
                return
            default:
                break
            }
        }

        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: message)
    }

    // MARK: - User Indicators

    private let loadingIndicatorID = "\(BipeSignupScreenViewModel.self)-Loading"

    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }

    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
}
