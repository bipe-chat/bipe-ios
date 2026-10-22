//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import Foundation
import UIKit

enum HomeScreenViewModelAction {
    case presentRoom(roomIdentifier: String)
    case detachRoom(roomIdentifier: String)
    case presentRoomDetails(roomIdentifier: String)
    case presentReportRoom(roomIdentifier: String)
    case presentDeclineAndBlock(userID: String, roomID: String)
    case presentSpace(SpaceRoomListProxyProtocol)
    case roomLeft(roomIdentifier: String)
    case transferOwnership(roomIdentifier: String)
    case presentSecureBackupSettings
    case presentRecoveryKeyScreen
    case presentEncryptionResetScreen
    case presentSettingsScreen
    case presentFeedbackScreen
    case presentStartChatScreen
    /// Bipe: the Grupos empty state opens the create room screen directly (ADR 0053).
    case presentCreateGroupScreen
    /// Bipe (bipe#200, bipe#415): the "Escolha seu @" card opens the username screen.
    case presentBipeHandleScreen
    case logout
}

enum HomeScreenViewAction {
    case selectRoom(roomIdentifier: String)
    case detachRoom(roomIdentifier: String)
    case showRoomDetails(roomIdentifier: String)
    case leaveRoom(roomIdentifier: String)
    case confirmLeaveRoom(roomIdentifier: String)
    /// Bipe (bipe#464): "Apagar conversa" replaces leave in a DM.
    case bipeDeleteChat(roomIdentifier: String)
    case reportRoom(roomIdentifier: String)
    case showSettings
    case startChat
    case createGroup
    /// Bipe ADR 0034: the card that opens the chat with the inviter.
    case openBipeInviterChat
    /// Bipe (bipe#200, bipe#415): the "Escolha seu @" card and its "Agora não".
    case openBipeHandlePrompt
    case dismissBipeHandlePrompt
    /// Bipe (ADR 0117, bipe#386): the remote critical banner.
    case openBipeRemoteBanner
    case dismissBipeRemoteBanner
    case setupRecovery
    case confirmRecoveryKey
    case resetEncryption
    case skipRecoveryKeyConfirmation
    case dismissNewSoundBanner
    case updateVisibleItemRange(Range<Int>)
    case spaceFilters
    case markRoomAsUnread(roomIdentifier: String)
    case markRoomAsRead(roomIdentifier: String)
    case markRoomAsFavourite(roomIdentifier: String, isFavourite: Bool)
    /// Bipe: swipe to archive (the `m.lowpriority` tag).
    case setRoomArchived(roomIdentifier: String, isArchived: Bool)
    case setRoomMuted(roomIdentifier: String, isMuted: Bool)
    
    case acceptInvite(roomIdentifier: String)
    case declineInvite(roomIdentifier: String)
}

enum HomeScreenRoomListMode: CustomStringConvertible {
    /// Shows nothing briefly on launch as the cached rooms usually publish in time to go straight to them.
    case awaitingCachedRooms
    case skeletons
    case empty
    case rooms
    
    var description: String {
        switch self {
        case .awaitingCachedRooms:
            return "Awaiting cached rooms"
        case .skeletons:
            return "Showing placeholders"
        case .empty:
            return "Showing empty state"
        case .rooms:
            return "Showing rooms"
        }
    }
}

enum HomeScreenSecurityBannerMode: Equatable {
    case none
    case dismissed
    case show(HomeScreenRecoveryKeyConfirmationBanner.State)
    
    var isDismissed: Bool {
        switch self {
        case .dismissed: true
        default: false
        }
    }
    
    var isShown: Bool {
        switch self {
        case .show: true
        default: false
        }
    }
}

struct HomeScreenViewState: BindableState {
    var userProfile: UserProfile
    
    /// ADR 0087: the company's name in the top bar when the account on screen is a company account.
    var bipeCompanyName: String?
    
    var securityBannerMode = HomeScreenSecurityBannerMode.none
    var shouldShowNewSoundBanner = false
    
    var rooms: [HomeScreenRoom] = []
    var roomListMode: HomeScreenRoomListMode = .awaitingCachedRooms
    
    var hasPendingInvitations = false
    
    /// Bipe: DM invites kept out of the chat list, shown behind the Pedidos row.
    var bipeRequestCount = 0
    
    /// Bipe: the home tab this list belongs to (ADR 0053).
    var bipeScope = BipeRoomListScope.chats
    
    /// Bipe: joined rooms of this tab in the archive.
    var bipeArchivedCount = 0
    
    var shouldShowBipeArchivedRow: Bool {
        bipeArchivedCount > 0 && !bindings.isSearchFieldFocused && !bindings.filtersState.isFiltering && (roomListMode == .rooms || roomListMode == .empty)
    }
    
    var shouldShowBipeRequestsRow: Bool {
        bipeRequestCount > 0 && !bindings.isSearchFieldFocused && !bindings.filtersState.isFiltering && roomListMode == .rooms
    }
    
    /// Bipe ADR 0034: the inviter's handle (without "@") until the user sends them a first message.
    var bipeInviterHandle: String?
    /// The inviter's profile for the row's avatar. It starts with the user ID only and fills in from the server.
    var bipeInviterProfile: UserProfile?
    
    var shouldShowBipeInviterRow: Bool {
        bipeInviterHandle != nil && bipeScope == .chats && !bindings.isSearchFieldFocused && !bindings.filtersState.isFiltering
    }
    
    /// Bipe (bipe#200, bipe#415): the account has no @ and the card was never dismissed.
    var bipeNeedsHandle = false
    
    /// Bipe (ADR 0117, bipe#386): the remote critical banner, above the account tasks. Conversas only.
    var bipeRemoteBanner: BipeRemoteBanner?
    var bipeRemoteBannerState = BipeRemoteBanner.State.hidden
    
    var shouldShowBipeRemoteBanner: Bool {
        bipeRemoteBannerState != .hidden && bipeScope == .chats && !bindings.isSearchFieldFocused && !bindings.filtersState.isFiltering
    }
    
    var shouldShowBipeHandlePrompt: Bool {
        bipeNeedsHandle && bipeScope == .chats && !bindings.isSearchFieldFocused && !bindings.filtersState.isFiltering
    }
    
    var selectedRoomID: String?
    
    var hideInviteAvatars = false
    
    var reportRoomEnabled = false
    
    var shouldShowSpaceFilters = false
    var selectedSpaceFilter: SpaceServiceFilter?
    
    /// Inline room list search is disabled when the dedicated global search tab is shown instead (see `UserSessionFlowCoordinator`).
    var isRoomListSearchEnabled = true
    
    var visibleRooms: [HomeScreenRoom] {
        if roomListMode == .skeletons || roomListMode == .awaitingCachedRooms {
            return placeholderRooms
        }
        
        return rooms
    }
    
    var bindings: HomeScreenViewStateBindings
    
    var placeholderRooms: [HomeScreenRoom] {
        (1...10).map { _ in
            HomeScreenRoom.placeholder()
        }
    }
    
    /// Used to hide all the rooms when the search field is focused and the query is empty
    var shouldHideRoomList: Bool {
        bindings.isSearchFieldFocused && bindings.searchQuery.isEmpty
    }
    
    var shouldShowEmptyFilterState: Bool {
        !bindings.isSearchFieldFocused &&
            (bindings.filtersState.isFiltering || selectedSpaceFilter != nil) &&
            visibleRooms.isEmpty
    }
    
    var shouldShowFilters: Bool {
        !bindings.isSearchFieldFocused && roomListMode == .rooms
    }
    
    var shouldShowBanner: Bool {
        securityBannerMode.isShown || shouldShowNewSoundBanner || shouldShowBipeInviterRow || shouldShowBipeHandlePrompt || shouldShowBipeRemoteBanner
    }
}

struct HomeScreenViewStateBindings {
    var filtersState: RoomListFiltersState
    var searchQuery = ""
    var isSearchFieldFocused = false
    
    var alertInfo: AlertInfo<UUID>?
    var leaveRoomAlertItem: LeaveRoomAlertItem?
    
    var spaceFiltersViewModel: ChatsSpaceFiltersScreenViewModel?
}

enum CallBadgeType {
    case voice, video, none
}

struct HomeScreenRoom: Identifiable, Equatable {
    enum RoomType: Equatable {
        case placeholder
        case room
        case invite(inviterDetails: RoomInviterDetails?)
        case knock
    }
    
    static let placeholderLastMessage = AttributedString("Hidden last message")
    
    /// The list item identifier is it's room identifier.
    let id: String
    
    /// The real room identifier this item points to
    let roomID: String?
    
    let type: RoomType
    
    var inviter: RoomInviterDetails? {
        if case .invite(let inviter) = type {
            return inviter
        }
        return nil
    }
    
    let badges: Badges
    struct Badges: Equatable {
        let isDotShown: Bool
        let notificationCount: UInt
        let isMentionShown: Bool
        let isMuteShown: Bool
        let callBadgeType: CallBadgeType
    }
    
    let name: String
    
    /// Bipe: the SDK `isDm`, the one DM test (bipe#524).
    let isDM: Bool
    
    let isHighlighted: Bool
    
    let isFavourite: Bool
    
    let timestamp: String?
    
    let lastMessage: AttributedString?
    
    enum LastMessageState { case sending, failed }
    let lastMessageState: LastMessageState?
    
    let avatar: RoomAvatar
    
    let statusEmoji: Character?
    
    let canonicalAlias: String?
    
    let isTombstoned: Bool
    
    /// Bipe: the other person in a DM, for the company seal (bipe#252).
    var dmUserID: String?
    
    /// Bipe: archived (the `m.lowpriority` tag). The row's own state picks archive or unarchive, not the open filter.
    var isLowPriority = false
    
    var displayedLastMessage: AttributedString? {
        if isTombstoned {
            // Bipe: grupo, not sala (bipe#508)
            AttributedString(isDM ? BipeStrings.dmTombstonedRow : BipeStrings.groupScreenRoomlistTombstonedRoomDescription) // Bipe: bipe#507
        } else if lastMessageState == .failed {
            AttributedString(L10n.commonMessageFailedToSend)
        } else {
            lastMessage
        }
    }
    
    static func placeholder() -> HomeScreenRoom {
        HomeScreenRoom(id: UUID().uuidString,
                       roomID: nil,
                       type: .placeholder,
                       badges: .init(isDotShown: false, notificationCount: 0, isMentionShown: false, isMuteShown: false, callBadgeType: .none),
                       name: "Placeholder room name",
                       isDM: false,
                       isHighlighted: false,
                       isFavourite: false,
                       timestamp: "Now",
                       lastMessage: placeholderLastMessage,
                       lastMessageState: nil,
                       avatar: .room(id: "", name: "", avatarURL: nil),
                       statusEmoji: nil,
                       canonicalAlias: nil,
                       isTombstoned: false)
    }
}

extension HomeScreenRoom {
    init(summary: RoomSummary,
         showAllActivity: Bool = true,
         seenInvites: Set<String> = []) {
        let roomID = summary.id
        
        let isUnseenInvite = summary.joinRequestType?.isInvite == true && !seenInvites.contains(roomID)
        
        let isDotShown = if showAllActivity {
            summary.hasUnreadMessages || summary.hasUnreadMentions || summary.hasUnreadNotifications || summary.isMarkedUnread || isUnseenInvite
        } else {
            (!summary.isMuted && (summary.hasUnreadNotifications || summary.hasUnreadMentions)) || summary.isMarkedUnread || isUnseenInvite
        }
        
        let isMentionShown = summary.hasUnreadMentions && !summary.isMuted
        let isMuteShown = summary.isMuted
        let isHighlighted = summary.isMarkedUnread || (!summary.isMuted && (summary.hasUnreadNotifications || summary.hasUnreadMentions)) || isUnseenInvite
        
        let callBadge = if summary.hasOngoingCall {
            summary.activeCallIntent == .audio ? CallBadgeType.voice : CallBadgeType.video
        } else {
            CallBadgeType.none
        }
        
        let type: HomeScreenRoom.RoomType = switch summary.joinRequestType {
        case .invite(let inviter): .invite(inviterDetails: inviter.map(RoomInviterDetails.init))
        case .knock: .knock
        case .none: .room
        }
        
        self.init(id: roomID,
                  roomID: summary.id,
                  type: type,
                  badges: .init(isDotShown: isDotShown,
                                notificationCount: summary.unreadNotificationsCount,
                                isMentionShown: isMentionShown,
                                isMuteShown: isMuteShown,
                                callBadgeType: callBadge),
                  name: summary.name,
                  isDM: summary.isDM,
                  isHighlighted: isHighlighted,
                  isFavourite: summary.isFavourite,
                  timestamp: summary.lastMessageDate?.formattedMinimal(),
                  lastMessage: summary.lastMessage,
                  lastMessageState: summary.homeScreenLastMessageState,
                  avatar: summary.avatar,
                  statusEmoji: summary.statusEmoji,
                  canonicalAlias: summary.canonicalAlias,
                  isTombstoned: summary.isTombstoned,
                  dmUserID: summary.isDM && summary.heroes.count == 1 ? summary.heroes[0].id : nil,
                  isLowPriority: summary.isLowPriority)
    }
}

private extension RoomSummary {
    var homeScreenLastMessageState: HomeScreenRoom.LastMessageState? {
        if isTombstoned {
            nil
        } else {
            switch lastMessageState {
            case .sending: .sending
            case .failed: .failed
            case .none: .none
            }
        }
    }
}
