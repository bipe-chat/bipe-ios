//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

struct ProseioMessagingScreenViewState: BindableState {
    var isLoading = true
    var isSaving = false
    var selection: ProseioWhoCanMessage?
    
    var bindings = ProseioMessagingScreenViewStateBindings()
    
    var isDisabled: Bool { isLoading || isSaving }
}

struct ProseioMessagingScreenViewStateBindings {
    var alertInfo: AlertInfo<ProseioMessagingScreenAlertType>?
}

enum ProseioMessagingScreenAlertType: Hashable {
    case error
}

enum ProseioMessagingScreenViewAction {
    case select(ProseioWhoCanMessage)
}
