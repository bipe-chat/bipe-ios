//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// The self-chat in the Você tab (bipe ADR 0053): an encrypted room with only this account.
/// Its room ID lives in global account data, so every device opens the same room.
/// Android uses the same event type and content shape.
@MainActor
final class BipeSelfChat {
    static let accountDataType = "chat.bipe.self_chat"
    /// Posted when the cached room ID changes. The room lists hide the room again: the new room
    /// reaches them before `createRoom` returns, and an empty room sends no later update.
    static let cachedRoomIDDidChange = Notification.Name("BipeSelfChatCachedRoomIDDidChange")
    
    private struct Content: Codable {
        let roomID: String
        
        enum CodingKeys: String, CodingKey {
            case roomID = "room_id"
        }
    }
    
    private let clientProxy: ClientProxyProtocol
    
    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }
    
    /// The last known self-chat room ID on this device. The room lists hide this room.
    var cachedRoomID: String? {
        UserDefaults.standard.string(forKey: cacheKey)
    }
    
    /// Reads the room ID from account data into the cache.
    func refresh() async {
        guard let roomID = await storedRoomID() else { return }
        cache(roomID)
    }
    
    /// Returns the self-chat room ID. Creates the room when it does not exist or was left.
    func roomID() async -> String? {
        if let roomID = await storedRoomID(), case .joined = await clientProxy.roomForIdentifier(roomID) {
            cache(roomID)
            return roomID
        }
        
        guard case .success(let roomID) = await clientProxy.createRoom(name: BipeStrings.selfChatTitle,
                                                                       topic: nil,
                                                                       accessType: .private,
                                                                       isSpace: false,
                                                                       userIDs: [],
                                                                       avatarURL: nil,
                                                                       aliasLocalPart: nil) else {
            return nil
        }
        
        // Cache first: the room list must hide the room even if the account data write fails.
        cache(roomID)
        
        guard let data = try? JSONEncoder().encode(Content(roomID: roomID)),
              let content = String(data: data, encoding: .utf8),
              case .success = await clientProxy.bipeSetAccountData(eventType: Self.accountDataType, content: content) else {
            MXLog.error("Failed storing the self-chat room ID")
            return roomID
        }
        
        return roomID
    }
    
    // MARK: - Private
    
    private var cacheKey: String {
        "bipe.selfChat.\(clientProxy.userID)"
    }
    
    private func cache(_ roomID: String) {
        guard roomID != cachedRoomID else { return }
        UserDefaults.standard.set(roomID, forKey: cacheKey)
        NotificationCenter.default.post(name: Self.cachedRoomIDDidChange, object: nil)
    }
    
    private func storedRoomID() async -> String? {
        guard let json = await clientProxy.bipeAccountData(eventType: Self.accountDataType),
              let content = try? JSONDecoder().decode(Content.self, from: Data(json.utf8)) else {
            return nil
        }
        return content.roomID
    }
}
