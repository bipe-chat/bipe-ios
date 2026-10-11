//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

enum ProseioHandleScreenViewModelAction {
    case done
}

struct ProseioHandleScreenViewState: BindableState {
    var isLoading = true
    var currentHandle: String?
    /// Set while the 30-day cooldown runs.
    var changeableAt: Date?
    var handleStatus = ProseioHandleStatus.empty
    var handleError: String?
    
    var bindings = ProseioHandleScreenViewStateBindings()
    
    var isInCooldown: Bool {
        guard let changeableAt else { return false }
        return changeableAt > .now
    }
    
    var footer: String {
        if let handleError { return handleError }
        if isInCooldown, let changeableAt {
            return ProseioStrings.handleCooldownUntil(changeableAt.formatted(date: .long, time: .shortened))
        }
        return handleStatus.footer(defaultText: ProseioStrings.handleScreenFooter)
    }
    
    var fieldState: CompoundTextFieldStyle.State {
        handleError != nil ? .error : handleStatus.textFieldState
    }
    
    var canSave: Bool {
        let handle = ProseioHandle.sanitize(bindings.handle)
        return !isLoading
            && !isInCooldown
            && !handle.isEmpty
            && handle != currentHandle
            && !handleStatus.isBlocking
    }
}

struct ProseioHandleScreenViewStateBindings {
    var handle = ""
    var alertInfo: AlertInfo<ProseioHandleScreenAlertType>?
}

enum ProseioHandleScreenAlertType: Hashable {
    case error
}

enum ProseioHandleScreenViewAction {
    case handleChanged
    case save
}
