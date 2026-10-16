//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Bipe: counts the ways back to the account from what the app already reads (ADR 0112). There is no API for it.
enum BipeWaysBackReader {
    /// `status` is `GET /v1/me/account`, `nil` when it did not load.
    static func waysBack(status: BipeAccountStatus?, clientProxy: ClientProxyProtocol) -> BipeWaysBack {
        BipeWaysBack(email: status?.email != nil,
                     // ADR 0096: no linked-account screen on iOS yet (bipe#307).
                     linkedAccount: false,
                     recoveryKey: clientProxy.secureBackupController.recoveryState.value == .enabled,
                     syncedToken: BipeCredentialStore.bipeApp.recoveryToken()?.userID == clientProxy.userID)
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
