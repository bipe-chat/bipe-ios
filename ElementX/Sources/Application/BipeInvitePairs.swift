//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Invite pairs (bipe ADR 0034): the people this account invited who joined, and its own inviter.
/// A direct-chat invite from one of them skips Pedidos and is accepted without a tap.
@MainActor
final class BipeInvitePairs {
    private let clientProxy: ClientProxyProtocol
    private let apiClient: BipeAPIClient
    private let store: BipeInviteStore
    private var userIDs: Set<String>
    /// Rooms already tried, so a failing join is not retried on every room list update.
    private var attemptedRoomIDs = Set<String>()
    /// Request rooms that already caused a refresh: a new invitee's first chat can arrive before the pairs know them.
    private var recheckedRoomIDs = Set<String>()
    
    init(clientProxy: ClientProxyProtocol, apiBaseURL: URL) {
        self.clientProxy = clientProxy
        apiClient = BipeAPIClient(baseURL: apiBaseURL)
        store = BipeInviteStore(userID: clientProxy.userID)
        userIDs = store.invitePairs()
    }
    
    func contains(_ userID: String?) -> Bool {
        userID.map(userIDs.contains) ?? false
    }
    
    /// Reloads the pairs from the Bipe API. Returns true when they changed.
    func refresh() async -> Bool {
        do {
            let fresh = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) -> [String] in
                try await apiClient.inviteConnections(accessToken: token)
            }
            let freshSet = Set(fresh)
            guard freshSet != userIDs else { return false }
            userIDs = freshSet
            store.setInvitePairs(freshSet)
            return true
        } catch {
            MXLog.error("Bipe invite pairs refresh failed: \(error)")
            return false
        }
    }
    
    /// Reloads the pairs once for a direct-chat invite from an unknown sender. Calls `onChange` when the pairs changed.
    func recheck(roomID: String, onChange: @escaping @MainActor () -> Void) {
        guard recheckedRoomIDs.insert(roomID).inserted else { return }
        Task {
            if await refresh() {
                onChange()
            }
        }
    }
    
    /// Joins a direct-chat invite from an invite pair, once per room. Then a waiting invite note can go (ADR 0136).
    func autoAccept(roomID: String) {
        guard attemptedRoomIDs.insert(roomID).inserted else { return }
        Task { [apiClient, clientProxy] in
            switch await clientProxy.joinRoom(roomID, via: []) {
            case .success:
                await BipeInviteNoteSender(apiClient: apiClient, clientProxy: clientProxy).run(joinedRoomID: roomID)
            case .failure(let error):
                MXLog.error("Bipe auto-accept of invite-pair chat \(roomID) failed: \(error)")
            }
        }
    }
}
