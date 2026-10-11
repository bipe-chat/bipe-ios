//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

typealias ProseioSignupScreenViewModelType = StateStoreViewModelV2<ProseioSignupScreenViewState, ProseioSignupScreenViewAction>

class ProseioSignupScreenViewModel: ProseioSignupScreenViewModelType, ProseioSignupScreenViewModelProtocol {
    private let apiClient: ProseioAPIClient
    private let authenticationService: AuthenticationServiceProtocol
    private let serverNameOrBaseURL: String
    private let userIndicatorController: UserIndicatorControllerProtocol

    private let handleChecker: ProseioHandleAvailabilityChecker
    /// The email the account was created with. The login hint uses it, even if the field changes later.
    private var createdEmail: String?

    private let actionsSubject: PassthroughSubject<ProseioSignupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioSignupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(apiClient: ProseioAPIClient,
         authenticationService: AuthenticationServiceProtocol,
         serverNameOrBaseURL: String,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.authenticationService = authenticationService
        self.serverNameOrBaseURL = serverNameOrBaseURL
        self.userIndicatorController = userIndicatorController
        handleChecker = ProseioHandleAvailabilityChecker(apiClient: apiClient)

        super.init(initialViewState: ProseioSignupScreenViewState())
    }

    override func process(viewAction: ProseioSignupScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
        case .handleChanged:
            state.handleError = nil
            handleChecker.check(state.bindings.handle) { [weak self] status in
                self?.state.handleStatus = status
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
        let handle = ProseioHandle.sanitize(state.bindings.handle)
        let displayName = state.bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = ProseioSignupRequest(email: email,
                                           password: state.bindings.password,
                                           handle: handle.isEmpty ? nil : handle,
                                           displayName: displayName.isEmpty ? nil : displayName)

        startLoading()
        defer { stopLoading() }

        do {
            let response = try await apiClient.signup(request)
            MXLog.info("Proseio sign-up created \(response.userId)")
            createdEmail = email
            state.isAccountCreated = true
            state.bindings.password = ""
            state.bindings.passwordConfirmation = ""
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.signupSuccess, icon: \.checkCircle))
            return true
        } catch {
            MXLog.error("Proseio sign-up failed: \(error)")
            show(error)
            return false
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

    private func show(_ error: ProseioAPIError) {
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
            default:
                break
            }
        }

        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: message)
    }

    // MARK: - User Indicators

    private let loadingIndicatorID = "\(ProseioSignupScreenViewModel.self)-Loading"

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
