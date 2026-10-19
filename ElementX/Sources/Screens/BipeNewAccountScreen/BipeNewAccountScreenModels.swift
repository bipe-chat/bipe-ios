//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// What the "Nova conta" window asks the app to start (bipe#445, #446).
enum BipeNewAccountChoice: Equatable {
    /// The sign-up, at the name step when `inviteCode` is set, else at the invite step.
    case signUp(BipeAccountType, inviteCode: BipeInviteCode?)
    /// The start screen of the add-account flow: sign-in, QR code and recovery.
    case signIn
}

enum BipeNewAccountScreenViewModelAction: Equatable {
    case choose(BipeNewAccountChoice)
    case dismiss
}

/// The invite that the account on screen gives the new account.
enum BipeNewAccountInvite: Equatable {
    /// The quota is loading, or it could not load. The sign-up shows its invite step if no invite is made.
    case unknown
    case available
    case noneLeft(nextAvailableAt: Date?)
    case created(BipeInviteCode)
}

struct BipeNewAccountScreenViewState: BindableState {
    /// The name of the account on screen. The invite comes from it.
    let accountName: String
    let canAddPersonal: Bool
    let maxPersonalAccounts: Int
    /// A company account needs an attested device (ADR 0043), and a company account makes no other company (ADR 0087).
    let showsCompany: Bool
    
    var invite = BipeNewAccountInvite.unknown
    /// The row whose tap is making the invite. The rows wait until it ends.
    var creatingInviteFor: BipeAccountType?
    
    var isPersonalEnabled: Bool {
        canAddPersonal && canSignUp
    }
    
    var isCompanyEnabled: Bool {
        canSignUp
    }
    
    var personalBody: String {
        canAddPersonal ? BipeStrings.accountNewPersonalBody : BipeStrings.accountCapReached(String(maxPersonalAccounts))
    }
    
    /// The text under the sign-up rows: who gives the invite, or why there is none.
    var inviteFooter: String? {
        switch invite {
        case .unknown: nil
        case .available, .created: BipeStrings.accountNewInviteNote(accountName)
        case .noneLeft(let nextAvailableAt): BipeInviteQuota.noneLeft(nextAvailableAt: nextAvailableAt)
        }
    }
    
    private var canSignUp: Bool {
        guard creatingInviteFor == nil else { return false }
        if case .noneLeft = invite {
            return false
        }
        return true
    }
}

enum BipeNewAccountScreenViewAction {
    case signUp(BipeAccountType)
    case signIn
    case cancel
}
