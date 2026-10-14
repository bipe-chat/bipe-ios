//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

enum BipeSignupScreenViewModelAction: CustomStringConvertible {
    /// The account exists and this device signed in with its hidden password.
    case signedIn(UserSessionProtocol)
    /// The account came from a personal invite. The app opens the inviter's profile after the first sign-in.
    case createdWithInvite(inviterUserID: String)

    var description: String {
        switch self {
        case .signedIn: "signedIn"
        case .createdWithInvite: "createdWithInvite"
        }
    }
}

struct BipeSignupScreenViewState: BindableState {
    var handleStatus = BipeHandleStatus.empty
    /// The API created the account. Submitting again only retries the sign-in.
    var isAccountCreated = false
    /// From `GET /v1/signup/config` (ADR 0072). `true` until the server says otherwise, and after an error.
    var isInviteRequired = true

    var emailError: String?
    var pinError: String?
    var handleError: String?
    var inviteCodeError: String?
    /// The inviter's handle, from the invite preview.
    var inviterHandle: String?

    var bindings = BipeSignupScreenViewStateBindings()

    var trimmedEmail: String {
        bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The PIN rule's message once all digits are typed.
    var pinProblem: BipePinProblem? {
        bindings.pin.count < BipeRegistries.pinLength ? nil : BipePIN.problem(for: bindings.pin)
    }

    var pinFooter: String {
        pinError ?? pinProblem?.localizedMessage ?? BipeStrings.pinCreateBody(String(BipeRegistries.pinLength))
    }

    var pinMismatch: Bool {
        bindings.pinConfirmation.count == BipeRegistries.pinLength && bindings.pin != bindings.pinConfirmation
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

    var isInviteCodeEmpty: Bool {
        bindings.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isInviteCodeAcceptable: Bool {
        inviteCode != nil || (isInviteCodeEmpty && !isInviteRequired)
    }

    var inviteCodeLabel: String {
        isInviteRequired ? BipeStrings.signupInviteCode : BipeStrings.signupInviteCodeOptional
    }

    /// Never "opcional" when the server requires an invite (ADR 0072): an empty field says why a code is needed.
    var inviteCodeFooter: String? {
        if let inviteCodeError { return inviteCodeError }
        if isInviteCodeEmpty { return isInviteRequired ? BipeStrings.signupInviteRequired : nil }
        return inviteCode == nil ? BipeStrings.errorInviteInvalid : nil
    }

    var isInviteCodeFooterError: Bool {
        inviteCodeError != nil || (!isInviteCodeEmpty && inviteCode == nil)
    }

    var canSubmit: Bool {
        if isAccountCreated { return true }
        let displayName = bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !displayName.isEmpty
            && displayName.count <= BipeSignupRules.displayNameMaxLength
            && (trimmedEmail.isEmpty || BipeSignupRules.isPlausibleEmail(trimmedEmail))
            && BipePIN.problem(for: bindings.pin) == nil
            && bindings.pin == bindings.pinConfirmation
            && !handleStatus.isBlocking
            && isInviteCodeAcceptable
            && inviteCodeError == nil
    }
}

struct BipeSignupScreenViewStateBindings {
    var displayName = ""
    var handle = ""
    var email = ""
    var pin = ""
    var pinConfirmation = ""
    var inviteCode = ""

    var alertInfo: AlertInfo<BipeSignupScreenAlertType>?
}

enum BipeSignupScreenAlertType: Hashable {
    case error
}

enum BipeSignupScreenViewAction {
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
