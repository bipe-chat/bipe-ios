//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

enum BipeHandleScreenViewModelAction {
    case done
}

struct BipeHandleScreenViewState: BindableState {
    var isLoading = true
    var currentHandle: String?
    /// Set while the 30-day cooldown runs.
    var changeableAt: Date?
    var handleStatus = BipeHandleStatus.empty
    var handleError: String?
    
    var bindings = BipeHandleScreenViewStateBindings()
    
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
        let handle = BipeHandle.sanitize(bindings.handle)
        return !isLoading
            && !isInCooldown
            && !handle.isEmpty
            && handle != currentHandle
            && !handleStatus.isBlocking
    }
}

struct BipeHandleScreenViewStateBindings {
    var handle = ""
    var alertInfo: AlertInfo<BipeHandleScreenAlertType>?
}

enum BipeHandleScreenAlertType: Hashable {
    case error
}

enum BipeHandleScreenViewAction {
    case handleChanged
    case save
}
