//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import MatrixRustSDK

/// Which rooms a home tab lists (bipe ADR 0053).
/// Conversas: direct chats and DM invites (they become Pedidos). Grupos: rooms that are not direct chats, joined or invited.
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
        case .chats: .category(expect: .people)
        case .groups: .all(filters: [.category(expect: .group), .any(filters: [.joined, .invite])])
        }
    }
    
    /// Filter chips that make no sense inside the tab. Archived chats open from their own row, not a chip.
    var hiddenFilters: Set<RoomListFilter> {
        switch self {
        case .chats: [.people, .rooms, .lowPriority]
        case .groups: [.people, .rooms, .invites, .lowPriority]
        }
    }
    
    /// Swift mirror of `rustFilter` for tab badges and routing.
    /// Bipe (bipe#524): the SDK `isDm` is the one DM test. The client's `.twoMembers` definition is `m.direct` and at most 2 active members.
    init(summary: RoomSummary) {
        self = summary.isDM ? .chats : .groups
    }
}
