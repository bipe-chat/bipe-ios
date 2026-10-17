//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// The ways back into a device-first account (ADR 0057, ADR 0059). Guardians and CPF are not built yet.
enum BipeRecoveryScreenMode: Equatable, CustomStringConvertible {
    /// Old phone (QR), recovery email, or a beta account's email sign-in.
    case choose
    /// A recovery token synced through iCloud Keychain. The PIN gets a new password at once.
    case token(userID: String)
    /// The link from the recovery email: the PIN (access), or a new PIN when the user forgot it.
    case emailLink(BipeRecoveryLinkToken)
    /// The safety wait after an email recovery. The app polls the claim.
    case waiting(BipeRecoveryStarted)
    
    var description: String {
        switch self {
        case .choose: "choose"
        case .token: "token"
        case .emailLink: "emailLink"
        case .waiting(let recovery): "waiting(\(recovery.purpose.rawValue))"
        }
    }
}

enum BipeRecoveryScreenViewModelAction: CustomStringConvertible {
    case signedIn(UserSessionProtocol)
    /// "I have my old phone": the QR sign-in. The old phone shows the code, this phone scans it (ADR 0059).
    case loginWithQR
    /// A beta account (email and own password) signs in through MAS.
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    
    var description: String {
        switch self {
        case .signedIn: "signedIn"
        case .loginWithQR: "loginWithQR"
        case .continueWithOAuth: "continueWithOAuth"
        }
    }
}

struct BipeRecoveryScreenViewState: BindableState {
    var mode: BipeRecoveryScreenMode
    var window: UIWindow?
    /// A synced token exists, so "choose" can go back to it.
    var hasRecoveryToken = false
    /// The user forgot the PIN: the email link sets a new one.
    var isNewPIN = false
    var isPINBlocked = false
    var emailSent = false
    var pinError: String?
    /// A one-line note at the top: cancelled, invalid link, PIN reset done.
    var notice: String?
    
    var bindings = BipeRecoveryScreenViewStateBindings()
    
    var title: String {
        switch mode {
        case .choose, .token: BipeStrings.recoveryTitle
        case .emailLink: isNewPIN ? BipeStrings.recoveryNewPinTitle : BipeStrings.pinEnterTitle
        case .waiting: BipeStrings.recoveryWaitingTitle
        }
    }
    
    var waitingBody: String? {
        guard case .waiting(let recovery) = mode else { return nil }
        let date = recovery.readyAt.formatted(date: .abbreviated, time: .shortened)
        return recovery.purpose == .pinReset ? BipeStrings.recoveryWaitingPinBody(date) : BipeStrings.recoveryWaitingBody(date)
    }
    
    var pinProblem: BipePinProblem? {
        guard isNewPIN, bindings.pin.count == BipeRegistries.pinLength else { return nil }
        return BipePIN.problem(for: bindings.pin)
    }
    
    var pinMismatch: Bool {
        isNewPIN && bindings.pinConfirmation.count == BipeRegistries.pinLength && bindings.pin != bindings.pinConfirmation
    }
    
    var canSubmitPIN: Bool {
        guard bindings.pin.count == BipeRegistries.pinLength, !isPINBlocked else { return false }
        return !isNewPIN || (pinProblem == nil && bindings.pin == bindings.pinConfirmation)
    }
    
    var canRequestEmail: Bool {
        BipeSignupRules.isPlausibleEmail(bindings.email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct BipeRecoveryScreenViewStateBindings {
    var pin = ""
    var pinConfirmation = ""
    var email = ""
    var alertInfo: AlertInfo<BipeRecoveryScreenAlertType>?
}

enum BipeRecoveryScreenAlertType: Hashable {
    case error
}

enum BipeRecoveryScreenViewAction {
    case updateWindow(UIWindow)
    case pinChanged
    case submitPIN
    case forgotPIN
    case requestEmail
    case loginWithQR
    case signInWithEmail
    case useRecoveryToken
    case refreshClaim
}
