//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Tells the inviter, once per join, that someone joined with their invite: a toast when the app opens.
/// The first check on a device only records existing joins, so old joins are not announced.
@MainActor
struct BipeInviteJoinNotifier {
    let apiBaseURL: URL
    let clientProxy: ClientProxyProtocol
    let handleResolver: BipeHandleResolver?
    let userIndicatorController: UserIndicatorControllerProtocol
    
    func run() async {
        let store = BipeInviteStore(userID: clientProxy.userID)
        let apiClient = BipeAPIClient(baseURL: apiBaseURL)
        let myInvites: BipeMyInvites
        do {
            myInvites = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe invite join check failed: \(error)")
            return
        }
        
        let joined = myInvites.invites.filter { $0.status == .used && $0.joinedUserId != nil }
        let joinedIDs = Set(joined.map(\.id))
        guard let seen = store.seenJoinedInviteIDs() else {
            store.setSeenJoinedInviteIDs(joinedIDs)
            return
        }
        store.setSeenJoinedInviteIDs(seen.union(joinedIDs))
        
        for invite in joined where !seen.contains(invite.id) {
            guard let userID = invite.joinedUserId else { continue }
            _ = await handleResolver?.resolve(userID)
            let name = handleResolver?.displayText(for: userID) ?? userID
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.invitesJoined(name), icon: \.userAdd))
        }
    }
}
