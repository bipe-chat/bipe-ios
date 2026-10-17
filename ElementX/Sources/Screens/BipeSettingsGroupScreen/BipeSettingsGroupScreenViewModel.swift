//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import LocalAuthentication
import SwiftUI

typealias BipeSettingsGroupScreenViewModelType = StateStoreViewModelV2<BipeSettingsGroupScreenViewState, BipeSettingsGroupScreenViewAction>

/// Bipe: the values of one settings group (ADR 0112). Rows come from the registry; this reads and writes what they show.
class BipeSettingsGroupScreenViewModel: BipeSettingsGroupScreenViewModelType, BipeSettingsGroupScreenViewModelProtocol {
    private let userSession: UserSessionProtocol
    private let appLockService: AppLockServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let apiClient: BipeAPIClient
    
    private var clientProxy: ClientProxyProtocol {
        userSession.clientProxy
    }
    
    private var appSettings: AppSettings {
        userSession.userSettings.app
    }
    
    private let actionsSubject: PassthroughSubject<BipeSettingsGroupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSettingsGroupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(group: BipeSettingsGroup,
         userSession: UserSessionProtocol,
         appLockService: AppLockServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.userSession = userSession
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController
        apiClient = BipeAPIClient(baseURL: userSession.userSettings.app.bipeAPIBaseURL)
        
        let appSettings = userSession.userSettings.app
        super.init(initialViewState: BipeSettingsGroupScreenViewState(group: group,
                                                                      isBipeAccount: userSession.clientProxy.userIDServerName == appSettings.bipeSignupServerName,
                                                                      hideInviteAvatars: userSession.clientProxy.hideInviteAvatarsPublisher.value,
                                                                      timelineMediaVisibility: userSession.clientProxy.timelineMediaVisibilityPublisher.value,
                                                                      bindings: .init(appSettings: appSettings)),
                   mediaProvider: userSession.mediaProvider)
        
        appSettings.linkNewDeviceEnabledPublisher
            .sink { [weak self] enabled in
                if enabled {
                    self?.state.flags.insert("linkNewDevice")
                } else {
                    self?.state.flags.remove("linkNewDevice")
                }
            }
            .store(in: &cancellables)
        
        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in self?.state.displayName = profile.displayName }
            .store(in: &cancellables)
        
        if group == .account {
            state.biometryName = appLockService.isEnabled && appLockService.biometryType != .none ? appLockService.biometryType.localizedString : nil
            state.bindings.biometricUnlock = appLockService.biometricUnlockEnabled
            
            userSession.clientProxy.secureBackupController.recoveryState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] recoveryState in
                    guard let self else { return }
                    state.recoveryKeySet = recoveryState == .enabled
                    state.waysBack = BipeWaysBackReader.waysBack(status: state.accountStatus, clientProxy: clientProxy)
                }
                .store(in: &cancellables)
        }
        
        if group == .chats {
            userSession.clientProxy.timelineMediaVisibilityPublisher
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.state.timelineMediaVisibility, on: self)
                .store(in: &cancellables)
        }
        
        if group == .privacy {
            userSession.clientProxy.hideInviteAvatarsPublisher
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.state.hideInviteAvatars, on: self)
                .store(in: &cancellables)
            
            userSession.clientProxy.ignoredUsersPublisher
                .receive(on: DispatchQueue.main)
                .map { $0?.count ?? 0 }
                .weakAssign(to: \.state.blockedCount, on: self)
                .store(in: &cancellables)
        }
    }
    
    override func process(viewAction: BipeSettingsGroupScreenViewAction) {
        switch viewAction {
        case .reload:
            reload()
        case .open(let row):
            actionsSubject.send(.open(row))
        case .updateHideInviteAvatars(let value):
            Task { await updateHideInviteAvatars(value) }
        case .discoverableChanged:
            Task { await saveDiscoverable(state.bindings.discoverableByPhone) }
        case .export:
            Task { await exportData() }
        case .exportClosed:
            removeExportFile()
        case .biometricUnlockChanged:
            Task { await updateBiometricUnlock(state.bindings.biometricUnlock) }
        case .updateTimelineMediaVisibility(let value):
            Task { await updateTimelineMediaVisibility(value) }
        }
    }
    
    private func reload() {
        switch state.group {
        case .profile where state.isBipeAccount:
            Task { await loadProfile() }
        case .privacy where state.isBipeAccount:
            Task { await loadPrivacy() }
        case .account:
            Task { await loadAccount() }
        default:
            break
        }
    }
    
    // MARK: - Seu perfil
    
    private func loadProfile() async {
        do {
            state.handle = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyHandle in
                try await apiClient.myHandle(accessToken: token)
            }.handle
        } catch {
            MXLog.error("Bipe handle load failed: \(error)")
        }
        do {
            state.publicProfileEnabled = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                try await apiClient.myProfile(accessToken: token)
            }.enabled
        } catch {
            MXLog.error("Bipe public profile load failed: \(error)")
        }
    }
    
    // MARK: - Sua conta
    
    private func loadAccount() async {
        guard state.isBipeAccount else {
            state.waysBack = BipeWaysBackReader.waysBack(status: nil, clientProxy: clientProxy)
            return
        }
        let result = await BipeWaysBackReader.load(apiClient: apiClient, clientProxy: clientProxy)
        state.accountStatus = result.status
        state.waysBack = result.waysBack
    }
    
    /// Same steps as Element's app lock settings: Face ID needs one unlock to confirm.
    private func updateBiometricUnlock(_ enabled: Bool) async {
        guard enabled != appLockService.biometricUnlockEnabled else { return }
        if enabled {
            guard case .success = appLockService.enableBiometricUnlock() else {
                MXLog.error("Enabling biometric unlock failed.")
                state.bindings.biometricUnlock = false
                return
            }
            if appLockService.biometryType == .faceID, await appLockService.unlockWithBiometrics() != .unlocked {
                MXLog.info("Biometric unlock not confirmed. Disabling it.")
                appLockService.disableBiometricUnlock()
                state.bindings.biometricUnlock = false
            }
        } else {
            appLockService.disableBiometricUnlock()
        }
    }
    
    // MARK: - Conversas e mídia
    
    private func updateTimelineMediaVisibility(_ value: TimelineMediaVisibility) async {
        let previous = state.timelineMediaVisibility
        state.timelineMediaVisibility = value
        state.isWaitingTimelineMediaVisibility = true
        defer { state.isWaitingTimelineMediaVisibility = false }
        if case .failure = await clientProxy.setTimelineMediaVisibility(value) {
            state.timelineMediaVisibility = previous
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.errorUnknown))
        }
    }
    
    // MARK: - Privacidade
    
    private func loadPrivacy() async {
        do {
            state.whoCanMessage = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeWhoCanMessage in
                try await apiClient.messagingSetting(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe messaging setting load failed: \(error)")
        }
        do {
            let phone = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyPhone in
                try await apiClient.myPhone(accessToken: token)
            }
            state.phoneLinked = phone.linked
            savedDiscoverable = phone.discoverableByPhone
            state.bindings.discoverableByPhone = phone.discoverableByPhone
        } catch {
            MXLog.error("Bipe phone status load failed: \(error)")
        }
    }
    
    private var savedDiscoverable = false
    
    private func saveDiscoverable(_ value: Bool) async {
        guard value != savedDiscoverable, !state.isWaitingDiscoverable else { return }
        state.isWaitingDiscoverable = true
        defer { state.isWaitingDiscoverable = false }
        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.setDiscoverableByPhone(value, accessToken: token)
            }
            savedDiscoverable = value
        } catch {
            MXLog.error("Bipe discovery setting failed: \(error)")
            state.bindings.discoverableByPhone = savedDiscoverable
            showError(error.localizedMessage)
        }
    }
    
    private func updateHideInviteAvatars(_ value: Bool) async {
        let previous = state.hideInviteAvatars
        state.hideInviteAvatars = value
        state.isWaitingHideInviteAvatars = true
        defer { state.isWaitingHideInviteAvatars = false }
        if case .failure = await clientProxy.setHideInviteAvatars(value) {
            state.hideInviteAvatars = previous
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.errorUnknown))
        }
    }
    
    /// LGPD art. 18 (bipe#364): device owner check, `GET /v1/me/export`, then the share sheet.
    private func exportData() async {
        guard await appLockService.verifyDeviceOwner(reason: BipeStrings.privacyExportBiometric) == .verified else {
            MXLog.info("Bipe data export: device owner check not passed")
            return
        }
        
        let indicatorID = "\(Self.self)-Export"
        userIndicatorController.submitIndicator(UserIndicator(id: indicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(indicatorID) }
        
        do {
            let export = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeDataExport in
                try await apiClient.exportMyData(accessToken: token)
            }
            let directory = URL.temporaryDirectory.appending(path: "BipeExport", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appending(path: export.filename, directoryHint: .notDirectory)
            try export.data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            exportedFile = fileURL
            state.bindings.exportFileURL = fileURL
        } catch let error as BipeAPIError {
            MXLog.error("Bipe data export failed: \(error)")
            if case .server(.rateLimited, _, _) = error {
                showError(BipeStrings.errorRateLimited)
            } else {
                showError(BipeStrings.privacyExportError)
            }
        } catch {
            MXLog.error("Bipe data export could not write the file: \(error)")
            showError(BipeStrings.privacyExportError)
        }
    }
    
    private var exportedFile: URL?
    
    /// The file leaves the device only through the share sheet; remove the copy after it closes.
    private func removeExportFile() {
        if let exportedFile {
            try? FileManager.default.removeItem(at: exportedFile)
        }
        exportedFile = nil
        state.bindings.exportFileURL = nil
    }
    
    // MARK: - Private
    
    private func showError(_ message: String) {
        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: message)
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
}
