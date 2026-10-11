//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

enum ProseioSignupScreenViewModelAction: CustomStringConvertible {
    /// The account exists. Continue with MAS login, pre-filled with the email.
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)

    var description: String {
        switch self {
        case .continueWithOAuth: "continueWithOAuth"
        }
    }
}

struct ProseioSignupScreenViewState: BindableState {
    var window: UIWindow?
    var handleStatus = ProseioHandleStatus.empty
    /// The API created the account. Submitting again only restarts the login.
    var isAccountCreated = false

    var emailError: String?
    var passwordError: String?
    var handleError: String?

    var bindings = ProseioSignupScreenViewStateBindings()

    var passwordMismatch: Bool {
        !bindings.passwordConfirmation.isEmpty && bindings.password != bindings.passwordConfirmation
    }

    var handleFooter: String {
        handleError ?? handleStatus.footer(defaultText: ProseioStrings.signupHandleFooter)
    }

    var handleFieldState: CompoundTextFieldStyle.State {
        handleError != nil ? .error : handleStatus.textFieldState
    }

    var canSubmit: Bool {
        if isAccountCreated { return true }
        let displayName = bindings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !displayName.isEmpty
            && displayName.count <= ProseioSignupRules.displayNameMaxLength
            && ProseioSignupRules.isPlausibleEmail(bindings.email.trimmingCharacters(in: .whitespacesAndNewlines))
            && ProseioSignupRules.isValidPassword(bindings.password)
            && bindings.password == bindings.passwordConfirmation
            && !handleStatus.isBlocking
    }
}

struct ProseioSignupScreenViewStateBindings {
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var handle = ""
    var displayName = ""

    var alertInfo: AlertInfo<ProseioSignupScreenAlertType>?
}

enum ProseioSignupScreenAlertType: Hashable {
    case error
}

enum ProseioSignupScreenViewAction {
    case updateWindow(UIWindow)
    case handleChanged
    case clearFieldErrors
    case submit
}

extension ProseioHandleStatus {
    /// Shared by the sign-up and username settings screens.
    var textFieldState: CompoundTextFieldStyle.State {
        switch self {
        case .available: .success
        case .problem: .error
        case .empty, .checking, .unknown: .default
        }
    }
}
