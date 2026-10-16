//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Foundation

/// Bipe ADR 0034: after a personal-invite sign-up, the chat list and the chat with the inviter
/// prompt the new user to message the inviter, until the user sends a first message there.
extension ClientProxyProtocol {
    /// The existing direct chat with a user, or a new one. `nil` when both fail.
    func bipeDirectRoom(with userID: String) async -> String? {
        if let roomID = try? directRoomForUserID(userID).get() {
            return roomID
        }
        switch await createDirectRoom(with: userID, expectedRoomName: nil) {
        case .success(let roomID):
            return roomID
        case .failure(let error):
            MXLog.error("Bipe: could not open a chat with \(userID): \(error)")
            return nil
        }
    }

    var bipeInviterGreeting: BipeInviterGreeting? {
        BipeInviteStore(userID: userID).inviterGreeting()
    }

    /// Ends the prompt. Called when the user sends a message in the chat with the inviter.
    func bipeEndInviterGreeting() {
        guard bipeInviterGreeting != nil else { return }
        BipeInviteStore(userID: userID).setInviterGreeting(nil)
    }
}

extension BipeInviterGreeting {
    /// The handle for the prompt: the live handle when the resolver knows it, else the one from the invite preview.
    @MainActor
    func displayHandle(resolver: BipeHandleResolver?) async -> String? {
        if let handle = await resolver?.resolve(userID) {
            return handle
        }
        return handle
    }
}
