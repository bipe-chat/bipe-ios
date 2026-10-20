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

typealias SettingsScreenViewModelType = StateStoreViewModelV2<SettingsScreenViewState, SettingsScreenViewAction>

class SettingsScreenViewModel: SettingsScreenViewModelType, SettingsScreenViewModelProtocol {
    private let userSettings: UserSettings
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var actionsSubject: PassthroughSubject<SettingsScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<SettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol, isBugReportServiceEnabled: Bool, isInSecondaryWindow: Bool, userIndicatorController: UserIndicatorControllerProtocol, bipeIsInTab: Bool = false) {
        userSettings = userSession.userSettings
        clientProxy = userSession.clientProxy
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init(deviceID: userSession.clientProxy.deviceID,
                                           userProfile: userSession.clientProxy.userProfilePublisher.value,
                                           showLinkNewDeviceButton: userSettings.app.linkNewDeviceEnabled,
                                           showAccountDeactivation: userSession.clientProxy.canDeactivateAccount,
                                           showDeveloperOptions: userSettings.app.developerOptionsEnabled,
                                           showBipeHandle: userSession.clientProxy.userIDServerName == userSettings.app.bipeSignupServerName,
                                           showAnalyticsSettings: userSettings.app.canPromptForAnalytics,
                                           isBugReportServiceEnabled: isBugReportServiceEnabled,
                                           navigationBarVisibility: isInSecondaryWindow ? .hidden : .automatic,
                                           bindings: .init(userSettings: userSettings)),
                   mediaProvider: userSession.mediaProvider)
        
        state.bipeIsInTab = bipeIsInTab
        state.bipeAccountType = BipeAccountLabels.isCompany(userSession.clientProxy.userID) ? .company : .personal
        
        userSettings.app.developerOptionsEnabledPublisher
            .weakAssign(to: \.state.showDeveloperOptions, on: self)
            .store(in: &cancellables)
        
        userSettings.app.linkNewDeviceEnabledPublisher
            .weakAssign(to: \.state.showLinkNewDeviceButton, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userProfile, on: self)
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] securityState in
                guard let self else { return }
                
                switch (securityState.verificationState, securityState.recoveryState) {
                case (.verified, .disabled):
                    state.showSecuritySectionBadge = true
                    state.securitySectionMode = .secureBackup
                case (.verified, .incomplete):
                    state.showSecuritySectionBadge = true
                    state.securitySectionMode = .secureBackup
                case (.unknown, _):
                    state.showSecuritySectionBadge = false
                    state.securitySectionMode = .none
                default:
                    state.showSecuritySectionBadge = false
                    state.securitySectionMode = .secureBackup
                }
            }
            .store(in: &cancellables)
        
        Task {
            if case .success(true) = await userSession.clientProxy.isUserStatusSupported() {
                state.showUserStatusInput = true
            }
            await userSession.clientProxy.loadUserProfileIfNeeded()
        }
        Task { await state.accountProfileURL = userSession.clientProxy.accountURL(action: .profile) }
    }
    
    override func process(viewAction: SettingsScreenViewAction) {
        switch viewAction {
        case .close:
            actionsSubject.send(.close)
            
        case .userDetails:
            actionsSubject.send(.userDetails)
        case .userStatus(.pickStatus):
            state.bindings.isPresentingStatusPicker = true
        case .userStatus(.customStatus):
            state.bindings.isPresentingStatusPicker = false
            state.bindings.isShowingCustomStatusField = true
        case .userStatus(.pickCustomEmoji):
            pickCustomEmoji()
        case .userStatus(.set(let status)):
            Task { await setUserStatus(status) }
        case .userStatus(.clear):
            Task { await clearUserStatus() }
        case .userStatus(.cancel):
            state.bindings.isPresentingStatusPicker = false
            state.bindings.isShowingCustomStatusField = false
            
        case let .manageAccount(url):
            actionsSubject.send(.manageAccount(url: url))
        case .linkNewDevice:
            actionsSubject.send(.linkNewDevice)
        case .notifications:
            actionsSubject.send(.notifications)
        case .secureBackup:
            actionsSubject.send(.secureBackup)
        case .moderationAndSafety:
            actionsSubject.send(.moderationAndSafety)
        case .reportBug:
            actionsSubject.send(.reportBug)
            
        case .logout:
            actionsSubject.send(.logout)
        case .deactivateAccount:
            actionsSubject.send(.deactivateAccount)
            
        case .mediaUploadQuality:
            actionsSubject.send(.mediaUploadQuality)
        case .appLock:
            actionsSubject.send(.appLock)
        case .locationSharing:
            actionsSubject.send(.locationSharing)
        case .analytics:
            actionsSubject.send(.analytics)
        case .labs:
            actionsSubject.send(.labs)
        case .about:
            actionsSubject.send(.about)
            
        case .enableDeveloperOptions:
            userSettings.app.developerOptionsEnabled.toggle()
        case .developerOptions:
            actionsSubject.send(.developerOptions)
            
        case .bipeHandle:
            actionsSubject.send(.bipeHandle)
        case .bipePublicProfile:
            actionsSubject.send(.bipePublicProfile)
        case .bipeMessaging:
            actionsSubject.send(.bipeMessaging)
        case .bipeLoadHandle:
            Task { await loadBipeHandle() }
            Task { await loadBipeWhoCanMessage() }
            Task { await loadBipeWaysBack() }
            Task { await loadBipeNotificationsState() }
        case .bipeContacts:
            actionsSubject.send(.bipeContacts)
        case .bipeSelfChat:
            actionsSubject.send(.bipeSelfChat)
        case .bipeAccount:
            actionsSubject.send(.bipeAccount)
        case .bipeGroup(let group):
            actionsSubject.send(.bipeGroup(group))
        case .bipeCopyDeviceID:
            guard let deviceID = state.deviceID else { return }
            UIPasteboard.general.string = deviceID
            BipeHaptics.play(.tap)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.helpDeviceIdCopied, icon: \.check))
        }
    }
    
    // MARK: - Bipe
    
    private func loadBipeHandle() async {
        guard state.showBipeHandle, let accessToken = clientProxy.accessToken else { return }
        let apiClient = BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL)
        do {
            state.bipeHandle = try await apiClient.myHandle(accessToken: accessToken).handle
        } catch {
            MXLog.error("Bipe handle load failed: \(error)")
        }
    }
    
    private func loadBipeWhoCanMessage() async {
        guard state.showBipeHandle else { return }
        let apiClient = BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL)
        do {
            state.bipeWhoCanMessage = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { (token: String) async throws(BipeAPIError) -> BipeWhoCanMessage in
                try await apiClient.messagingSetting(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe messaging setting load failed: \(error)")
        }
    }
    
    private func loadBipeWaysBack() async {
        guard state.showBipeHandle else {
            state.bipeWaysBack = BipeWaysBackReader.waysBack(status: nil, clientProxy: clientProxy)
            return
        }
        let apiClient = BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL)
        let (status, waysBack) = await BipeWaysBackReader.load(apiClient: apiClient, clientProxy: clientProxy)
        state.bipeWaysBack = waysBack
        if let status {
            state.bipeAccountType = status.accountType ?? .personal
        }
        if state.bipeAccountType == .company {
            await loadBipeBusiness(apiClient: apiClient)
        }
    }
    
    private func loadBipeBusiness(apiClient: BipeAPIClient) async {
        do {
            state.bipeBusiness = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { (token: String) async throws(BipeAPIError) -> BipeBusinessClaim? in
                try await apiClient.myBusiness(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe business claim load failed: \(error)")
        }
    }
    
    /// On when the app setting is on and iOS allows notifications.
    private func loadBipeNotificationsState() async {
        let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        state.bipeNotificationsOn = userSettings.app.enableNotifications && authorizationStatus != .denied
    }
    
    // MARK: - Private
    
    private var pickCustomEmojiCancellable: AnyCancellable?
    private func pickCustomEmoji() {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        actionsSubject.send(.userStatusEmojiPicker(continuation))
        
        pickCustomEmojiCancellable = Task { [weak self] in
            for await emoji in stream {
                self?.state.bindings.customStatusEmoji = Character(emoji)
            }
        }
        .asCancellable()
    }
    
    private func setUserStatus(_ status: UserStatus.Raw) async {
        showSavingIndicator()
        defer { hideSavingIndicator() }
        
        state.bindings.isPresentingStatusPicker = false
        state.bindings.isShowingCustomStatusField = false
        
        if case .failure = await clientProxy.setUserStatus(status) {
            showFailureIndicator()
        }
    }
    
    /// Clears both the `UserStatus.Raw` and `UserStatus.Call` values simultaneously.
    private func clearUserStatus() async {
        showSavingIndicator()
        defer { hideSavingIndicator() }
        
        state.bindings.isPresentingStatusPicker = false
        state.bindings.isShowingCustomStatusField = false
        
        if case .failure = await clientProxy.clearUserStatus() {
            showFailureIndicator()
        }
    }
    
    // MARK: - Indicators
    
    private static var savingIndicatorID: String {
        "\(Self.self)-Saving"
    }
    
    private static var failureIndicatorID: String {
        "\(Self.self)-Failure"
    }
    
    private func showSavingIndicator() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.savingIndicatorID,
                                                              type: .toast(progress: .indeterminate),
                                                              title: L10n.commonSaving,
                                                              persistent: true))
    }
    
    private func hideSavingIndicator() {
        userIndicatorController.retractIndicatorWithId(Self.savingIndicatorID)
    }
    
    private func showFailureIndicator() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.failureIndicatorID,
                                                              type: .toast,
                                                              title: L10n.commonFailed,
                                                              icon: \.close))
    }
}
