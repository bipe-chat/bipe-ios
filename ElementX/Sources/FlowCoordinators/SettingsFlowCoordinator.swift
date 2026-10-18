//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import SwiftUI

enum SettingsFlowCoordinatorAction {
    case dismiss
    case clearCache
    case runLogoutFlow
    /// Logout without a confirmation. The user forgot their PIN.
    case forceLogout
    /// Bipe: open a user's profile in the chats tab (from the invites screen).
    case openUserProfile(userID: String)
    /// Bipe: open the self-chat (ADR 0053).
    case openSelfChat
    /// Bipe: "Criar conta da empresa" (ADR 0087, bipe#269).
    case bipeCreateCompanyAccount
}

class SettingsFlowCoordinator: FlowCoordinatorProtocol {
    private let appLockService: AppLockServiceProtocol
    private let isInSecondaryWindow: Bool
    private let isInTab: Bool
    private let navigationStackCoordinator: NavigationStackCoordinator
    private let flowParameters: CommonFlowParameters
    
    private var userSettings: UserSettings {
        flowParameters.userSession.userSettings
    }
    
    // periphery:ignore - retaining purpose
    private var appLockSetupFlowCoordinator: AppLockSetupFlowCoordinator?
    private var bugReportFlowCoordinator: BugReportFlowCoordinator?
    // periphery:ignore - retaining purpose
    private var encryptionSettingsFlowCoordinator: EncryptionSettingsFlowCoordinator?
    // periphery:ignore - retaining purpose
    private var linkNewDeviceFlowCoordinator: LinkNewDeviceFlowCoordinator?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<SettingsFlowCoordinatorAction, Never> = .init()
    var actions: AnyPublisher<SettingsFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(appLockService: AppLockServiceProtocol,
         isInSecondaryWindow: Bool,
         isInTab: Bool = false,
         navigationStackCoordinator: NavigationStackCoordinator,
         flowParameters: CommonFlowParameters) {
        self.appLockService = appLockService
        self.isInSecondaryWindow = isInSecondaryWindow
        self.isInTab = isInTab
        self.navigationStackCoordinator = navigationStackCoordinator
        self.flowParameters = flowParameters
    }
    
    func start(animated: Bool) {
        fatalError("Unavailable")
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        MXLog.info("Handling app route: \(appRoute)")
        
        switch appRoute {
        case .settings:
            presentSettingsScreen(animated: animated)
        case .chatBackupSettings:
            // Bipe: the recovery key lives in Sua conta (ADR 0112).
            presentBipeSettingsGroup(.account)
            presentBipeRecoveryKey()
        default:
            break
        }
    }
    
    func clearRoute(animated: Bool) {
        fatalError("Unavailable")
    }
    
    // MARK: - Private
    
    private func presentSettingsScreen(animated: Bool) {
        let settingsScreenCoordinator = SettingsScreenCoordinator(parameters: .init(userSession: flowParameters.userSession,
                                                                                    isBugReportServiceEnabled: flowParameters.bugReportService.isEnabled,
                                                                                    isInSecondaryWindow: isInSecondaryWindow,
                                                                                    userIndicatorController: flowParameters.userIndicatorController,
                                                                                    bipeIsInTab: isInTab))
        
        settingsScreenCoordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .dismiss:
                    actionsSubject.send(.dismiss)
                    
                case .userDetails:
                    presentUserDetailsEditScreen()
                case let .userStatusEmojiPicker(continuation):
                    presentEmojiPicker(emojiPickerContinuation: continuation)
                    
                case .addAccount:
                    break // Nothing to present until the add account flow exists.
                    
                case let .manageAccount(url):
                    presentAccountManagementURL(url)
                case .linkNewDevice:
                    startLinkNewDeviceFlow()
                case .notifications:
                    presentNotificationSettings()
                case .secureBackup:
                    startEncryptionSettingsFlow()
                case .moderationAndSafety:
                    presentModerationAndSafetySettings()
                case .bugReport:
                    presentBugReport()
                    
                case .logout:
                    actionsSubject.send(.runLogoutFlow)
                case .deactivateAccount:
                    presentDeactivateAccount()
                    
                case .mediaUploadQuality:
                    presentMediaUploadQualitySettings()
                case .appLock:
                    presentAppLockSetupFlow()
                case .locationSharing:
                    presentLocationSharingSettings()
                case .analytics:
                    presentAnalyticsScreen()
                case .labs:
                    presentLabs()
                case .about:
                    presentLegalInformationScreen()
                    
                case .developerOptions:
                    presentDeveloperOptions()
                    
                case .bipeHandle:
                    presentBipeHandleScreen()
                case .bipePublicProfile:
                    presentBipePublicProfileScreen()
                case .bipeMessaging:
                    presentBipeMessagingScreen()
                case .bipeContacts:
                    presentBipeContactsScreen()
                case .bipeSelfChat:
                    actionsSubject.send(.openSelfChat)
                case .bipeAccount:
                    presentBipeSettingsGroup(.account)
                case .bipeGroup(let group):
                    presentBipeSettingsGroup(group)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.setRootCoordinator(settingsScreenCoordinator, animated: animated)
    }
    
    // MARK: - Bipe settings groups (ADR 0112)
    
    private func presentBipeSettingsGroup(_ group: BipeSettingsGroup) {
        guard !group.usesElementScreen else {
            presentNotificationSettings()
            return
        }
        
        let coordinator = BipeSettingsGroupScreenCoordinator(parameters: .init(group: group,
                                                                               userSession: flowParameters.userSession,
                                                                               appLockService: appLockService,
                                                                               userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .open(let row):
                    self?.openBipeSettingsRow(row)
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    /// The rows that open another screen or flow. Old Element routes map here.
    private func openBipeSettingsRow(_ row: BipeSettingsRow) {
        switch row {
        case .profileNamePhoto:
            presentUserDetailsEditScreen()
        case .profileHandle:
            presentBipeHandleScreen()
        case .profilePublicProfile:
            presentBipePublicProfileScreen()
        case .privacyMessaging:
            presentBipeMessagingScreen()
        case .privacyBlocked:
            presentBlockedUsersScreen()
        case .privacyContacts:
            presentBipeContactsScreen()
        case .accountChangePin:
            presentBipeAccountScreen(mode: .pin)
        case .accountEmail:
            presentBipeAccountScreen(mode: .email)
        case .accountRecoveryKey:
            presentBipeRecoveryKey()
        case .accountLinkDevice:
            startLinkNewDeviceFlow()
        case .accountSignOut:
            actionsSubject.send(.runLogoutFlow)
        case .accountCreateCompany:
            actionsSubject.send(.bipeCreateCompanyAccount)
        case .helpReportProblem:
            presentBugReport()
        case .chatsMediaQuality:
            presentMediaUploadQualitySettings()
        case .chatsLiveLocation:
            presentLocationSharingSettings()
        default:
            MXLog.error("Bipe settings row without a screen: \(row.rawValue)")
        }
    }
    
    /// "Avisar sobre um problema" (bipe#367): the report goes to the Bipe API.
    private func presentBugReport() {
        bugReportFlowCoordinator = BugReportFlowCoordinator(parameters: .init(presentationMode: .push(navigationStackCoordinator),
                                                                              userIndicatorController: flowParameters.userIndicatorController,
                                                                              bugReportService: flowParameters.bugReportService,
                                                                              userSession: flowParameters.userSession))
        bugReportFlowCoordinator?.start()
    }
    
    /// `onDone` runs after the screen pops, e.g. to reload the screen below.
    private func presentBipeHandleScreen(onDone: (() -> Void)? = nil) {
        let coordinator = BipeHandleScreenCoordinator(parameters: .init(apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                        clientProxy: flowParameters.userSession.clientProxy,
                                                                        handleResolver: flowParameters.userSession.bipeHandleResolver,
                                                                        userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done:
                    self?.navigationStackCoordinator.pop()
                    onDone?()
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentBipePublicProfileScreen() {
        let coordinator = BipePublicProfileScreenCoordinator(parameters: .init(apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                               userSession: flowParameters.userSession,
                                                                               userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self, weak coordinator] action in
                switch action {
                case .openHandle:
                    self?.presentBipeHandleScreen { coordinator?.reload() }
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentBipeAccountScreen(mode: BipeAccountScreenMode) {
        let coordinator = BipeAccountScreenCoordinator(parameters: .init(mode: mode,
                                                                         apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                         clientProxy: flowParameters.userSession.clientProxy,
                                                                         appLockService: appLockService,
                                                                         userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done:
                    self?.navigationStackCoordinator.pop()
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    /// Bipe: "Chave de recuperação" in Sua conta. With key storage on, the recovery key screen opens directly,
    /// so Sua conta never shows Element's "Criptografia" screen. Without it, the full flow turns key storage on first.
    private func presentBipeRecoveryKey() {
        let clientProxy = flowParameters.userSession.clientProxy
        guard clientProxy.secureBackupController.keyBackupState.value == .enabled else {
            startEncryptionSettingsFlow()
            return
        }
        
        let sheetNavigationStackCoordinator = NavigationStackCoordinator()
        let parameters = SecureBackupRecoveryKeyScreenCoordinatorParameters(secureBackupController: clientProxy.secureBackupController,
                                                                            userIndicatorController: flowParameters.userIndicatorController,
                                                                            isModallyPresented: true)
        let coordinator = flowParameters.appHooks.recoveryKeyScreenHook.makeCoordinator(parameters: parameters,
                                                                                        homeserver: clientProxy.homeserver)
        coordinator.actions
            .sink { [weak self] action in
                switch action {
                case .complete:
                    self?.navigationStackCoordinator.setSheetCoordinator(nil)
                }
            }
            .store(in: &cancellables)
        sheetNavigationStackCoordinator.setRootCoordinator(coordinator, animated: true)
        navigationStackCoordinator.setSheetCoordinator(sheetNavigationStackCoordinator)
    }
    
    private func presentBipeMessagingScreen() {
        let coordinator = BipeMessagingScreenCoordinator(parameters: .init(apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                           clientProxy: flowParameters.userSession.clientProxy))
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentBipeInvitesScreen() {
        let coordinator = BipeInvitesScreenCoordinator(parameters: .init(apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                         clientProxy: flowParameters.userSession.clientProxy,
                                                                         userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .openUserProfile(let userID):
                    self?.actionsSubject.send(.openUserProfile(userID: userID))
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentBipeContactsScreen() {
        let coordinator = BipeContactsScreenCoordinator(parameters: .init(apiClient: BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL),
                                                                          clientProxy: flowParameters.userSession.clientProxy,
                                                                          userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .openUserProfile(let userID):
                    self?.actionsSubject.send(.openUserProfile(userID: userID))
                case .openInvites:
                    self?.presentBipeInvitesScreen()
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentLabs() {
        let coordinator = LabsScreenCoordinator(parameters: .init(userSettings: userSettings))
        coordinator.actions
            .sink { [weak self] action in
                switch action {
                case .clearCache:
                    self?.actionsSubject.send(.clearCache)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func startEncryptionSettingsFlow() {
        let coordinator = EncryptionSettingsFlowCoordinator(parameters: .init(userSession: flowParameters.userSession,
                                                                              appHooks: flowParameters.appHooks,
                                                                              userIndicatorController: flowParameters.userIndicatorController,
                                                                              navigationStackCoordinator: navigationStackCoordinator))
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .complete:
                // The flow coordinator tidies up the stack, no need to do anything.
                self?.encryptionSettingsFlowCoordinator = nil
            }
        }
        .store(in: &cancellables)
        
        encryptionSettingsFlowCoordinator = coordinator
        coordinator.start()
    }
    
    private func presentEmojiPicker(emojiPickerContinuation: EmojiPickerScreenContinuation) {
        let coordinator = EmojiPickerScreenCoordinator(parameters: .init(mode: .userStatus,
                                                                         selectedEmojis: [],
                                                                         emojiProvider: flowParameters.emojiProvider,
                                                                         continuation: emojiPickerContinuation))
        coordinator.actions
            .sink { [weak self] action in
                switch action {
                case .dismiss:
                    self?.navigationStackCoordinator.setSheetCoordinator(nil)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.setSheetCoordinator(coordinator)
    }
    
    private func presentUserDetailsEditScreen() {
        let coordinator = UserDetailsEditScreenCoordinator(parameters: .init(orientationManager: flowParameters.windowManager,
                                                                             userSession: flowParameters.userSession,
                                                                             mediaUploadingPreprocessor: MediaUploadingPreprocessor(userSettings: userSettings),
                                                                             navigationStackCoordinator: navigationStackCoordinator,
                                                                             userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actions
            .sink { [weak self] action in
                switch action {
                case .dismiss:
                    self?.navigationStackCoordinator.pop()
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func startLinkNewDeviceFlow() {
        let stackCoordinator = NavigationStackCoordinator()
        let flowCoordinator = LinkNewDeviceFlowCoordinator(navigationStackCoordinator: stackCoordinator,
                                                           appLockService: appLockService,
                                                           flowParameters: flowParameters)
        flowCoordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .dismiss:
                    navigationStackCoordinator.setSheetCoordinator(nil)
                case .requestOAuthAuthorisation(let url, let continuation):
                    presentAccountManagementURL(url, continuation: continuation)
                case .forceLogout:
                    actionsSubject.send(.forceLogout)
                }
            }
            .store(in: &cancellables)
        
        linkNewDeviceFlowCoordinator = flowCoordinator
        flowCoordinator.start()
        
        navigationStackCoordinator.setSheetCoordinator(stackCoordinator) { [weak self] in
            self?.linkNewDeviceFlowCoordinator = nil
        }
    }
    
    private func presentAnalyticsScreen() {
        let coordinator = AnalyticsSettingsScreenCoordinator(parameters: .init(userSettings: userSettings,
                                                                               analytics: flowParameters.analytics))
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentAppLockSetupFlow() {
        let coordinator = AppLockSetupFlowCoordinator(presentingFlow: .settings,
                                                      appLockService: appLockService,
                                                      navigationStackCoordinator: navigationStackCoordinator)
        coordinator.actions.sink { [weak self] action in
            guard let self else { return }
            switch action {
            case .complete:
                // The flow coordinator tidies up the stack, no need to do anything.
                appLockSetupFlowCoordinator = nil
            case .forceLogout:
                actionsSubject.send(.forceLogout)
            }
        }
        .store(in: &cancellables)
        
        appLockSetupFlowCoordinator = coordinator
        coordinator.start()
    }
    
    private func presentLegalInformationScreen() {
        navigationStackCoordinator.push(LegalInformationScreenCoordinator(userSettings: userSettings))
    }
    
    private func presentBlockedUsersScreen() {
        let coordinator = BlockedUsersScreenCoordinator(parameters: .init(hideProfiles: userSettings.app.hideIgnoredUserProfiles,
                                                                          userSession: flowParameters.userSession,
                                                                          userIndicatorController: flowParameters.userIndicatorController))
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentNotificationSettings() {
        let notificationParameters = NotificationSettingsScreenCoordinatorParameters(navigationStackCoordinator: navigationStackCoordinator,
                                                                                     userSession: flowParameters.userSession,
                                                                                     userNotificationCenter: UNUserNotificationCenter.current(),
                                                                                     userIndicatorController: flowParameters.userIndicatorController,
                                                                                     isModallyPresented: false)
        let coordinator = NotificationSettingsScreenCoordinator(parameters: notificationParameters)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentModerationAndSafetySettings() {
        let parameters = ModerationAndSafetySettingsScreenCoordinatorParameters(userSession: flowParameters.userSession,
                                                                                userIndicatorController: flowParameters.userIndicatorController)
        let coordinator = ModerationAndSafetySettingsScreenCoordinator(parameters: parameters)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .blockedUsers:
                    presentBlockedUsersScreen()
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentMediaUploadQualitySettings() {
        let parameters = MediaUploadQualitySettingsScreenCoordinatorParameters(userSettings: userSettings,
                                                                               analytics: flowParameters.analytics)
        let coordinator = MediaUploadQualitySettingsScreenCoordinator(parameters: parameters)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentLocationSharingSettings() {
        let parameters = LocationSharingSettingsScreenCoordinatorParameters(userSettings: userSettings)
        let coordinator = LocationSharingSettingsScreenCoordinator(parameters: parameters)
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentDeveloperOptions() {
        let coordinator = DeveloperOptionsScreenCoordinator(appSettings: userSettings.app,
                                                            appHooks: flowParameters.appHooks,
                                                            clientProxy: flowParameters.userSession.clientProxy)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .clearCache:
                    actionsSubject.send(.clearCache)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentDeactivateAccount() {
        let parameters = DeactivateAccountScreenCoordinatorParameters(clientProxy: flowParameters.userSession.clientProxy,
                                                                      userIndicatorController: flowParameters.userIndicatorController)
        let coordinator = DeactivateAccountScreenCoordinator(parameters: parameters)
        
        coordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .accountDeactivated:
                    actionsSubject.send(.forceLogout)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    // MARK: OAuth Account Management
    
    private var accountSettingsPresenter: OAuthAccountSettingsPresenter?
    private func presentAccountManagementURL(_ url: URL, continuation: OAuthAccountSettingsPresenter.Continuation? = nil) {
        // Note to anyone in the future if you come back here to make this open in Safari instead of a WAS.
        // As of iOS 16, there is an issue on the simulator with accessing the cookie but it works on a device. 🤷‍♂️
        accountSettingsPresenter = OAuthAccountSettingsPresenter(accountURL: url,
                                                                 presentationAnchor: flowParameters.windowManager.mainWindow,
                                                                 appMediator: flowParameters.appMediator,
                                                                 userSettings: userSettings,
                                                                 appHooks: flowParameters.appHooks,
                                                                 continuation: continuation)
        accountSettingsPresenter?.start()
    }
}
