//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeSignupScreenViewModelType = StateStoreViewModelV2<BipeSignupScreenViewState, BipeSignupScreenViewAction>

/// Device-first sign-up (ADR 0057, ADR 0059) in the steps of bipe-shared `registries/onboarding.json` (bipe#415):
/// the invite code (unless a link brought it), the name and terms, an 8-digit PIN, then the fallback prompt.
/// The @ comes later (bipe#200). App Attest runs when the account is created.
/// The API returns a hidden password and a recovery token once. The app keeps both in the keychain and signs in
/// with the password (`m.login.password`), so no browser opens.
class BipeSignupScreenViewModel: BipeSignupScreenViewModelType, BipeSignupScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let signIn: BipeAccountSignIn
    private let appLockService: AppLockServiceProtocol?
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    /// The new account's PIN, kept in memory until the sign-in succeeds. Then it becomes the app lock PIN.
    private var pendingAppLockPIN: String?
    /// The new account's credentials, kept in memory until the sign-in succeeds.
    private var createdCredentials: BipeCredentials?
    
    private let actionsSubject: PassthroughSubject<BipeSignupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSignupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(inviteCode: BipeInviteCode? = nil,
         startsWithInviteCode: Bool = true,
         apiClient: BipeAPIClient,
         signIn: BipeAccountSignIn,
         appLockService: AppLockServiceProtocol?,
         userIndicatorController: UserIndicatorControllerProtocol,
         accountType: BipeAccountType = .personal) {
        self.apiClient = apiClient
        self.signIn = signIn
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController
        
        let site = signIn.appSettings.websiteURL
        var initialState = BipeSignupScreenViewState(termsURL: BipeLegalLinks.termsURL(site: site),
                                                     privacyURL: BipeLegalLinks.privacyURL(site: site),
                                                     firstStep: inviteCode == nil && startsWithInviteCode ? .inviteCode : .name)
        initialState.bindings.inviteCode = inviteCode?.value ?? ""
        initialState.isCompany = accountType == .company
        super.init(initialViewState: initialState)
        
        if let inviteCode {
            Task { await loadInvitePreview(inviteCode) }
        }
        Task { await loadSignupConfig() }
    }
    
    override func process(viewAction: BipeSignupScreenViewAction) {
        switch viewAction {
        case .inviteCodeChanged:
            state.inviteCodeError = nil
            state.inviterHandle = nil
            // A pasted link or message becomes the bare code; a complete code shows who invited.
            if let code = state.inviteCode {
                if state.bindings.inviteCode != code.value {
                    state.bindings.inviteCode = code.value
                }
                Task { await loadInvitePreview(code) }
            }
        case .clearFieldErrors:
            state.emailError = nil
            state.pinError = nil
            let pin = BipePIN.sanitize(state.bindings.pin)
            if pin != state.bindings.pin {
                state.bindings.pin = pin
            }
            let confirmation = BipePIN.sanitize(state.bindings.pinConfirmation)
            if confirmation != state.bindings.pinConfirmation {
                state.bindings.pinConfirmation = confirmation
            }
        case .primary:
            continueStep()
        case .text(let target):
            switch target {
            case .waitlist:
                state.bindings.isWaitlistPresented = true
            case .create:
                // Fallback "Agora não": the account without an email.
                state.bindings.email = ""
                state.isFallbackEmailOpen = false
                Task { await submit() }
            default:
                MXLog.error("Unexpected sign-up text button: \(target)")
            }
        case .back:
            let steps = BipeOnboardingStep.allCases
            guard let index = steps.firstIndex(of: state.step), state.step != state.firstStep, index > 0 else { return }
            state.step = steps[index - 1]
        case .joinWaitlist:
            Task { await joinWaitlist() }
        }
    }
    
    // MARK: - Private
    
    private func continueStep() {
        switch state.step {
        case .inviteCode:
            guard state.canContinueInviteCode else { return }
            state.step = .name
        case .name:
            guard state.canContinueName else { return }
            state.step = .pin
        case .pin:
            guard state.isPINValid else { return }
            BipeHaptics.play(.success)
            if state.isAccountCreated {
                Task { await submit() }
            } else {
                state.step = .fallback
            }
        case .fallback:
            if state.isAccountCreated {
                Task { await submit() }
            } else if !state.isFallbackEmailOpen {
                state.isFallbackEmailOpen = true
            } else if state.canSubmitFallbackEmail {
                Task { await submit() }
            }
        }
    }
    
    private func joinWaitlist() async {
        guard state.canJoinWaitlist else { return }
        state.waitlistError = nil
        let email = state.bindings.waitlistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = Locale.current.language.languageCode == .english ? "en" : "pt"
        startLoading()
        defer { stopLoading() }
        do {
            try await apiClient.joinWaitlist(email: email, lang: lang)
            state.isWaitlistJoined = true
        } catch {
            MXLog.error("Bipe waitlist failed: \(error)")
            state.waitlistError = error.localizedMessage
        }
    }
    
    private func submit() async {
        guard state.canSubmit else { return }
        
        startLoading()
        defer { stopLoading() }
        
        if !state.isAccountCreated {
            guard let (credentials, pin) = await createAccount() else { return }
            createdCredentials = credentials
            pendingAppLockPIN = pin
            state.bindings.pin = ""
            state.bindings.pinConfirmation = ""
            await finishSignIn(signIn.signIn(with: credentials))
        } else if let result = await signIn.signInWithStoredPassword() {
            await finishSignIn(result)
        } else if let credentials = createdCredentials {
            // The keychain did not keep the password: sign in with the copy in memory.
            await finishSignIn(signIn.signIn(with: credentials))
        } else {
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }
    
    /// The new account's credentials and the PIN it really has. On a retry after a lost answer the server returns the
    /// account of the first try (ADR 0094), so the PIN is the one that try sent.
    private func createAccount() async -> (BipeCredentials, String)? {
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
        if pin != state.bindings.pin {
            // The first try may have made the account with that PIN, so it stays the PIN.
            MXLog.info("Bipe sign-up uses the PIN of the first try")
            state.bindings.pin = pin
            state.bindings.pinConfirmation = pin
        }
        
        do {
            let response = try await signupRetryingLostAnswers { () async throws(BipeAPIError) -> BipeSignupRequest in
                // A new attestation for every try: the server spends each challenge once.
                // Unsupported (simulator): sign up without it and let the server decide. A failure on a supported device stops sign-up.
                var attestation: BipeAttestation?
                if BipeAppAttest.isSupported {
                    attestation = try await BipeAppAttest.attestationUnlessServiceDown(api: apiClient)
                }
                return BipeSignupRequest(inviteCode: state.inviteCode?.value,
                                         email: email.isEmpty ? nil : email,
                                         pin: pin,
                                         handle: nil,
                                         displayName: displayName.isEmpty ? nil : displayName,
                                         attestation: attestation,
                                         signupKey: pending.key,
                                         termsVersion: state.bindings.isTermsAccepted ? BipeRegistries.legalVersion : nil,
                                         accountType: state.isCompany ? .company : nil)
            }
            MXLog.info("Bipe sign-up created \(response.userId)")
            BipeAccountLabels.rememberCompany(state.isCompany, for: response.userId)
            guard let credentials = response.credentials else {
                MXLog.error("Bipe sign-up returned no device-first credentials")
                state.bindings.alertInfo = AlertInfo(id: .error)
                return nil
            }
            state.isAccountCreated = true
            if let inviterUserID = response.inviterUserId {
                actionsSubject.send(.createdWithInvite(inviterUserID: inviterUserID, inviterHandle: state.inviterHandle))
            }
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.signupDeviceSuccess, icon: \.checkCircle))
            return (credentials, pin)
        } catch {
            MXLog.error("Bipe sign-up failed: \(error)")
            if case .server(let code, _, _) = error, code != .rateLimited, code != .internal {
                // A field error: the server made nothing, so the next try takes the PIN from the form again.
                // A limit or a server failure proves nothing, so the PIN of the first try stays.
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
            createdCredentials = nil
            if let pin = pendingAppLockPIN.take() {
                appLockService?.bipeUseAccountPIN(pin)
            }
            if signIn.credentialStore.password() != nil {
                signIn.credentialStore.deletePendingSignup()
            }
            actionsSubject.send(.signedIn(userSession))
        case .failure(let error):
            MXLog.error("Bipe sign-in after sign-up failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: BipeStrings.signupSigninFailed)
        }
    }
    
    /// An error keeps the default: an invite is required (ADR 0072). An open server skips an empty code step.
    private func loadSignupConfig() async {
        guard let config = try? await apiClient.signupConfig() else { return }
        state.isInviteRequired = config.inviteRequired
        if !config.inviteRequired, state.step == .inviteCode, state.isInviteCodeEmpty {
            state.step = .name
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
            // A field error opens the step that holds the field.
            case .emailTaken:
                state.emailError = message
                state.step = .fallback
                state.isFallbackEmailOpen = true
                return
            case .pinWeak:
                state.pinError = message
                state.step = .pin
                return
            case .inviteInvalid:
                state.inviteCodeError = message
                state.step = .inviteCode
                return
            case .termsRequired:
                // The alert below says why; the name step holds the checkbox.
                state.step = .name
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
