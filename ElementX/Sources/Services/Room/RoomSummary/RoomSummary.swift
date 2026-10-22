//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// A quick summary of a Room, useful to describe and give quick informations for the room list
nonisolated struct RoomSummary {
    enum JoinRequestType {
        case invite(inviter: RoomMemberProxyProtocol?)
        case knock
        
        var isInvite: Bool {
            switch self {
            case .invite: true
            default: false
            }
        }
    }
    
    enum LastMessageState { case sending, failed }
    
    let room: Room
    
    let id: String
    
    let joinRequestType: JoinRequestType?
    let isJoined: Bool
    
    let name: String
    let isDirect: Bool
    /// Bipe: the SDK `isDm`, the one DM test on every screen (bipe#524). `isDirect` is only the `m.direct` flag.
    var isDM = false
    let isSpace: Bool
    let avatarURL: URL?
    
    let heroes: [UserProfile]
    let activeMembersCount: UInt
    
    let lastMessage: AttributedString?
    let lastMessageDate: Date?
    let lastMessageState: LastMessageState?
    let unreadMessagesCount: UInt
    let unreadMentionsCount: UInt
    let unreadNotificationsCount: UInt
    let notificationMode: RoomNotificationModeProxy?
    let canonicalAlias: String?
    let alternativeAliases: Set<String>
    
    let hasOngoingCall: Bool
    let activeCallIntent: CallIntent?
    
    let isMarkedUnread: Bool
    let isFavourite: Bool
    let isTombstoned: Bool
    /// Bipe: archived. The Matrix `m.lowpriority` tag, so other clients see the same state.
    var isLowPriority = false
    /// Bipe: `origin_server_ts` (ms) of the latest event, for cleared DMs (bipe#464). `lastMessageDate` has whole seconds only.
    var bipeLatestEventTimestamp: UInt64?
    
    var hasUnreadMessages: Bool {
        unreadMessagesCount > 0
    }
    
    var hasUnreadMentions: Bool {
        unreadMentionsCount > 0
    }
    
    var hasUnreadNotifications: Bool {
        unreadNotificationsCount > 0
    }
    
    var isMuted: Bool {
        notificationMode == .mute
    }
}

nonisolated extension RoomSummary: CustomStringConvertible {
    var description: String {
        """
        RoomSummary: - id: \(id) \
        - isDirect: \(isDirect) \
        - isDM: \(isDM) \
        - unreadMessagesCount: \(unreadMessagesCount) \
        - unreadMentionsCount: \(unreadMentionsCount) \
        - unreadNotificationsCount: \(unreadNotificationsCount) \
        - notificationMode: \(notificationMode?.rawValue ?? "nil")
        """
    }
    
    /// Used where summaries are shown in a list e.g. message forwarding,
    /// global search, share destination list etc.
    var roomListDescription: String {
        if isDM { // Bipe: one DM test (bipe#524)
            return canonicalAlias ?? ""
        }
        
        if let alias = canonicalAlias {
            return alias
        }
        
        guard !heroes.isEmpty else {
            return ""
        }
        
        var heroComponents = heroes.compactMap(\.displayName)
        
        let othersCount = Int(activeMembersCount) - heroes.count
        if othersCount > 0 {
            heroComponents.append(L10n.commonManyMembers(othersCount))
        }
        
        return heroComponents.formatted(.list(type: .and))
    }
}

nonisolated extension RoomSummary {
    /// An empty summary used when the room info is momentarily unavailable (e.g. while the client tears
    /// down on logout). Keeps the diff indices aligned with the SDK instead of crashing.
    nonisolated static func placeholder(room: Room) -> RoomSummary {
        RoomSummary(room: room,
                    id: room.id(),
                    joinRequestType: nil,
                    isJoined: false,
                    name: room.id(),
                    isDirect: false,
                    isSpace: false,
                    avatarURL: nil,
                    heroes: [],
                    activeMembersCount: 0,
                    lastMessage: nil,
                    lastMessageDate: nil,
                    lastMessageState: nil,
                    unreadMessagesCount: 0,
                    unreadMentionsCount: 0,
                    unreadNotificationsCount: 0,
                    notificationMode: nil,
                    canonicalAlias: nil,
                    alternativeAliases: [],
                    hasOngoingCall: false,
                    activeCallIntent: nil,
                    isMarkedUnread: false,
                    isFavourite: false,
                    isTombstoned: false)
    }
    
    init(room: Room, id: String, settingsMode: RoomNotificationModeProxy, hasUnreadMessages: Bool, hasUnreadMentions: Bool, hasUnreadNotifications: Bool) {
        self.room = room
        self.id = id
        let string = "\(settingsMode) - messages: \(hasUnreadMessages) - mentions: \(hasUnreadMentions) - notifications: \(hasUnreadNotifications)"
        name = string
        isDirect = true
        isDM = true
        isSpace = false
        avatarURL = nil
        
        heroes = []
        activeMembersCount = 0
        
        lastMessage = AttributedString(string)
        lastMessageDate = .mock
        lastMessageState = nil
        unreadMessagesCount = hasUnreadMessages ? 1 : 0
        unreadMentionsCount = hasUnreadMentions ? 1 : 0
        unreadNotificationsCount = hasUnreadNotifications ? 1 : 0
        notificationMode = settingsMode
        canonicalAlias = nil
        alternativeAliases = []
        hasOngoingCall = false
        activeCallIntent = nil
        
        joinRequestType = nil
        isJoined = true
        isMarkedUnread = false
        isFavourite = false
        isTombstoned = false
    }
    
    /// This doesn't have to work properly for DM invites, the heroes are always empty
    var avatar: RoomAvatar {
        guard !isTombstoned else {
            return .tombstoned(isDM: isDM) // Bipe: bipe#507, bipe#524
        }
        
        if isSpace {
            return .space(id: id, name: name, avatarURL: avatarURL)
        } else if isDM, avatarURL == nil, heroes.count == 1 { // Bipe: one DM test (bipe#524)
            return .heroes(heroes)
        } else {
            return .room(id: id, name: name, avatarURL: avatarURL)
        }
    }
    
    var statusEmoji: Character? {
        guard case let .heroes(heroes) = avatar else { return nil }
        return heroes.first?.status.displayed?.emoji
    }
}
