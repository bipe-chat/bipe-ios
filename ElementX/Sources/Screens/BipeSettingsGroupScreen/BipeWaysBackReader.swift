//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

/// Bipe: counts the ways back to the account from what the app already reads (ADR 0112). There is no API for it.
enum BipeWaysBackReader {
    /// Each count made from a loaded account state, with the user ID. The Você tab badge follows it.
    static let counted = PassthroughSubject<(userID: String, waysBack: BipeWaysBack), Never>()
    
    /// `status` is `GET /v1/me/account`, `nil` when it did not load.
    static func waysBack(status: BipeAccountStatus?, clientProxy: ClientProxyProtocol) -> BipeWaysBack {
        let waysBack = BipeWaysBack(email: status?.email != nil,
                                    // ADR 0096: no linked-account screen on iOS yet (bipe#307).
                                    linkedAccount: false,
                                    recoveryKey: clientProxy.secureBackupController.recoveryState.value == .enabled,
                                    syncedToken: BipeCredentialStore.bipeApp.recoveryToken()?.userID == clientProxy.userID)
        // Without the account state the email is unknown: no count goes to the tab.
        if status != nil {
            counted.send((clientProxy.userID, waysBack))
        }
        return waysBack
    }
    
    /// Loads the account state, then counts. The status is `nil` when the call fails.
    static func load(apiClient: BipeAPIClient, clientProxy: ClientProxyProtocol) async -> (status: BipeAccountStatus?, waysBack: BipeWaysBack) {
        var status: BipeAccountStatus?
        do {
            status = try await BipeAPIClient.withTokenRetry(accessToken: { clientProxy.accessToken }) { (token: String) async throws(BipeAPIError) -> BipeAccountStatus in
                try await apiClient.account(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe account state load failed: \(error)")
        }
        return (status, waysBack(status: status, clientProxy: clientProxy))
    }
}
