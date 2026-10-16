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
    
    var id: String { userID }
}

/// A person on Bipe: an address-book match, someone who joined with the user's invite, or both.
struct BipeContactsScreenRow: Identifiable, Equatable {
    let userID: String
    /// `nil` when the person is not in the address book.
    let contactName: String?
    let joinedWithInvite: Bool
    
    var id: String { userID }
}

struct BipeContactsScreenViewState: BindableState {
    var access = BipeContactsAccess.unknown
    var isLoading = false
    var matches: [BipeContactsScreenMatch] = []
    var hasSearched = false
    /// `nil` until the status loads.
    var phoneLinked: Bool?
    
    /// `nil` until the invites load.
    var invitesAvailable: Int?
    var nextInviteAt: Date?
    var joinedUserIDs: [String] = []
    var pendingInviteCount = 0
    
    var bindings = BipeContactsScreenViewStateBindings()
    
    var canCreateInvite: Bool {
        (invitesAvailable ?? 0) > 0
    }
    
    var inviteFooter: String {
        BipeInviteQuota.footer(available: invitesAvailable, nextAvailableAt: nextInviteAt)
    }
    
    /// People who joined with the user's invite come first, so the invites the user sent stay in view.
    var rows: [BipeContactsScreenRow] {
        let joined = Set(joinedUserIDs)
        let namesByUserID = Dictionary(uniqueKeysWithValues: matches.map { ($0.userID, $0.contactName) })
        let joinedRows = joinedUserIDs.map { BipeContactsScreenRow(userID: $0, contactName: namesByUserID[$0], joinedWithInvite: true) }
        let otherRows = matches.filter { !joined.contains($0.userID) }
            .map { BipeContactsScreenRow(userID: $0.userID, contactName: $0.contactName, joinedWithInvite: false) }
        return joinedRows + otherRows
    }
}

struct BipeContactsScreenViewStateBindings {
    var discoverableByPhone = true
    var alertInfo: AlertInfo<BipeContactsScreenAlertType>?
    var shareSheetLink: BipeInviteShareLink?
    var qrCodeLink: BipeInviteShareLink?
}

enum BipeContactsScreenAlertType: Hashable {
    case error
}

enum BipeContactsScreenViewAction {
    case appeared
    case requestAccess
    case discoverableChanged
    case openUserProfile(userID: String)
    case openInvites
    case inviteByLink
    case inviteInPerson
}
