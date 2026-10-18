//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

enum BipeSignupScreenViewModelAction: CustomStringConvertible {
    /// The account exists and this device signed in with its hidden password.
    case signedIn(UserSessionProtocol)
    /// The account came from a personal invite. The app opens a chat with the inviter after the first sign-in (ADR 0034).
    case createdWithInvite(inviterUserID: String, inviterHandle: String?)
    
    var description: String {
        switch self {
        case .signedIn: "signedIn"
        case .createdWithInvite: "createdWithInvite"
        }
    }
}

struct BipeSignupScreenViewState: BindableState {
    /// The Termos de uso on the public site (ADR 0113).
    let termsURL: URL
    let privacyURL: URL
    /// ADR 0087: the name is the company's, and the account is a company account.
    var isCompany = false
    /// The screens in order come from bipe-shared `registries/onboarding.json` (bipe#415), the same as Android.
    /// The code step shows only when no invite came with a link.
    let firstStep: BipeOnboardingStep
    var step: BipeOnboardingStep
    /// The fallback step shows the email field.
    var isFallbackEmailOpen = false
    /// The API created the account. Submitting again only retries the sign-in.
    var isAccountCreated = false
    /// From `GET /v1/signup/config` (ADR 0072). `true` until the server says otherwise, and after an error.
    var isInviteRequired = true
    
    var emailError: String?
    var pinError: String?
    var inviteCodeError: String?
    /// The inviter's handle, from the invite preview.
    var inviterHandle: String?
    
    /// "Não tem convite?": the address was sent to the waitlist.
    var isWaitlistJoined = false
    var waitlistError: String?
    
    var bindings = BipeSignupScreenViewStateBindings()
    
    init(termsURL: URL, privacyURL: URL, firstStep: BipeOnboardingStep) {
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.firstStep = firstStep
        step = firstStep
    }
    
    /// The custom back button: one step back, never before the first step.
    var canGoBack: Bool {
        guard step != firstStep, let index = BipeOnboardingStep.allCases.firstIndex(of: step) else { return false }
        return index > 0
    }
    
    var trimmedEmail: String {
        bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// The PIN rule's message once all digits are typed.
    var pinProblem: BipePinProblem? {
        bindings.pin.count < BipeRegistries.pinLength ? nil : BipePIN.problem(for: bindings.pin)
    }
    
    /// Only a problem: the header already says what the PIN is for.
    var pinFooter: String? {
        pinError ?? pinProblem?.localizedMessage
    }
    
    var pinMismatch: Bool {
        bindings.pinConfirmation.count == BipeRegistries.pinLength && bindings.pin != bindings.pinConfirmation
    }
    
    /// The normalised code, or `nil` when the field is empty.
    var inviteCode: BipeInviteCode? {
        BipeInviteCode(bindings.inviteCode)
    }
    
    var isInviteCodeEmpty: Bool {
        bindings.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isInviteCodeAcceptable: Bool {
        (inviteCode != nil || (isInviteCodeEmpty && !isInviteRequired)) && inviteCodeError == nil
    }
    
    var inviteCodeFooter: String? {
        if let inviteCodeError {
            return inviteCodeError
        }
        if let inviterHandle {
            return BipeStrings.signupInvitedBy(inviterHandle)
        }
        return !isInviteCodeEmpty && inviteCode == nil ? BipeStrings.errorInviteInvalid : nil
    }
    
    var isInviteCodeFooterError: Bool {
        inviteCodeError != nil || (!isInviteCodeEmpty && inviteCode == nil)
    }
    
    var canContinueInviteCode: Bool {
        inviteCode != nil && inviteCodeError == nil
    }
    
    var canContinueName: Bool {
        let displayName = bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !displayName.isEmpty
            && displayName.count <= BipeSignupRules.displayNameMaxLength
            && bindings.isTermsAccepted
    }
    
    var isPINValid: Bool {
        BipePIN.problem(for: bindings.pin) == nil && bindings.pin == bindings.pinConfirmation
    }
    
    /// The fallback step's email: required once the field is open.
    var canSubmitFallbackEmail: Bool {
        !trimmedEmail.isEmpty && BipeSignupRules.isPlausibleEmail(trimmedEmail)
    }
    
    var canJoinWaitlist: Bool {
        let email = bindings.waitlistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return BipeSignupRules.isPlausibleEmail(email)
    }
    
    var canSubmit: Bool {
        isAccountCreated || (isInviteCodeAcceptable && canContinueName && isPINValid)
    }
}

struct BipeSignupScreenViewStateBindings {
    var displayName = ""
    var email = ""
    var pin = ""
    var pinConfirmation = ""
    var inviteCode = ""
    /// The clickwrap checkbox (ADR 0113). Starts unticked; sign-up needs it ticked.
    var isTermsAccepted = false
    
    var isWaitlistPresented = false
    var waitlistEmail = ""
    
    var alertInfo: AlertInfo<BipeSignupScreenAlertType>?
}

enum BipeSignupScreenAlertType: Hashable {
    case error
}

enum BipeSignupScreenViewAction {
    case inviteCodeChanged
    case clearFieldErrors
    /// The step's filled button: next step, or create the account.
    case primary
    /// A text button of the step, by its target in the registry.
    case text(BipeOnboardingTarget)
    /// Back one step.
    case back
    /// Waitlist sheet: send the address.
    case joinWaitlist
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
