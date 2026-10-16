//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Bipe: Sua conta opens this screen for one thing (ADR 0112).
enum BipeAccountScreenMode {
    /// The senha: the device owner check runs first, then the form.
    case pin
    /// The recovery email.
    case email
}

enum BipeAccountScreenViewModelAction {
    /// The senha is saved: back to Sua conta.
    case done
}

struct BipeAccountScreenViewState: BindableState {
    let mode: BipeAccountScreenMode
    var status: BipeAccountStatus?
    var isLoading = true
    /// The PIN form is open: a change, or the first PIN of a beta account.
    var isEditingPIN = false
    var emailSentTo: String?

    var bindings = BipeAccountScreenViewStateBindings()
    
    var title: String {
        switch mode {
        case .pin: isBetaAccount ? BipeStrings.pinCreateTitle : BipeStrings.pinChangeTitle
        case .email: BipeStrings.emailTitle
        }
    }

    /// A beta account still signs in with its own password. Its first PIN moves it to a hidden password.
    var isBetaAccount: Bool {
        status.map { !$0.deviceFirst } ?? false
    }

    var pinProblem: BipePinProblem? {
        bindings.pin.count == BipeRegistries.pinLength ? BipePIN.problem(for: bindings.pin) : nil
    }

    var pinMismatch: Bool {
        bindings.pinConfirmation.count == BipeRegistries.pinLength && bindings.pin != bindings.pinConfirmation
    }

    var canSavePIN: Bool {
        BipePIN.problem(for: bindings.pin) == nil && bindings.pin == bindings.pinConfirmation
    }

    var canSaveEmail: Bool {
        BipeSignupRules.isPlausibleEmail(bindings.email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct BipeAccountScreenViewStateBindings {
    var pin = ""
    var pinConfirmation = ""
    var email = ""
    var alertInfo: AlertInfo<BipeAccountScreenAlertType>?
}

enum BipeAccountScreenAlertType: Hashable {
    case error
    case removeEmail
}

enum BipeAccountScreenViewAction {
    case editPIN
    case pinChanged
    case savePIN
    case cancelPIN
    case saveEmail
    case removeEmail
}
