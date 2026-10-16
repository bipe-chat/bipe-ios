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
@MainActor
final class BipeRecoveryAlerts {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let defaults: UserDefaults
    
    private var isChecking = false
    /// IDs shown in this run, so a foreground event during an open alert does not stack a second one.
    private var shownThisRun: Set<String> = []
    
    private static let acknowledgeTokenRecoveriesKey = "bipe.recoveries.acknowledgeCompletedTokens"
    
    init(apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         navigationRootCoordinator: NavigationRootCoordinator,
         userIndicatorController: UserIndicatorControllerProtocol,
         defaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.navigationRootCoordinator = navigationRootCoordinator
        self.userIndicatorController = userIndicatorController
        self.defaults = defaults
    }
    
    /// This device redeemed a token. Its own completed token recovery must not alert it.
    static func acknowledgeCompletedTokenRecoveriesOnNextCheck(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: acknowledgeTokenRecoveriesKey)
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
            return
        }
        
        var acknowledged = acknowledgedIDs()
        let completedTokens = status.recoveries.filter { $0.state == .completed && $0.method == .token }.map(\.id)
        // First check of this account on this device, or right after this device's own token recovery.
        if acknowledged == nil || defaults.bool(forKey: Self.acknowledgeTokenRecoveriesKey) {
            acknowledged = (acknowledged ?? []).union(completedTokens)
            setAcknowledgedIDs(acknowledged ?? [])
            defaults.removeObject(forKey: Self.acknowledgeTokenRecoveriesKey)
        }
        
        let next = status.recoveries.first { recovery in
            recovery.alertMessage != nil && !(acknowledged ?? []).contains(recovery.id) && !shownThisRun.contains(recovery.id)
        }
        guard let next, let message = next.alertMessage else { return }
        shownThisRun.insert(next.id)
        show(next, message: message)
    }
    
    // MARK: - Private
    
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
        "bipe.recoveries.acknowledged.\(clientProxy.userID)"
    }
    
    private func acknowledgedIDs() -> Set<String>? {
        defaults.stringArray(forKey: acknowledgedKey).map(Set.init)
    }
    
    private func setAcknowledgedIDs(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: acknowledgedKey)
    }
}
