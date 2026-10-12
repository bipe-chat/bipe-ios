//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

/// Tells the inviter, once per join, that someone joined with their invite: a toast when the app opens.
/// The first check on a device only records existing joins, so old joins are not announced.
@MainActor
struct ProseioInviteJoinNotifier {
    let apiBaseURL: URL
    let clientProxy: ClientProxyProtocol
    let handleResolver: ProseioHandleResolver?
    let userIndicatorController: UserIndicatorControllerProtocol
    
    func run() async {
        let store = ProseioInviteStore(userID: clientProxy.userID)
        let apiClient = ProseioAPIClient(baseURL: apiBaseURL)
        let myInvites: ProseioMyInvites
        do {
            myInvites = try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
        } catch {
            MXLog.error("Proseio invite join check failed: \(error)")
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
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.invitesJoined(name), icon: \.userAdd))
        }
    }
}
