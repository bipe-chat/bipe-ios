//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// The old-device side of recovery (ADR 0057, ADR 0059, security.md rule 6). Reads `GET /v1/me/account` when the
/// app comes to the foreground and shows each waiting recovery with a cancel button, and each completed token
/// recovery once as a notice. A recovery the user answered "It was me" to does not show again on this device.
/// The same read asks for the terms again when the account's version is not the current one (ADR 0113).
@MainActor
final class BipeRecoveryAlerts {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let defaults: UserDefaults
    /// Shows the terms re-accept screen. Only after a successful read: the server is the authority, so errors fail open.
    private let onTermsOutdated: () -> Void
    
    private var isChecking = false
    /// Failed reads in a row. At app start the first read often gets a 401 just before the SDK refreshes the token.
    private var failedReads = 0
    private static let retryDelays: [Duration] = [.seconds(3), .seconds(10), .seconds(30)]
    /// IDs shown in this run, so a foreground event during an open alert does not stack a second one.
    private var shownThisRun: Set<String> = []
    
    /// The one flag of all accounts before bipe#265. Read once by the next check, then removed.
    private static let legacyAcknowledgeTokenRecoveriesKey = "bipe.recoveries.acknowledgeCompletedTokens"
    private var acknowledgeTokenRecoveriesKey: String {
        Self.acknowledgeTokenRecoveriesKey(for: clientProxy.userID)
    }
    
    init(apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         navigationRootCoordinator: NavigationRootCoordinator,
         userIndicatorController: UserIndicatorControllerProtocol,
         defaults: UserDefaults = .standard,
         onTermsOutdated: @escaping () -> Void) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.navigationRootCoordinator = navigationRootCoordinator
        self.userIndicatorController = userIndicatorController
        self.defaults = defaults
        self.onTermsOutdated = onTermsOutdated
    }
    
    /// This device redeemed a token of `userID`. Its own completed token recovery must not alert it.
    static func acknowledgeCompletedTokenRecoveriesOnNextCheck(for userID: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: acknowledgeTokenRecoveriesKey(for: userID))
    }
    
    /// ADR 0140: the device that asked for the deletion does not get the cancel alert.
    static func acknowledgeDeletion(_ deletion: BipeAccountDeletion, for userID: String, defaults: UserDefaults = .standard) {
        let key = acknowledgedKey(for: userID)
        let ids = Set(defaults.stringArray(forKey: key) ?? []).union([deletionAlertID(deletion)])
        defaults.set(ids.sorted(), forKey: key)
    }
    
    private static func deletionAlertID(_ deletion: BipeAccountDeletion) -> String {
        "deletion:\(Int(deletion.createdAt.timeIntervalSince1970))"
    }
    
    private static func acknowledgeTokenRecoveriesKey(for userID: String) -> String {
        "bipe.recoveries.acknowledgeCompletedTokens.\(userID)"
    }
    
    func check() async {
        guard !isChecking, navigationRootCoordinator.alertInfo == nil else { return }
        isChecking = true
        defer { isChecking = false }
        
        let status: BipeAccountStatus
        do {
            status = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) -> BipeAccountStatus in
                try await apiClient.account(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe account state check failed: \(error)")
            scheduleRetry()
            return
        }
        failedReads = 0
        BipeAccountCap.onServerValue(status.maxAccounts)
        if let accountType = status.accountType {
            BipeAccountLabels.rememberCompany(accountType == .company, for: clientProxy.userID)
        }
        
        var acknowledged = acknowledgedIDs()
        let completedTokens = status.recoveries.filter { $0.state == .completed && $0.method == .token }.map(\.id)
        // First check of this account on this device, or right after this device's own token recovery.
        if acknowledged == nil || defaults.bool(forKey: acknowledgeTokenRecoveriesKey) || defaults.bool(forKey: Self.legacyAcknowledgeTokenRecoveriesKey) {
            acknowledged = (acknowledged ?? []).union(completedTokens)
            setAcknowledgedIDs(acknowledged ?? [])
            defaults.removeObject(forKey: acknowledgeTokenRecoveriesKey)
            defaults.removeObject(forKey: Self.legacyAcknowledgeTokenRecoveriesKey)
        }
        
        // No version (an account from before ADR 0113) counts as outdated. The screen covers the app and an alert
        // cannot show over it, so recovery alerts wait: acceptance runs this check again.
        if status.termsVersion != BipeRegistries.legalVersion {
            onTermsOutdated()
            return
        }
        
        // ADR 0140: a waiting deletion that another device asked for comes before the recoveries.
        if let deletion = status.deletion {
            let id = Self.deletionAlertID(deletion)
            if !(acknowledged ?? []).contains(id), !shownThisRun.contains(id) {
                shownThisRun.insert(id)
                showDeletion(deletion, id: id)
                return
            }
        }
        
        let next = status.recoveries.first { recovery in
            recovery.alertMessage != nil && !(acknowledged ?? []).contains(recovery.id) && !shownThisRun.contains(recovery.id)
        }
        guard let next, let message = next.alertMessage else { return }
        shownThisRun.insert(next.id)
        show(next, message: message)
    }
    
    // MARK: - Private
    
    /// Without a retry, a failed first read waits for the next foreground, and the terms screen does not show.
    private func scheduleRetry() {
        guard failedReads < Self.retryDelays.count else { return }
        let delay = Self.retryDelays[failedReads]
        failedReads += 1
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            await self?.check()
        }
    }
    
    private func show(_ recovery: BipeRecovery, message: String) {
        let keep = AlertInfoButton(title: BipeStrings.recoveryAlertKeep, role: .cancel) { [weak self] in
            self?.acknowledge(recovery.id)
        }
        
        guard recovery.canBeCancelled else {
            navigationRootCoordinator.alertInfo = AlertInfo(id: UUID(), title: BipeStrings.recoveryAlertTitle, message: message, primaryButton: keep)
            return
        }
        
        let cancel = AlertInfoButton(title: BipeStrings.recoveryAlertCancel, role: .destructive) { [weak self] in
            Task { await self?.cancel(recovery) }
        }
        navigationRootCoordinator.alertInfo = AlertInfo(id: UUID(),
                                                        title: BipeStrings.recoveryAlertTitle,
                                                        message: message,
                                                        primaryButton: cancel,
                                                        secondaryButton: keep)
    }
    
    private func showDeletion(_ deletion: BipeAccountDeletion, id: String) {
        let keep = AlertInfoButton(title: BipeStrings.recoveryAlertKeep, role: .cancel) { [weak self] in
            self?.acknowledge(id)
        }
        let cancel = AlertInfoButton(title: BipeStrings.recoveryAlertCancel, role: .destructive) { [weak self] in
            Task { await self?.cancelDeletion(id: id) }
        }
        navigationRootCoordinator.alertInfo = AlertInfo(id: UUID(),
                                                        title: BipeStrings.accountDeleteAlertTitle,
                                                        message: BipeStrings.accountDeleteAlertBody(deletion.dueAt.formatted(date: .long, time: .shortened)),
                                                        primaryButton: cancel,
                                                        secondaryButton: keep)
    }
    
    private func cancelDeletion(id: String) async {
        do {
            try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.cancelDeletion(accessToken: token)
            }
            acknowledge(id)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.accountDeleteCancelled, icon: \.checkCircle))
        } catch {
            MXLog.error("Bipe account deletion cancel failed: \(error)")
            shownThisRun.remove(id)
            userIndicatorController.submitIndicator(UserIndicator(title: error.localizedMessage))
        }
    }
    
    private func cancel(_ recovery: BipeRecovery) async {
        do {
            try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.cancelRecovery(id: recovery.id, accessToken: token)
            }
            acknowledge(recovery.id)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.recoveryAlertCancelled, icon: \.checkCircle))
        } catch {
            MXLog.error("Bipe recovery cancel failed: \(error)")
            // Not acknowledged: the alert comes back on the next check.
            shownThisRun.remove(recovery.id)
            userIndicatorController.submitIndicator(UserIndicator(title: error.localizedMessage))
        }
    }
    
    private func acknowledge(_ id: String) {
        setAcknowledgedIDs((acknowledgedIDs() ?? []).union([id]))
    }
    
    private var acknowledgedKey: String {
        Self.acknowledgedKey(for: clientProxy.userID)
    }
    
    private static func acknowledgedKey(for userID: String) -> String {
        "bipe.recoveries.acknowledged.\(userID)"
    }
    
    private func acknowledgedIDs() -> Set<String>? {
        defaults.stringArray(forKey: acknowledgedKey).map(Set.init)
    }
    
    private func setAcknowledgedIDs(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: acknowledgedKey)
    }
}
