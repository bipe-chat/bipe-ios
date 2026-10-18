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
    /// Names the person gave their invites on this device, by invite ID.
    var names: [String: String] = [:]
    
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
        BipeInviteQuota.footer(available: isLoading ? nil : available, nextAvailableAt: nextAvailableAt)
    }
}

struct BipeInvitesScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeInvitesScreenAlertType>?
    var shareSheetLink: BipeInviteShareLink?
    var qrCodeLink: BipeInviteShareLink?
    var namingInviteID: String?
    var nameDraft = ""
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
    case startNaming(inviteID: String)
    case saveName
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
