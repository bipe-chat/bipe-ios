//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import SwiftUI

typealias AuthenticationStartScreenViewModelType = StateStoreViewModelV2<AuthenticationStartScreenViewState, AuthenticationStartScreenViewAction>

class AuthenticationStartScreenViewModel: AuthenticationStartScreenViewModelType, AuthenticationStartScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let provisioningParameters: AccountProvisioningParameters?
    private let appMediator: AppMediatorProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let canReportProblem: Bool
    private let bipePendingInviteCode: BipeInviteCode?
    private let bipeAPIClient: BipeAPIClient?
    
    private var actionsSubject: PassthroughSubject<AuthenticationStartScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<AuthenticationStartScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(authenticationService: AuthenticationServiceProtocol,
         provisioningParameters: AccountProvisioningParameters?,
         isBugReportServiceEnabled: Bool,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         mediaProvider: MediaProviderProtocol?,
         notificationCenter: NotificationCenter = .default,
         userIndicatorController: UserIndicatorControllerProtocol,
         bipePendingInviteCode: BipeInviteCode? = nil,
         bipeAPIClient: BipeAPIClient? = nil) {
        self.authenticationService = authenticationService
        self.provisioningParameters = provisioningParameters
        self.appMediator = appMediator
        self.userIndicatorController = userIndicatorController
        canReportProblem = isBugReportServiceEnabled
        self.bipePendingInviteCode = bipePendingInviteCode
        self.bipeAPIClient = bipeAPIClient
        
        let isQRCodeScanningSupported = !ProcessInfo.processInfo.isiOSAppOnMac
        let isClassicAppAccountAllowed = if let classicAppAccount = authenticationService.classicAppAccount {
            appSettings.accountProviders.contains(serverName: classicAppAccount.serverName, orBaseURL: classicAppAccount.homeserverURL)
        } else {
            false
        }
        
        let initialViewState = if !appSettings.allowOtherAccountProviders {
            // We don't show the create account button when custom providers are disallowed.
            // The assumption here being that if you're running a custom app, your users will already be created.
            AuthenticationStartScreenViewState(serverNameOrBaseURL: appSettings.accountProviders.count == 1 ? appSettings.accountProviders[0].serverNameOrBaseURL : nil,
                                               showCreateAccountButton: appSettings.usesBipeSignup, // Bipe: invite sign-up
                                               showQRCodeLoginButton: isQRCodeScanningSupported && !appSettings.usesBipeSignup, // Bipe: QR is on the recovery screen
                                               classicAppMode: isClassicAppAccountAllowed ? authenticationService.classicAppAccount.map { .welcomeBack($0) } : nil,
                                               hideBrandChrome: appSettings.hideBrandChrome)
        } else if let provisioningParameters {
            // We only show the "Sign in to …" button when using a provisioning link.
            AuthenticationStartScreenViewState(serverNameOrBaseURL: provisioningParameters.accountProvider,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: false,
                                               classicAppMode: nil,
                                               hideBrandChrome: appSettings.hideBrandChrome)
        } else {
            // The default configuration.
            AuthenticationStartScreenViewState(serverNameOrBaseURL: nil,
                                               showCreateAccountButton: appSettings.showCreateAccountButton,
                                               showQRCodeLoginButton: isQRCodeScanningSupported,
                                               classicAppMode: authenticationService.classicAppAccount.map { .welcomeBack($0) },
                                               hideBrandChrome: appSettings.hideBrandChrome)
        }
        
        var bipeViewState = initialViewState
        if appSettings.usesBipeSignup {
            // Bipe ADR 0057: no login screen. The button opens the ways back into an account.
            bipeViewState.bipeLoginButtonTitle = BipeStrings.recoveryTitle
            // ADR 0072: an invite is required until the server says otherwise.
            bipeViewState.bipeStart = .variant(invitePending: bipePendingInviteCode != nil, inviteRequired: true)
        }
        super.init(initialViewState: bipeViewState, mediaProvider: mediaProvider)
        
        if appSettings.usesBipeSignup {
            Task { await loadBipeSignupMode() }
            Task { await detectBipePastedInvite() }
        }
        
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.reloadClassicAppAccount()
                if appSettings.usesBipeSignup {
                    Task { await self?.detectBipePastedInvite() }
                }
            }
            .store(in: &cancellables)
    }
    
    override func process(viewAction: AuthenticationStartScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
        case .reportProblem:
            if canReportProblem {
                actionsSubject.send(.reportProblem)
            }
        case .developerOptions:
            actionsSubject.send(.developerOptions)
            
        case .loginWithQR:
            actionsSubject.send(.loginWithQR)
        case .login:
            Task { await login() }
        case .register:
            actionsSubject.send(.register)
        case .bipe(let target):
            switch target {
            case .recovery:
                actionsSubject.send(.login)
            case .inviteCode:
                actionsSubject.send(.bipeSignup(startsWithInviteCode: true))
            case .name:
                actionsSubject.send(.bipeSignup(startsWithInviteCode: false))
            default:
                MXLog.error("Unexpected start screen target: \(target)")
            }
        case .bipePaste(let strings):
            if let code = strings.lazy.compactMap(BipeInviteCode.init).first {
                actionsSubject.send(.bipeInvitePasted(code))
            } else {
                state.bipePastedNoInvite = true
            }
            
        case .continueWithClassic(let account):
            Task { await login(classicAppAccount: account) }
        case .otherOptions(let account):
            state.classicAppMode = .otherOptions(account)
        case .closeOtherOptions(let account):
            state.classicAppMode = .welcomeBack(account)
        case .openClassicApp:
            guard let classicAppDeepLinkURL = InfoPlistReader.main.classicAppDeepLinkURL else { return }
            appMediator.open(classicAppDeepLinkURL)
        }
    }
    
    // MARK: - Private
    
    /// bipe#197: the invite page copies the invite link before it opens the App Store or TestFlight.
    /// `detectPatterns` does not read the pasteboard, so iOS shows no paste alert. Only the system paste button reads it.
    private func detectBipePastedInvite() async {
        guard bipePendingInviteCode == nil else { return }
        let patterns = try? await UIPasteboard.general.detectPatterns(for: [\UIPasteboard.DetectedValues.probableWebURL])
        state.bipeOffersPasteInvite = patterns?.contains(\UIPasteboard.DetectedValues.probableWebURL) == true
    }
    
    /// The start screen variant follows the server's sign-up mode (ADR 0072) and shows who invited.
    /// A failed read keeps the invite-first variant.
    private func loadBipeSignupMode() async {
        guard let bipeAPIClient else { return }
        if let code = bipePendingInviteCode, let preview = try? await bipeAPIClient.invitePreview(code: code.value), preview.valid {
            state.bipeInviterHandle = preview.inviterHandle
        }
        if let config = try? await bipeAPIClient.signupConfig() {
            state.bipeStart = .variant(invitePending: bipePendingInviteCode != nil, inviteRequired: config.inviteRequired)
        }
    }
    
    private func login(classicAppAccount: ClassicAppAccount? = nil) async {
        if let classicAppAccount {
            if classicAppAccount.state.availableSecrets == .requiresBackup {
                state.bindings.showClassicAppBackupInstructions = true
            } else {
                await loginDirectly(using: classicAppAccount.serverName,
                                    loginHint: "mxid:\(classicAppAccount.userID)",
                                    fallbackHomeserverURL: classicAppAccount.homeserverURL)
            }
        } else if state.bipeLoginButtonTitle != nil {
            actionsSubject.send(.login) // Bipe: the flow coordinator opens the recovery screen.
        } else if let serverNameOrBaseURL = state.serverNameOrBaseURL {
            await loginDirectly(using: serverNameOrBaseURL, loginHint: provisioningParameters?.loginHint)
        } else {
            actionsSubject.send(.login) // No need to configure anything here, continue the flow.
        }
    }
    
    private func loginDirectly(using serverNameOrBaseURL: String, loginHint: String? = nil, fallbackHomeserverURL: URL? = nil) async {
        startLoading()
        defer { stopLoading() }
        
        if case .failure = await authenticationService.configure(for: serverNameOrBaseURL, flow: .login) {
            // Try the fallback URL before showing an error.
            if let fallbackHomeserverURL,
               case .success = await authenticationService.configure(for: fallbackHomeserverURL.absoluteString, flow: .login) {
                // Fallback succeeded, continue with the flow.
            } else {
                // As the server was provisioned, we don't worry about the specifics and show a generic error to the user.
                // Element Classic accounts aren't shown for unsupported servers either, so nothing to do here.
                displayError()
                return
            }
        }
        
        guard authenticationService.homeserver.value.loginMode.supportsOAuthFlow else {
            actionsSubject.send(.loginDirectlyWithPassword(loginHint: loginHint))
            return
        }
        
        guard let window = state.window else {
            displayError()
            return
        }
        
        switch await authenticationService.urlForOAuthLogin(loginHint: loginHint) {
        case .success(let oAuthData):
            actionsSubject.send(.loginDirectlyWithOAuth(data: oAuthData, window: window))
        case .failure:
            displayError()
        }
    }
    
    @CancellableTask private var reloadClassicAppSecretsTask: Task<Void, Never>?
    private func reloadClassicAppAccount() {
        guard case let .welcomeBack(classicAppAccount) = state.classicAppMode else { return }
        
        reloadClassicAppSecretsTask = Task { [weak self] in
            await self?.authenticationService.refreshClassicAppAccountState()
            
            guard !Task.isCancelled else { return }
            
            if let availableSecrets = classicAppAccount.state.availableSecrets, availableSecrets != .requiresBackup {
                await MainActor.run { self?.state.bindings.showClassicAppBackupInstructions = false }
            }
        }
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(AuthenticationStartScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .genericError)
    }
}
