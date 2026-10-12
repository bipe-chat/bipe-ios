//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

/// The self-chat in the Você tab (proseio ADR 0053): an encrypted room with only this account.
/// Its room ID lives in global account data, so every device opens the same room.
/// Android uses the same event type and content shape.
@MainActor
final class ProseioSelfChat {
    static let accountDataType = "br.com.proseio.self_chat"
    
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
    
    /// Reads the room ID from account data into the cache. Returns true when it changed.
    func refresh() async -> Bool {
        guard let roomID = await storedRoomID(), roomID != cachedRoomID else { return false }
        UserDefaults.standard.set(roomID, forKey: cacheKey)
        return true
    }
    
    /// Returns the self-chat room ID. Creates the room when it does not exist or was left.
    func roomID() async -> String? {
        if let roomID = await storedRoomID(), case .joined = await clientProxy.roomForIdentifier(roomID) {
            UserDefaults.standard.set(roomID, forKey: cacheKey)
            return roomID
        }
        
        guard case .success(let roomID) = await clientProxy.createRoom(name: ProseioStrings.selfChatTitle,
                                                                       topic: nil,
                                                                       accessType: .private,
                                                                       isSpace: false,
                                                                       userIDs: [],
                                                                       avatarURL: nil,
                                                                       aliasLocalPart: nil) else {
            return nil
        }
        
        // Cache first: the room list must hide the room even if the account data write fails.
        UserDefaults.standard.set(roomID, forKey: cacheKey)
        
        guard let data = try? JSONEncoder().encode(Content(roomID: roomID)),
              let content = String(data: data, encoding: .utf8),
              case .success = await clientProxy.proseioSetAccountData(eventType: Self.accountDataType, content: content) else {
            MXLog.error("Failed storing the self-chat room ID")
            return roomID
        }
        
        return roomID
    }
    
    // MARK: - Private
    
    private var cacheKey: String {
        "proseio.selfChat.\(clientProxy.userID)"
    }
    
    private func storedRoomID() async -> String? {
        guard let json = await clientProxy.proseioAccountData(eventType: Self.accountDataType),
              let content = try? JSONDecoder().decode(Content.self, from: Data(json.utf8)) else {
            return nil
        }
        return content.roomID
    }
}
