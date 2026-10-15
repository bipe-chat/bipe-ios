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
    
    var joinedInvites: [BipeInvite] {
        invites.filter { $0.status == .used && $0.joinedUserId != nil }
    }
    
    /// Expired and cancelled invites are left out: they have no action and only push the useful rows down.
    var pendingInvites: [BipeInvite] {
        invites.filter { $0.status == .pending }
    }
    
    var footer: String {
        guard !isLoading else { return BipeStrings.invitesExplainer }
        guard available > 0 else {
            guard let nextAvailableAt else { return BipeStrings.invitesNoneLeft }
            return "\(BipeStrings.invitesNoneLeft) \(BipeStrings.invitesNext(nextAvailableAt.formatted(date: .abbreviated, time: .shortened)))"
        }
        // A large count means nothing to the person, so it shows only when few invites are left.
        guard available <= Self.lowInviteCount else { return BipeStrings.invitesExplainer }
        return "\(BipeStrings.invitesExplainer) \(BipeStrings.invitesAvailable(String(available)))"
    }
    
    private static let lowInviteCount = 5
}

struct BipeInvitesScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeInvitesScreenAlertType>?
    var shareSheetLink: BipeInviteShareLink?
    var qrCodeLink: BipeInviteShareLink?
}

struct BipeInviteShareLink: Identifiable {
    let id: String
    let url: URL
}

enum BipeInvitesScreenAlertType: Hashable {
    case error
}

enum BipeInvitesScreenViewAction {
    case inviteByLink
    case inviteInPerson
    case share(inviteID: String)
    case showQRCode(inviteID: String)
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
