//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum StartChatScreenErrorType: Error {
    case failedCreatingRoom
    case bipeInvite
}

enum StartChatScreenViewModelAction: Equatable {
    case close
    case createRoom
    case showRoom(roomID: String)
    case openRoomDirectorySearch
}

struct StartChatScreenViewState: BindableState {
    let userID: String
    var bindings = StartChatScreenViewStateBindings()
    var usersSection: UserDiscoverySection = .init(type: .suggestions, users: [])
    /// Bipe: the handle in the query when nobody holds it.
    var bipeHandleNotFound: String?
    /// Bipe ADR 0111: the inviter while the user has not messaged them yet.
    var bipeInviter: (profile: UserProfile, handle: String)?
    
    var isSearching: Bool {
        !bindings.searchQuery.isEmpty
    }
    
    var hasEmptySearchResults: Bool {
        isSearching && usersSection.type == .searchResult && usersSection.users.isEmpty
    }
    
    var joinByAddressState: JoinByAddressState = .example
}

struct StartChatScreenViewStateBindings {
    var searchQuery = ""
    var roomAddress = ""
    
    /// Information describing the currently displayed alert.
    var alertInfo: AlertInfo<StartChatScreenErrorType>?
    
    var selectedUserToInvite: UserToInvite?
    var isJoinRoomByAddressSheetPresented = false
    var bipeInviteShareLink: BipeInviteShareLink?
}

enum StartChatScreenViewAction {
    case close
    case createRoom
    case createDM(user: UserProfile)
    case selectUser(UserProfile)
    case joinRoomByAddress
    case openRoomDirectorySearch
    case bipeInviteToApp
}

enum JoinByAddressState: Equatable {
    case example
    case invalidAddress
    case addressNotFound
    case addressFound(address: String, roomID: String)
}
