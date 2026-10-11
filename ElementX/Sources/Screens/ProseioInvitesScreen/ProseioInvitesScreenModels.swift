//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

enum ProseioInvitesScreenViewModelAction {
    case openUserProfile(userID: String)
}

struct ProseioInvitesScreenViewState: BindableState {
    var isLoading = true
    var quota = 0
    var available = 0
    var invites: [ProseioInvite] = []
    /// Links for invites created on this device in this session. The server keeps only a hash of each code.
    var shareURLs: [String: URL] = [:]
    
    var bindings = ProseioInvitesScreenViewStateBindings()
    
    var canCreate: Bool {
        !isLoading && available > 0
    }
}

struct ProseioInvitesScreenViewStateBindings {
    var alertInfo: AlertInfo<ProseioInvitesScreenAlertType>?
}

enum ProseioInvitesScreenAlertType: Hashable {
    case error
}

enum ProseioInvitesScreenViewAction {
    case create
    case revoke(inviteID: String)
    case openUserProfile(userID: String)
}

extension ProseioInviteStatus {
    var title: String {
        switch self {
        case .pending: ProseioStrings.invitesStatusPending
        case .used: ProseioStrings.invitesStatusUsed
        case .expired: ProseioStrings.invitesStatusExpired
        case .revoked: ProseioStrings.invitesStatusRevoked
        }
    }
}
