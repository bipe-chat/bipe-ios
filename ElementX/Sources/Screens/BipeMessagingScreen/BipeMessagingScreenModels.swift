//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

struct BipeMessagingScreenViewState: BindableState {
    var isLoading = true
    var isSaving = false
    var selection: BipeWhoCanMessage?
    
    var bindings = BipeMessagingScreenViewStateBindings()
    
    var isDisabled: Bool {
        isLoading || isSaving
    }
}

struct BipeMessagingScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeMessagingScreenAlertType>?
}

enum BipeMessagingScreenAlertType: Hashable {
    case error
}

enum BipeMessagingScreenViewAction {
    case select(BipeWhoCanMessage)
}
