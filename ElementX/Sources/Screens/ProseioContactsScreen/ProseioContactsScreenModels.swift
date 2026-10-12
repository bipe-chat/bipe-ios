//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

enum ProseioContactsScreenViewModelAction {
    case openUserProfile(userID: String)
    case openInvites
}

enum ProseioContactsAccess {
    case unknown, notDetermined, denied, granted
}

struct ProseioContactsScreenMatch: Identifiable, Equatable {
    let userID: String
    /// The name in the user's own address book.
    let contactName: String
    
    var id: String { userID }
}

struct ProseioContactsScreenViewState: BindableState {
    var access = ProseioContactsAccess.unknown
    var isLoading = false
    var matches: [ProseioContactsScreenMatch] = []
    var hasSearched = false
    /// `nil` until the status loads.
    var phoneLinked: Bool?
    
    var bindings = ProseioContactsScreenViewStateBindings()
}

struct ProseioContactsScreenViewStateBindings {
    var discoverableByPhone = true
    var alertInfo: AlertInfo<ProseioContactsScreenAlertType>?
}

enum ProseioContactsScreenAlertType: Hashable {
    case error
}

enum ProseioContactsScreenViewAction {
    case requestAccess
    case discoverableChanged
    case openUserProfile(userID: String)
    case openInvites
}
