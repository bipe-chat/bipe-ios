//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

/// Invite pairs (proseio ADR 0034): the people this account invited who joined, and its own inviter.
/// A direct-chat invite from one of them skips Pedidos and is accepted without a tap.
@MainActor
final class ProseioInvitePairs {
    private let clientProxy: ClientProxyProtocol
    private let apiClient: ProseioAPIClient
    private let store: ProseioInviteStore
    private var userIDs: Set<String>
    /// Rooms already tried, so a failing join is not retried on every room list update.
    private var attemptedRoomIDs = Set<String>()
    /// Request rooms that already caused a refresh: a new invitee's first chat can arrive before the pairs know them.
    private var recheckedRoomIDs = Set<String>()
    
    init(clientProxy: ClientProxyProtocol, apiBaseURL: URL) {
        self.clientProxy = clientProxy
        apiClient = ProseioAPIClient(baseURL: apiBaseURL)
        store = ProseioInviteStore(userID: clientProxy.userID)
        userIDs = store.invitePairs()
    }
    
    func contains(_ userID: String?) -> Bool {
        userID.map(userIDs.contains) ?? false
    }
    
    /// Reloads the pairs from the Proseio API. Returns true when they changed.
    func refresh() async -> Bool {
        do {
            let fresh = try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(ProseioAPIError) -> [String] in
                try await apiClient.inviteConnections(accessToken: token)
            }
            let freshSet = Set(fresh)
            guard freshSet != userIDs else { return false }
            userIDs = freshSet
            store.setInvitePairs(freshSet)
            return true
        } catch {
            MXLog.error("Proseio invite pairs refresh failed: \(error)")
            return false
        }
    }
    
    /// Reloads the pairs once for a direct-chat invite from an unknown sender. Calls `onChange` when the pairs changed.
    func recheck(roomID: String, onChange: @escaping @MainActor () -> Void) {
        guard recheckedRoomIDs.insert(roomID).inserted else { return }
        Task {
            if await refresh() { onChange() }
        }
    }
    
    /// Joins a direct-chat invite from an invite pair, once per room.
    func autoAccept(roomID: String) {
        guard attemptedRoomIDs.insert(roomID).inserted else { return }
        Task {
            if case .failure(let error) = await clientProxy.joinRoom(roomID, via: []) {
                MXLog.error("Proseio auto-accept of invite-pair chat \(roomID) failed: \(error)")
            }
        }
    }
}
