//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

enum BipeTermsReacceptScreenViewModelAction {
    /// The server recorded the current terms version.
    case accepted
}

struct BipeTermsReacceptScreenViewState: BindableState {
    let termsURL: URL
    let privacyURL: URL
    var isSaving = false
    /// The last `POST /v1/me/terms` failed.
    var isFailed = false

    var bindings = BipeTermsReacceptScreenViewStateBindings()

    var canContinue: Bool {
        bindings.isTermsAccepted && !isSaving
    }
}

struct BipeTermsReacceptScreenViewStateBindings {
    /// Starts unticked, as at sign-up (ADR 0113).
    var isTermsAccepted = false
}

enum BipeTermsReacceptScreenViewAction {
    case `continue`
}
