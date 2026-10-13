//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipeInvitesScreenViewModelAction {
    case openUserProfile(userID: String)
}

struct BipeInvitesScreenViewState: BindableState {
    var isLoading = true
    var quota = 0
    var available = 0
    var nextAvailableAt: Date?
    var invites: [BipeInvite] = []
    /// Links for pending invites created on this device (kept in the keychain). The server keeps only a hash of each code.
    var shareURLs: [String: URL] = [:]
    
    var bindings = BipeInvitesScreenViewStateBindings()
    
    var canCreate: Bool {
        !isLoading && available > 0
    }
    
    var footer: String {
        guard !isLoading, available == 0 else { return BipeStrings.invitesExplainer }
        guard let nextAvailableAt else { return BipeStrings.invitesNoneLeft }
        return "\(BipeStrings.invitesNoneLeft) \(BipeStrings.invitesNext(nextAvailableAt.formatted(date: .abbreviated, time: .shortened)))"
    }
}

struct BipeInvitesScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeInvitesScreenAlertType>?
}

enum BipeInvitesScreenAlertType: Hashable {
    case error
}

enum BipeInvitesScreenViewAction {
    case create
    case revoke(inviteID: String)
    case openUserProfile(userID: String)
}

extension BipeInviteStatus {
    var title: String {
        switch self {
        case .pending: BipeStrings.invitesStatusPending
        case .used: BipeStrings.invitesStatusUsed
        case .expired: BipeStrings.invitesStatusExpired
        case .revoked: BipeStrings.invitesStatusRevoked
        }
    }
}
