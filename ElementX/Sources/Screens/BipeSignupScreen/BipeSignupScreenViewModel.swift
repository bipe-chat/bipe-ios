//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import BipeKit
import SwiftUI

typealias BipeSignupScreenViewModelType = StateStoreViewModelV2<BipeSignupScreenViewState, BipeSignupScreenViewAction>

class BipeSignupScreenViewModel: BipeSignupScreenViewModelType, BipeSignupScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let authenticationService: AuthenticationServiceProtocol
    private let serverNameOrBaseURL: String
    private let userIndicatorController: UserIndicatorControllerProtocol

    private let handleChecker: BipeHandleAvailabilityChecker
    /// The email the account was created with. The login hint uses it, even if the field changes later.
    private var createdEmail: String?

    private let actionsSubject: PassthroughSubject<BipeSignupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSignupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(inviteCode: BipeInviteCode? = nil,
         apiClient: BipeAPIClient,
         authenticationService: AuthenticationServiceProtocol,
         serverNameOrBaseURL: String,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.authenticationService = authenticationService
        self.serverNameOrBaseURL = serverNameOrBaseURL
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
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
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
            state.passwordError = nil
        case .submit:
            Task { await submit() }
        }
    }

    // MARK: - Private

    private func submit() async {
        guard state.canSubmit else { return }

        if !state.isAccountCreated {
            guard await createAccount() else { return }
        }

        await startLogin()
    }

    private func createAccount() async -> Bool {
        let email = state.bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = BipeHandle.sanitize(state.bindings.handle)
        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        startLoading()
        defer { stopLoading() }

        do {
            // Unsupported (simulator): sign up without it and let the server decide. A failure on a supported device stops sign-up.
            var attestation: BipeAttestation?
            if BipeAppAttest.isSupported {
                attestation = try await BipeAppAttest.attestation(api: apiClient)
            }
            let request = BipeSignupRequest(inviteCode: state.inviteCode?.value,
                                               email: email,
                                               password: state.bindings.password,
                                               handle: handle.isEmpty ? nil : handle,
                                               displayName: displayName.isEmpty ? nil : displayName,
                                               attestation: attestation)
            let response = try await apiClient.signup(request)
            MXLog.info("Bipe sign-up created \(response.userId)")
            createdEmail = email
            state.isAccountCreated = true
            if let inviterUserID = response.inviterUserId {
                actionsSubject.send(.createdWithInvite(inviterUserID: inviterUserID))
            }
            state.bindings.password = ""
            state.bindings.passwordConfirmation = ""
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.signupSuccess, icon: \.checkCircle))
            return true
        } catch {
            MXLog.error("Bipe sign-up failed: \(error)")
            show(error)
            return false
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

    private func startLogin() async {
        guard let window = state.window else {
            MXLog.error("No window available for OAuth presentation")
            state.bindings.alertInfo = AlertInfo(id: .error)
            return
        }

        startLoading()
        defer { stopLoading() }

        guard case .success = await authenticationService.configure(for: serverNameOrBaseURL, flow: .login) else {
            state.bindings.alertInfo = AlertInfo(id: .error)
            return
        }

        // MAS (v1.26) pre-fills its login form when login_hint is a plain email address.
        switch await authenticationService.urlForOAuthLogin(loginHint: createdEmail) {
        case .success(let oAuthData):
            actionsSubject.send(.continueWithOAuth(data: oAuthData, window: window))
        case .failure:
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }

    private func show(_ error: BipeAPIError) {
        let message = error.localizedMessage

        if case .server(let code, _, _) = error {
            switch code {
            case .emailTaken:
                state.emailError = message
                return
            case .passwordWeak:
                state.passwordError = message
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
