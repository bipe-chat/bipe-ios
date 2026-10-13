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
            guard let credentials = await createAccount() else { return }
            pendingAppLockPIN = state.bindings.pin
            state.bindings.pin = ""
            state.bindings.pinConfirmation = ""
            await finishSignIn(signIn.signIn(with: credentials))
        } else if let result = await signIn.signInWithStoredPassword() {
            await finishSignIn(result)
        } else {
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }

    private func createAccount() async -> BipeCredentials? {
        let handle = BipeHandle.sanitize(state.bindings.handle)
        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = state.trimmedEmail

        do {
            // Unsupported (simulator): sign up without it and let the server decide. A failure on a supported device stops sign-up.
            var attestation: BipeAttestation?
            if BipeAppAttest.isSupported {
                attestation = try await BipeAppAttest.attestation(api: apiClient)
            }
            let request = BipeSignupRequest(inviteCode: state.inviteCode?.value,
                                            email: email.isEmpty ? nil : email,
                                            pin: state.bindings.pin,
                                            handle: handle.isEmpty ? nil : handle,
                                            displayName: displayName.isEmpty ? nil : displayName,
                                            attestation: attestation)
            let response = try await apiClient.signup(request)
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
            return credentials
        } catch {
            MXLog.error("Bipe sign-up failed: \(error)")
            show(error)
            return nil
        }
    }

    private func finishSignIn(_ result: Result<UserSessionProtocol, AuthenticationServiceError>) async {
        switch result {
        case .success(let userSession):
            if let pin = pendingAppLockPIN.take() {
                appLockService?.bipeUseAccountPIN(pin)
            }
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
