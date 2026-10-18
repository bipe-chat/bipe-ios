//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import SwiftState
import SwiftUI

protocol AuthenticationFlowCoordinatorDelegate: AnyObject {
    func authenticationFlowCoordinator(didLoginWithSession userSession: UserSessionProtocol)
    /// Bipe: the add-account sheet was closed without a sign-in (ADR 0086, bipe#267).
    func authenticationFlowCoordinatorDidCancelAddingAccount()
}

class AuthenticationFlowCoordinator: FlowCoordinatorProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let bugReportService: BugReportServiceProtocol
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let navigationStackCoordinator: NavigationStackCoordinator
    private let appMediator: AppMediatorProtocol
    private let appSettings: AppSettings
    private let homeserverHistoryManager: HomeserverHistoryManager
    private let appHooks: AppHooks
    private let userIndicatorController: UserIndicatorControllerProtocol
    /// Bipe: the account PIN also locks the app (ADR 0057).
    private let appLockService: AppLockServiceProtocol?
    /// Bipe: adding an account from a signed-in session shows the flow as a sheet over it, with no silent sign-in (ADR 0086).
    private let isAddingAccount: Bool
    /// Bipe: "Criar conta da empresa" goes straight to the sign-up as a company (ADR 0087).
    private let bipeAccountType: BipeAccountType
    
    enum State: StateType {
        /// The state machine hasn't started.
        case initial
        
        /// The initial screen shown when you first launch the app.
        case startScreen
        
        /// The screen used for the whole QR Code flow.
        case qrCodeLoginScreen
        
        /// The screen used to choose a server
        case serverSelectionScreen
        
        /// The screen to login with a password.
        case loginScreen
        
        /// Bipe: invite-based sign-up through the Bipe API.
        case bipeSignupScreen
        /// Bipe: the ways back into a device-first account (ADR 0057).
        case bipeRecoveryScreen
        
        /// The screen to report an error.
        case bugReportFlow
        /// The screen to toggle feature flags.
        case developerOptions
        
        /// The flow is complete.
        case complete
    }
    
    enum Event: EventType {
        /// The flow is being started.
        case start
        
        /// Modify the flow using the provisioning parameters in the `userInfo`.
        case applyProvisioningParameters
        
        /// The user would like to login with a QR code.
        case loginWithQR
        /// Show the server confirmation screen.
        case selectServer(AuthenticationFlow)
        
        /// The QR login flow was aborted.
        case cancelledLoginWithQR
        /// The user aborted manual login.
        case cancelledServerSelection
        
        /// Show the screen to login with password (with the optional login hint in the `userInfo`).
        case continueWithPassword
        /// The password login was aborted.
        case cancelledPasswordLogin(previousState: State)
        
        /// Bipe: show the invite sign-up screen.
        case bipeSignup
        /// Bipe: the invite sign-up was aborted.
        case cancelledBipeSignup
        /// Bipe: show the recovery screen. The user info is a `BipeRecoveryScreenMode`.
        case bipeRecovery
        /// Bipe: the recovery screen was closed.
        case cancelledBipeRecovery
        
        /// The user encountered a problem.
        case reportProblem
        /// The user has finished reporting a problem (or viewing the logs).
        case bugReportFlowComplete
        
        /// The user wants to toggle a feature flag.
        case developerOptions
        /// The user finished toggling feature flags.
        case dismissedDeveloperOptions
        
        /// The user has successfully signed in. The new session can be found in the `userInfo`.
        case signedIn
    }
    
    private let stateMachine: StateMachine<State, Event>
    private var cancellables = Set<AnyCancellable>()
    
    private var oAuthPresenter: OAuthAuthenticationPresenter?
    /// Bipe: the code from an invite link. The start screen shows who invited; sign-up skips the code step.
    private var pendingInviteCode: BipeInviteCode?
    /// Bipe: false when the start screen's button goes straight to the name (bipe#415).
    private var bipeSignupStartsWithInviteCode = true
    
    // periphery:ignore - retaining purpose
    private var bugReportFlowCoordinator: BugReportFlowCoordinator?
    
    weak var delegate: AuthenticationFlowCoordinatorDelegate?
    
    init(authenticationService: AuthenticationServiceProtocol,
         bugReportService: BugReportServiceProtocol,
         navigationRootCoordinator: NavigationRootCoordinator,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         appHooks: AppHooks,
         userIndicatorController: UserIndicatorControllerProtocol,
         appLockService: AppLockServiceProtocol? = nil,
         isAddingAccount: Bool = false,
         bipeAccountType: BipeAccountType = .personal) {
        self.authenticationService = authenticationService
        self.appLockService = appLockService
        self.isAddingAccount = isAddingAccount
        self.bipeAccountType = bipeAccountType
        self.bugReportService = bugReportService
        self.navigationRootCoordinator = navigationRootCoordinator
        self.appMediator = appMediator
        self.appSettings = appSettings
        homeserverHistoryManager = HomeserverHistoryManager(appSettings: appSettings)
        self.appHooks = appHooks
        self.userIndicatorController = userIndicatorController
        
        navigationStackCoordinator = NavigationStackCoordinator()
        
        stateMachine = .init(state: .initial)
        configureStateMachine()
    }
    
    func start(animated: Bool) {
        stateMachine.tryEvent(.start)
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        MXLog.info("Handling app route: \(appRoute)")
        
        switch appRoute {
        case .accountProvisioningLink(let provisioningParameters):
            guard appSettings.allowOtherAccountProviders else {
                MXLog.error("Provisioning links not allowed, ignoring.")
                return
            }
            
            if stateMachine.state != .startScreen {
                clearRoute(animated: animated)
            }
            
            stateMachine.tryEvent(.applyProvisioningParameters, userInfo: provisioningParameters)
        case .bipeInvite(let code):
            guard appSettings.usesBipeSignup else { return }
            pendingInviteCode = code
            if stateMachine.state != .startScreen {
                clearRoute(animated: animated)
            }
            // bipe#415: the start screen says who invited, with "Entrar com o convite" as its one filled button.
            if stateMachine.state == .startScreen {
                showStartScreen(fromState: .startScreen)
            }
        case .bipeRecoveryLink(let token):
            guard appSettings.usesBipeSignup else { return }
            if stateMachine.state != .startScreen {
                clearRoute(animated: animated)
            }
            stateMachine.tryEvent(.bipeRecovery, userInfo: BipeRecoveryScreenMode.emailLink(token))
        default:
            fatalError()
        }
    }
    
    func clearRoute(animated: Bool) {
        oAuthPresenter?.cancel() // Handle ongoing OAuth authentication first.
        
        switch stateMachine.state {
        case .initial, .startScreen:
            break
        case .qrCodeLoginScreen:
            navigationStackCoordinator.setSheetCoordinator(nil)
            stateMachine.tryEvent(.cancelledLoginWithQR) // Needs to be handled manually.
        case .serverSelectionScreen:
            navigationStackCoordinator.popToRoot(animated: animated)
        case .loginScreen:
            navigationStackCoordinator.popToRoot(animated: animated)
        case .bipeSignupScreen, .bipeRecoveryScreen:
            navigationStackCoordinator.popToRoot(animated: animated)
        case .bugReportFlow:
            navigationStackCoordinator.setSheetCoordinator(nil)
        case .developerOptions:
            navigationStackCoordinator.setSheetCoordinator(nil)
        case .complete:
            fatalError()
        }
    }
    
    func handleOAuthCallbackURL(_ url: URL) {
        guard let oAuthPresenter else {
            MXLog.error("Failed to find an OAuth request in progress.")
            return
        }
        
        oAuthPresenter.handleUniversalLinkCallback(url)
    }
    
    // MARK: - Setup
    
    private func configureStateMachine() {
        stateMachine.addRoutes(event: .start, transitions: [.initial => .startScreen]) { [weak self] _ in
            self?.showStartScreen(fromState: .initial)
        }
        
        stateMachine.addRoutes(event: .applyProvisioningParameters, transitions: [.initial => .startScreen,
                                                                                  .startScreen => .startScreen]) { [weak self] context in
            guard let provisioningParameters = context.userInfo as? AccountProvisioningParameters else { fatalError("The authentication configuration is missing.") }
            self?.showStartScreen(fromState: context.fromState, applying: provisioningParameters)
        }
        
        // QR Code
        
        stateMachine.addRoutes(event: .loginWithQR, transitions: [.startScreen => .qrCodeLoginScreen]) { [weak self] _ in
            self?.showQRCodeLoginScreen()
        }
        stateMachine.addRoutes(event: .cancelledLoginWithQR, transitions: [.qrCodeLoginScreen => .startScreen])
        
        // Manual Authentication
        
        stateMachine.addRoutes(event: .selectServer(.login), transitions: [.startScreen => .serverSelectionScreen]) { [weak self] _ in
            self?.showServerSelectionScreen(authenticationFlow: .login)
        }
        stateMachine.addRoutes(event: .selectServer(.register), transitions: [.startScreen => .serverSelectionScreen]) { [weak self] _ in
            self?.showServerSelectionScreen(authenticationFlow: .register)
        }
        stateMachine.addRoutes(event: .cancelledServerSelection, transitions: [.serverSelectionScreen => .startScreen])
        
        stateMachine.addRoutes(event: .continueWithPassword, transitions: [.serverSelectionScreen => .loginScreen,
                                                                           .startScreen => .loginScreen]) { [weak self] context in
            let loginHint = context.userInfo as? String
            self?.showLoginScreen(loginHint: loginHint, fromState: context.fromState)
        }
        stateMachine.addRoutes(event: .cancelledPasswordLogin(previousState: .serverSelectionScreen), transitions: [.loginScreen => .serverSelectionScreen])
        stateMachine.addRoutes(event: .cancelledPasswordLogin(previousState: .startScreen), transitions: [.loginScreen => .startScreen])
        
        // Bipe Sign-up
        
        stateMachine.addRoutes(event: .bipeSignup, transitions: [.startScreen => .bipeSignupScreen]) { [weak self] _ in
            self?.showBipeSignupScreen()
        }
        stateMachine.addRoutes(event: .cancelledBipeSignup, transitions: [.bipeSignupScreen => .startScreen])
        stateMachine.addRoutes(event: .bipeRecovery, transitions: [.startScreen => .bipeRecoveryScreen]) { [weak self] context in
            self?.showBipeRecoveryScreen(mode: context.userInfo as? BipeRecoveryScreenMode ?? .choose)
        }
        stateMachine.addRoutes(event: .cancelledBipeRecovery, transitions: [.bipeRecoveryScreen => .startScreen])
        
        // Bug Report
        
        stateMachine.addRoutes(event: .reportProblem, transitions: [.startScreen => .bugReportFlow]) { [weak self] _ in
            self?.startBugReportFlow()
        }
        stateMachine.addRoutes(event: .bugReportFlowComplete, transitions: [.bugReportFlow => .startScreen])
        
        // Developer Options
        
        stateMachine.addRoutes(event: .developerOptions, transitions: [.startScreen => .developerOptions]) { [weak self] _ in
            self?.showDeveloperOptionsScreen()
        }
        stateMachine.addRoutes(event: .dismissedDeveloperOptions, transitions: [.developerOptions => .startScreen])
        
        // Completion
        
        stateMachine.addRoutes(event: .signedIn, transitions: [.qrCodeLoginScreen => .complete,
                                                               .serverSelectionScreen => .complete, // OAuth authentication
                                                               .startScreen => .complete, // Direct OAuth authentication
                                                               .loginScreen => .complete,
                                                               .bipeSignupScreen => .complete,
                                                               .bipeRecoveryScreen => .complete]) { [weak self] context in
            guard let userSession = context.userInfo as? UserSessionProtocol else { fatalError("The user session wasn't included in the context") }
            self?.userHasSignedIn(userSession: userSession)
        }
        
        // Logging
        
        stateMachine.addAnyHandler(.any => .any) { context in
            MXLog.info("Transitioning from `\(context.fromState)` to `\(context.toState)` with event `\(String(describing: context.event))`.")
        }
        
        // Unhandled
        
        stateMachine.addErrorHandler { context in
            switch (context.fromState, context.toState) {
            case (.complete, .complete):
                break // Ignore all events triggered by
            default:
                fatalError("Unexpected transition: \(context)")
            }
        }
    }
    
    private func showStartScreen(fromState: State, applying provisioningParameters: AccountProvisioningParameters? = nil) {
        let mediaProvider = authenticationService.classicAppAccount.map { account in
            MediaProvider(mediaLoader: ClassicAppMediaLoader(classicAppAccount: account),
                          imageCache: .onlyInMemory,
                          homeserverReachabilityPublisher: appMediator.networkMonitor.reachabilityPublisher.map(HomeserverReachability.init)) // Close enough approximation
        }
        
        let parameters = AuthenticationStartScreenParameters(authenticationService: authenticationService,
                                                             provisioningParameters: provisioningParameters,
                                                             isBugReportServiceEnabled: bugReportService.isEnabled,
                                                             appMediator: appMediator,
                                                             appSettings: appSettings,
                                                             mediaProvider: mediaProvider,
                                                             userIndicatorController: userIndicatorController,
                                                             bipePendingInviteCode: pendingInviteCode,
                                                             bipeAPIClient: appSettings.usesBipeSignup ? BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL) : nil)
        let coordinator = AuthenticationStartScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .loginWithQR:
                    stateMachine.tryEvent(.loginWithQR)
                case .login:
                    if appSettings.usesBipeSignup {
                        stateMachine.tryEvent(.bipeRecovery, userInfo: BipeRecoveryScreenMode.choose)
                    } else {
                        stateMachine.tryEvent(.selectServer(.login))
                    }
                case .register:
                    if appSettings.usesBipeSignup {
                        stateMachine.tryEvent(.bipeSignup)
                    } else {
                        stateMachine.tryEvent(.selectServer(.register))
                    }
                case .bipeSignup(let startsWithInviteCode):
                    bipeSignupStartsWithInviteCode = startsWithInviteCode
                    stateMachine.tryEvent(.bipeSignup)
                    
                case .loginDirectlyWithOAuth(let oAuthData, let window):
                    showOAuthAuthentication(oAuthData: oAuthData, presentationAnchor: window)
                case .loginDirectlyWithPassword(let loginHint):
                    stateMachine.tryEvent(.continueWithPassword, userInfo: loginHint)
                    
                case .reportProblem:
                    stateMachine.tryEvent(.reportProblem)
                case .developerOptions:
                    stateMachine.tryEvent(.developerOptions)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.setRootCoordinator(coordinator)
        
        if fromState == .initial, isAddingAccount {
            navigationRootCoordinator.setSheetCoordinator(navigationStackCoordinator) { [weak self] in
                guard let self, stateMachine.state != .complete else { return }
                delegate?.authenticationFlowCoordinatorDidCancelAddingAccount()
            }
            if bipeAccountType == .company {
                // After the start transition ends.
                Task { self.stateMachine.tryEvent(.bipeSignup) }
            }
        } else if fromState == .initial {
            navigationRootCoordinator.setRootCoordinator(navigationStackCoordinator)
            if appSettings.usesBipeSignup {
                Task { await resumeBipeAccount() }
            }
        }
    }
    
    // MARK: - QR Code
    
    private func showQRCodeLoginScreen() {
        let stackCoordinator = NavigationStackCoordinator()
        let coordinator = QRCodeLoginScreenCoordinator(parameters: .init(mode: .login(authenticationService),
                                                                         canSignInManually: appSettings.allowOtherAccountProviders, // No need to worry about provisioning links as we hide QR login.
                                                                         orientationManager: appMediator.windowManager,
                                                                         appMediator: appMediator))
        coordinator.actionsPublisher.sink { [weak self] action in
            guard let self else {
                return
            }
            switch action {
            case .startOver:
                fatalError("QR code login shouldn't request to start over as it's handled within the screen.")
            case .requestOAuthAuthorisation, .linkedDevice:
                fatalError("QR code login shouldn't request an OAuth flow or link a device.")
            case .signInManually:
                navigationStackCoordinator.setSheetCoordinator(nil)
                stateMachine.tryEvent(.cancelledLoginWithQR)
                stateMachine.tryEvent(.selectServer(.login))
            case .signedIn(let userSession):
                navigationStackCoordinator.setSheetCoordinator(nil)
                DispatchQueue.main.async {
                    self.stateMachine.tryEvent(.signedIn, userInfo: userSession)
                }
            case .cancel:
                navigationStackCoordinator.setSheetCoordinator(nil)
                stateMachine.tryEvent(.cancelledLoginWithQR)
            }
        }
        .store(in: &cancellables)
        
        stackCoordinator.setRootCoordinator(coordinator)
        navigationStackCoordinator.setSheetCoordinator(stackCoordinator) // Don't use the callback (interactive dismiss disabled), choose the event with the action.
    }
    
    // MARK: - Manual Authentication
    
    private func showServerSelectionScreen(authenticationFlow: AuthenticationFlow) {
        // Reset the service back to the default homeserver before continuing. This ensures
        // we check that registration is supported if it was previously configured for login.
        authenticationService.reset()
        
        let parameters = ServerSelectionScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                    authenticationFlow: authenticationFlow,
                                                                    appSettings: appSettings,
                                                                    homeserverHistoryManager: homeserverHistoryManager,
                                                                    userIndicatorController: userIndicatorController)
        let coordinator = ServerSelectionScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .continueWithOAuth(let oAuthData, let window):
                    showOAuthAuthentication(oAuthData: oAuthData, presentationAnchor: window)
                case .continueWithPassword:
                    stateMachine.tryEvent(.continueWithPassword)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.stateMachine.tryEvent(.cancelledServerSelection)
        }
    }
    
    /// **Note:** We have intentionally excluded this presentation from the state machine as it doesn't mutate our navigation stack and there
    /// isn't a robust way to detect why the user returned to the app when the MAS URL directly opens an external app for authentication without
    /// presenting a web authentication session.
    private func showOAuthAuthentication(oAuthData: OAuthAuthorizationDataProxy, presentationAnchor: UIWindow) {
        let presenter = OAuthAuthenticationPresenter(authenticationService: authenticationService,
                                                     redirectURL: appSettings.oAuthRedirectURL,
                                                     presentationAnchor: presentationAnchor,
                                                     appMediator: appMediator,
                                                     appHooks: appHooks,
                                                     userIndicatorController: userIndicatorController)
        oAuthPresenter = presenter
        
        Task {
            switch await presenter.authenticate(using: oAuthData) {
            case .success(let userSession):
                stateMachine.tryEvent(.signedIn, userInfo: userSession)
            case .failure:
                break // Nothing to do, any alerts will be handled by the presenter.
            }
            oAuthPresenter = nil
        }
    }
    
    private func showLoginScreen(loginHint: String?, fromState: State) {
        let parameters = LoginScreenCoordinatorParameters(authenticationService: authenticationService,
                                                          loginHint: loginHint,
                                                          userIndicatorController: userIndicatorController,
                                                          appSettings: appSettings)
        let coordinator = LoginScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .signedIn(let userSession):
                    stateMachine.tryEvent(.signedIn, userInfo: userSession)
                case .configuredForOAuth:
                    // Pop back to the confirmation screen for OAuth login to continue.
                    navigationStackCoordinator.pop(animated: false)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.stateMachine.tryEvent(.cancelledPasswordLogin(previousState: fromState))
        }
    }
    
    // MARK: - Bipe Sign-up
    
    private func showBipeSignupScreen() {
        // The code stays: back on the start screen, "Entrar com o convite" still uses it.
        let parameters = BipeSignupScreenCoordinatorParameters(inviteCode: pendingInviteCode,
                                                               startsWithInviteCode: bipeSignupStartsWithInviteCode,
                                                               apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL),
                                                               signIn: BipeAccountSignIn(authenticationService: authenticationService, appSettings: appSettings),
                                                               appLockService: appLockService,
                                                               userIndicatorController: userIndicatorController,
                                                               accountType: bipeAccountType)
        let coordinator = BipeSignupScreenCoordinator(parameters: parameters)
        
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let userSession):
                    self?.stateMachine.tryEvent(.signedIn, userInfo: userSession)
                case .createdWithInvite(let inviterUserID, let inviterHandle):
                    self?.appSettings.bipePendingInviterUserID = inviterUserID
                    self?.appSettings.bipePendingInviterHandle = inviterHandle
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.stateMachine.tryEvent(.cancelledBipeSignup)
        }
    }
    
    // MARK: - Bipe Recovery
    
    /// At app start without a session: a pending email recovery, then the password stored on this device (silent sign-in),
    /// then a synced recovery token (asks for the PIN). ADR 0057 "Old phone lost, credential synced", with ADR 0059's token.
    private func resumeBipeAccount() async {
        let store = BipeCredentialStore.bipeApp
        guard stateMachine.state == .startScreen else { return }
        
        if let pending = store.pendingRecovery() {
            stateMachine.tryEvent(.bipeRecovery, userInfo: BipeRecoveryScreenMode.waiting(pending))
            return
        }
        
        // A sign-up whose answer never arrived (ADR 0094): the account exists, so finish it instead of showing the form again.
        if store.password() == nil, store.pendingSignup() != nil {
            let loadingIndicatorID = "BipeResumeSignup"
            userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
            let signIn = BipeAccountSignIn(authenticationService: authenticationService, appSettings: appSettings)
            let resumed = await signIn.resumePendingSignup(apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL))
            userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
            if case .success(let userSession) = resumed, stateMachine.state == .startScreen {
                finishBipeSignup(store)
                stateMachine.tryEvent(.signedIn, userInfo: userSession)
                return
            }
        }
        
        if store.password() != nil {
            let loadingIndicatorID = "BipeResumeAccount"
            userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
            let result = await BipeAccountSignIn(authenticationService: authenticationService, appSettings: appSettings).signInWithStoredPassword()
            userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
            if case .success(let userSession) = result, stateMachine.state == .startScreen {
                // The app closed between sign-up and sign-in: the pending sign-up still holds the PIN for the app lock.
                finishBipeSignup(store)
                stateMachine.tryEvent(.signedIn, userInfo: userSession)
                return
            }
        }
        
        if let token = store.recoveryToken(), stateMachine.state == .startScreen {
            stateMachine.tryEvent(.bipeRecovery, userInfo: BipeRecoveryScreenMode.token(userID: token.userID))
        }
    }
    
    /// The account PIN of a finished sign-up becomes the app lock PIN (ADR 0057). Then the pending sign-up goes.
    private func finishBipeSignup(_ store: BipeCredentialStore) {
        guard let pending = store.pendingSignup() else { return }
        if let pin = pending.pin {
            appLockService?.bipeUseAccountPIN(pin)
        }
        // Without a stored password the pending sign-up is the only way to get it back (POST /v1/signup/resume).
        if store.password() != nil {
            store.deletePendingSignup()
        }
    }
    
    private func showBipeRecoveryScreen(mode: BipeRecoveryScreenMode) {
        let parameters = BipeRecoveryScreenCoordinatorParameters(mode: mode,
                                                                 apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL),
                                                                 signIn: BipeAccountSignIn(authenticationService: authenticationService, appSettings: appSettings),
                                                                 serverNameOrBaseURL: appSettings.defaultAccountProvider.serverNameOrBaseURL,
                                                                 appLockService: appLockService,
                                                                 userIndicatorController: userIndicatorController)
        let coordinator = BipeRecoveryScreenCoordinator(parameters: parameters)
        
        coordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                switch action {
                case .signedIn(let userSession):
                    stateMachine.tryEvent(.signedIn, userInfo: userSession)
                case .loginWithQR:
                    // The pop moves the state back to the start screen synchronously; QR sign-in starts from there.
                    navigationStackCoordinator.pop(animated: false)
                    stateMachine.tryEvent(.loginWithQR)
                case .continueWithOAuth(let oAuthData, let window):
                    showOAuthAuthentication(oAuthData: oAuthData, presentationAnchor: window)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.stateMachine.tryEvent(.cancelledBipeRecovery)
        }
    }
    
    // MARK: - Bug Report
    
    private func startBugReportFlow() {
        let coordinator = BugReportFlowCoordinator(parameters: .init(presentationMode: .sheet(navigationStackCoordinator),
                                                                     userIndicatorController: userIndicatorController,
                                                                     bugReportService: bugReportService,
                                                                     userSession: nil))
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .complete:
                self?.stateMachine.tryEvent(.bugReportFlowComplete)
            }
        }
        .store(in: &cancellables)
        
        bugReportFlowCoordinator = coordinator
        coordinator.start()
    }
    
    // MARK: - Developer Options
    
    private func showDeveloperOptionsScreen() {
        let stackCoordinator = NavigationStackCoordinator()
        let coordinator = DeveloperOptionsScreenCoordinator(appSettings: appSettings,
                                                            appHooks: appHooks,
                                                            clientProxy: nil)
        coordinator.actions
            .sink { action in
                switch action {
                case .clearCache:
                    break // Not sent when clientProxy == nil
                }
            }
            .store(in: &cancellables)
        
        stackCoordinator.setRootCoordinator(coordinator)
        navigationStackCoordinator.setSheetCoordinator(stackCoordinator) { [weak self] in
            self?.stateMachine.tryEvent(.dismissedDeveloperOptions)
        }
    }
    
    // MARK: - Completion
    
    private func userHasSignedIn(userSession: UserSessionProtocol) {
        delegate?.authenticationFlowCoordinator(didLoginWithSession: userSession)
        
        let newAccountProvider = authenticationService.homeserver.value.accountProvider
        homeserverHistoryManager.addServerToList(newAccountProvider.serverNameOrBaseURL)
    }
}
