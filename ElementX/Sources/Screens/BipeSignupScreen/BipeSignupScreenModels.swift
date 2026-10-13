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

/// One question per screen (bipe#196): the invite when there is none yet (ADR 0072), the name, the PIN, the PIN again.
enum BipeSignupStep: Int, Comparable {
    case invite
    case name
    case pin
    case pinConfirmation

    static func < (lhs: BipeSignupStep, rhs: BipeSignupStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct BipeSignupScreenViewState: BindableState {
    var step: BipeSignupStep
    /// `.invite` without a code from a link, else `.name`. A rejected code moves it back to `.invite`.
    var firstStep: BipeSignupStep
    /// The API created the account. Submitting again only retries the sign-in.
    var isAccountCreated = false

    var pinError: String?
    /// The second PIN did not match the first. Cleared when the user types again.
    var pinMismatch = false
    var inviteCodeError: String?
    /// The inviter's handle, from the invite preview.
    var inviterHandle: String?
    /// "Não tenho convite" was tapped.
    var showsNoInviteHelp = false

    var bindings = BipeSignupScreenViewStateBindings()

    init(inviteCode: BipeInviteCode?) {
        firstStep = inviteCode == nil ? .invite : .name
        step = firstStep
        bindings.inviteCode = inviteCode?.value ?? ""
    }

    /// The step the back button opens, or `nil` on the first step (the system back button pops the screen).
    var previousStep: BipeSignupStep? {
        guard step > firstStep, !isAccountCreated else { return nil }
        return BipeSignupStep(rawValue: step.rawValue - 1)
    }

    var trimmedDisplayName: String {
        bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinueFromName: Bool {
        !trimmedDisplayName.isEmpty && trimmedDisplayName.count <= BipeSignupRules.displayNameMaxLength
    }

    /// The PIN rule's message once all digits are typed.
    var pinProblem: BipePinProblem? {
        bindings.pin.count < BipeRegistries.pinLength ? nil : BipePIN.problem(for: bindings.pin)
    }

    var pinFooter: String? {
        pinError ?? pinProblem?.localizedMessage
    }

    /// The normalised code, or `nil` when the field is empty or not a code.
    var inviteCode: BipeInviteCode? {
        BipeInviteCode(bindings.inviteCode)
    }

    var inviteCodeFooter: String? {
        if let inviteCodeError { return inviteCodeError }
        let isEmpty = bindings.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEmpty || inviteCode != nil ? nil : BipeStrings.errorInviteInvalid
    }

    var canContinueFromInvite: Bool {
        inviteCode != nil && inviteCodeError == nil
    }

    var canSubmit: Bool {
        if isAccountCreated { return true }
        return canContinueFromName
            && BipePIN.problem(for: bindings.pin) == nil
            && bindings.pin == bindings.pinConfirmation
            && canContinueFromInvite
    }
}

struct BipeSignupScreenViewStateBindings {
    var displayName = ""
    var pin = ""
    var pinConfirmation = ""
    var inviteCode = ""

    var alertInfo: AlertInfo<BipeSignupScreenAlertType>?
}

enum BipeSignupScreenAlertType: Hashable {
    case error
}

enum BipeSignupScreenViewAction {
    case inviteCodeChanged
    case continueFromInvite
    case showNoInviteHelp
    case continueFromName
    case pinChanged
    case pinConfirmationChanged
    case back
    /// Retries the sign-in after the account was created.
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
