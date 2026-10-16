//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import MatrixRustSDK

/// Which rooms a home tab lists (bipe ADR 0053).
/// Conversas: direct chats and every invite (DM invites become Pedidos). Grupos: joined rooms that are not direct chats.
enum BipeRoomListScope {
    case chats
    case groups
    
    var title: String {
        switch self {
        case .chats: BipeStrings.tabChats
        case .groups: BipeStrings.tabGroups
        }
    }
    
    /// Added to every filter of the tab's room summary provider. The SDK category puts the DM flag first, then the member count.
    var rustFilter: RoomListEntriesDynamicFilterKind {
        switch self {
        case .chats: .any(filters: [.category(expect: .people), .invite])
        case .groups: .all(filters: [.category(expect: .group), .joined])
        }
    }
    
    /// Filter chips that make no sense inside the tab.
    var hiddenFilters: Set<RoomListFilter> {
        switch self {
        case .chats: [.people, .rooms]
        case .groups: [.people, .rooms, .invites]
        }
    }
    
    /// Swift mirror of `rustFilter` for tab badges and routing.
    init(summary: RoomSummary) {
        if summary.joinRequestType?.isInvite == true || (summary.isDirect && summary.activeMembersCount <= 2) {
            self = .chats
        } else {
            self = .groups
        }
    }
}
