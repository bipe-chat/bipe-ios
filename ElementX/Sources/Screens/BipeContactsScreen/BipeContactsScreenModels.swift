//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipeContactsScreenViewModelAction {
    case openUserProfile(userID: String)
    case openInvites
}

enum BipeContactsAccess {
    case unknown, notDetermined, denied, granted
}

struct BipeContactsScreenMatch: Identifiable, Equatable {
    let userID: String
    /// The name in the user's own address book.
    let contactName: String
    
    var id: String {
        userID
    }
}

struct BipeContactsScreenViewState: BindableState {
    var access = BipeContactsAccess.unknown
    var isLoading = false
    var matches: [BipeContactsScreenMatch] = []
    var hasSearched = false
    /// `nil` until the status loads.
    var phoneLinked: Bool?
    
    var bindings = BipeContactsScreenViewStateBindings()
}

struct BipeContactsScreenViewStateBindings {
    var discoverableByPhone = true
    var alertInfo: AlertInfo<BipeContactsScreenAlertType>?
}

enum BipeContactsScreenAlertType: Hashable {
    case error
}

enum BipeContactsScreenViewAction {
    case requestAccess
    case discoverableChanged
    case openUserProfile(userID: String)
    case openInvites
}
