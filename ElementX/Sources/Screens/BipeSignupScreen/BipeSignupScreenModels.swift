//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

enum BipeSignupScreenViewModelAction: CustomStringConvertible {
    /// The account exists. Continue with MAS login, pre-filled with the email.
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    /// The account came from a personal invite. The app opens the inviter's profile after the first sign-in.
    case createdWithInvite(inviterUserID: String)

    var description: String {
        switch self {
        case .continueWithOAuth: "continueWithOAuth"
        case .createdWithInvite: "createdWithInvite"
        }
    }
}

struct BipeSignupScreenViewState: BindableState {
    var window: UIWindow?
    var handleStatus = BipeHandleStatus.empty
    /// The API created the account. Submitting again only restarts the login.
    var isAccountCreated = false

    var emailError: String?
    var passwordError: String?
    var handleError: String?
    var inviteCodeError: String?
    /// The inviter's handle, from the invite preview.
    var inviterHandle: String?

    var bindings = BipeSignupScreenViewStateBindings()

    var passwordMismatch: Bool {
        !bindings.passwordConfirmation.isEmpty && bindings.password != bindings.passwordConfirmation
    }

    var handleFooter: String {
        handleError ?? handleStatus.footer(defaultText: BipeStrings.signupHandleFooter)
    }

    var handleFieldState: CompoundTextFieldStyle.State {
        handleError != nil ? .error : handleStatus.textFieldState
    }

    /// The normalised code, or `nil` when the field is empty.
    var inviteCode: BipeInviteCode? {
        BipeInviteCode(bindings.inviteCode)
    }

    var isInviteCodeAcceptable: Bool {
        bindings.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inviteCode != nil
    }

    var inviteCodeFooter: String? {
        inviteCodeError ?? (isInviteCodeAcceptable ? nil : BipeStrings.errorInviteInvalid)
    }

    var canSubmit: Bool {
        if isAccountCreated { return true }
        let displayName = bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !displayName.isEmpty
            && displayName.count <= BipeSignupRules.displayNameMaxLength
            && BipeSignupRules.isPlausibleEmail(bindings.email.trimmingCharacters(in: .whitespacesAndNewlines))
            && BipeSignupRules.isValidPassword(bindings.password)
            && bindings.password == bindings.passwordConfirmation
            && !handleStatus.isBlocking
            && isInviteCodeAcceptable
            && inviteCodeError == nil
    }
}

struct BipeSignupScreenViewStateBindings {
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var handle = ""
    var displayName = ""
    var inviteCode = ""

    var alertInfo: AlertInfo<BipeSignupScreenAlertType>?
}

enum BipeSignupScreenAlertType: Hashable {
    case error
}

enum BipeSignupScreenViewAction {
    case updateWindow(UIWindow)
    case handleChanged
    case inviteCodeChanged
    case clearFieldErrors
    case submit
}

extension BipeHandleStatus {
    /// Shared by the sign-up and username settings screens.
    var textFieldState: CompoundTextFieldStyle.State {
        switch self {
        case .available: .success
        case .problem: .error
        case .empty, .checking, .unknown: .default
        }
    }
}
