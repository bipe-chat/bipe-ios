//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeRecoveryScreenViewModelType = StateStoreViewModelV2<BipeRecoveryScreenViewState, BipeRecoveryScreenViewAction>

/// Gets a device-first account back onto this phone (ADR 0057, ADR 0059). Each path asks for the PIN only after
/// its other factor: the synced token, or the email link.
class BipeRecoveryScreenViewModel: BipeRecoveryScreenViewModelType, BipeRecoveryScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let signIn: BipeAccountSignIn
    private let authenticationService: AuthenticationServiceProtocol
    private let serverNameOrBaseURL: String
    private let appLockService: AppLockServiceProtocol?
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var credentialStore: BipeCredentialStore {
        signIn.credentialStore
    }
    
    /// The PIN typed on this phone during this run. After the sign-in it becomes the app lock PIN.
    private var confirmedPIN: String?
    
    @CancellableTask private var pollTask: Task<Void, Never>?
    private static let pollInterval: Duration = .seconds(60)
    
    private let actionsSubject: PassthroughSubject<BipeRecoveryScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeRecoveryScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(mode: BipeRecoveryScreenMode,
         apiClient: BipeAPIClient,
         signIn: BipeAccountSignIn,
         serverNameOrBaseURL: String,
         appLockService: AppLockServiceProtocol?,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.signIn = signIn
        authenticationService = signIn.authenticationService
        self.serverNameOrBaseURL = serverNameOrBaseURL
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: BipeRecoveryScreenViewState(mode: mode, hasRecoveryToken: signIn.credentialStore.recoveryToken() != nil))
        startPollingIfWaiting()
    }
    
    override func process(viewAction: BipeRecoveryScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
        case .pinChanged:
            state.pinError = nil
            let pin = BipePIN.sanitize(state.bindings.pin)
            if pin != state.bindings.pin {
                state.bindings.pin = pin
            }
            let confirmation = BipePIN.sanitize(state.bindings.pinConfirmation)
            if confirmation != state.bindings.pinConfirmation {
                state.bindings.pinConfirmation = confirmation
            }
        case .submitPIN:
            Task { await submitPIN() }
        case .forgotPIN:
            forgotPIN()
        case .requestEmail:
            Task { await requestEmail() }
        case .loginWithQR:
            actionsSubject.send(.loginWithQR)
        case .signInWithEmail:
            Task { await signInWithEmail() }
        case .useRecoveryToken:
            guard let token = credentialStore.recoveryToken() else { return }
            switchMode(to: .token(userID: token.userID))
        case .refreshClaim:
            Task { await claim() }
        }
    }
    
    // MARK: - PIN
    
    private func submitPIN() async {
        guard state.canSubmitPIN else { return }
        let pin = state.bindings.pin
        
        switch state.mode {
        case .token(let userID):
            await recoverWithToken(pin: pin, userID: userID)
        case .emailLink(let linkToken):
            await confirmEmailLink(linkToken, pin: pin)
        case .choose, .waiting:
            break
        }
    }
    
    private func recoverWithToken(pin: String, userID: String) async {
        guard let token = credentialStore.recoveryToken(for: userID) else {
            switchMode(to: .choose)
            return
        }
        
        startLoading()
        defer { stopLoading() }
        
        do {
            let credentials = try await apiClient.recoverWithToken(token.secret, pin: pin)
            confirmedPIN = pin
            // This device's own token recovery must not alert this device.
            BipeRecoveryAlerts.acknowledgeCompletedTokenRecoveriesOnNextCheck(for: credentials.userId)
            await finishSignIn(credentials)
        } catch {
            MXLog.error("Bipe token recovery failed: \(error)")
            if case .server(.recoveryInvalid, _, _) = error {
                credentialStore.deleteRecoveryToken(for: token.userID)
                state.hasRecoveryToken = credentialStore.recoveryToken() != nil
                switchMode(to: .choose)
                state.notice = error.localizedMessage
                return
            }
            handlePINError(error)
        }
    }
    
    private func confirmEmailLink(_ linkToken: BipeRecoveryLinkToken, pin: String) async {
        startLoading()
        defer { stopLoading() }
        
        do {
            let started = try await apiClient.confirmRecoveryEmail(linkToken: linkToken.value,
                                                                   pin: state.isNewPIN ? nil : pin,
                                                                   newPIN: state.isNewPIN ? pin : nil)
            credentialStore.savePendingRecovery(started)
            confirmedPIN = pin
            switchMode(to: .waiting(started))
        } catch {
            MXLog.error("Bipe email recovery confirm failed: \(error)")
            if case .server(.recoveryInvalid, _, _) = error {
                switchMode(to: .choose)
                state.notice = BipeStrings.emailLinkInvalid
                return
            }
            handlePINError(error)
        }
    }
    
    private func handlePINError(_ error: BipeAPIError) {
        state.bindings.pin = ""
        state.bindings.pinConfirmation = ""
        switch error {
        case .server(.pinBlocked, _, _):
            state.isPINBlocked = true
            state.pinError = BipeStrings.pinBlockedBody(String(BipeRegistries.pinMaxWrongTries))
        case .server(.pinWrong, _, _), .server(.pinWeak, _, _):
            state.pinError = error.localizedMessage
        default:
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    /// A blocked or forgotten PIN: the email link sets a new one, after the safety wait.
    private func forgotPIN() {
        if case .emailLink = state.mode {
            state.isNewPIN = true
            state.isPINBlocked = false
            state.pinError = nil
            state.bindings.pin = ""
            state.bindings.pinConfirmation = ""
        } else {
            switchMode(to: .choose)
        }
    }
    
    // MARK: - Email
    
    private func requestEmail() async {
        guard state.canRequestEmail else { return }
        
        startLoading()
        defer { stopLoading() }
        
        do {
            try await apiClient.requestRecoveryEmail(state.bindings.email.trimmingCharacters(in: .whitespacesAndNewlines))
            state.emailSent = true
        } catch {
            MXLog.error("Bipe recovery email request failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    // MARK: - Waiting
    
    private func startPollingIfWaiting() {
        guard case .waiting = state.mode else {
            pollTask = nil
            return
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.claim()
                guard self != nil else { return }
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }
    
    private func claim() async {
        guard case .waiting(let recovery) = state.mode else { return }
        
        let result: BipeRecoveryClaim
        do {
            result = try await apiClient.claimRecovery(id: recovery.recoveryId, claimSecret: recovery.claimSecret)
        } catch {
            if case .server(.recoveryInvalid, _, _) = error {
                endRecovery(notice: BipeStrings.errorRecoveryInvalid)
            }
            MXLog.error("Bipe recovery claim failed: \(error)")
            return
        }
        
        switch (result.state, result.purpose) {
        case (.waiting, _):
            break
        case (.completed, .access):
            guard let credentials = result.credentials else {
                endRecovery(notice: BipeStrings.errorRecoveryInvalid)
                return
            }
            credentialStore.deletePendingRecovery()
            pollTask = nil
            startLoading()
            defer { stopLoading() }
            await finishSignIn(credentials)
        case (.completed, .pinReset):
            endRecovery(notice: BipeStrings.recoveryPinReady)
        case (.cancelled, _):
            endRecovery(notice: BipeStrings.recoveryCancelled)
        case (.expired, _):
            endRecovery(notice: BipeStrings.errorRecoveryInvalid)
        }
    }
    
    private func endRecovery(notice: String) {
        credentialStore.deletePendingRecovery()
        if let token = credentialStore.recoveryToken() {
            switchMode(to: .token(userID: token.userID))
        } else {
            switchMode(to: .choose)
        }
        state.notice = notice
    }
    
    // MARK: - Beta accounts
    
    /// A beta account (email and own password) signs in through MAS, as before. Settings then offer the move to a PIN.
    private func signInWithEmail() async {
        guard let window = state.window else {
            state.bindings.alertInfo = AlertInfo(id: .error)
            return
        }
        
        startLoading()
        defer { stopLoading() }
        
        guard case .success = await authenticationService.configure(for: serverNameOrBaseURL, flow: .login),
              case .success(let data) = await authenticationService.urlForOAuthLogin(loginHint: nil) else {
            state.bindings.alertInfo = AlertInfo(id: .error)
            return
        }
        actionsSubject.send(.continueWithOAuth(data: data, window: window))
    }
    
    // MARK: - Common
    
    private func finishSignIn(_ credentials: BipeCredentials) async {
        switch await signIn.signIn(with: credentials) {
        case .success(let userSession):
            if let pin = confirmedPIN.take() {
                appLockService?.bipeUseAccountPIN(pin)
            }
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.recoveryReady, icon: \.checkCircle))
            actionsSubject.send(.signedIn(userSession))
        case .failure(let error):
            MXLog.error("Bipe sign-in after recovery failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error)
        }
    }
    
    private func switchMode(to mode: BipeRecoveryScreenMode) {
        state.mode = mode
        state.notice = nil
        state.pinError = nil
        state.isNewPIN = false
        state.isPINBlocked = false
        state.bindings.pin = ""
        state.bindings.pinConfirmation = ""
        startPollingIfWaiting()
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(BipeRecoveryScreenViewModel.self)-Loading"
    
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
