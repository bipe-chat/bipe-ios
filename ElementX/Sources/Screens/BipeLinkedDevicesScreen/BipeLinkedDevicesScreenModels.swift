//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipeLinkedDevicesScreenViewModelAction {
    /// The support check passed: open the scanner (desktop direction only, ADR 0116).
    case linkComputer
    case signOut(deviceID: String)
    case dismiss
}

struct BipeLinkedDevicesScreenViewState: BindableState {
    var isLoading = true
    var isCheckingSupport = false
    /// The other devices of the account, newest use first. This phone is not in it.
    var devices: [BipeMatrixDevice] = []
    let showsLinkComputer: Bool
    
    var bindings = BipeLinkedDevicesScreenViewStateBindings()
}

struct BipeLinkedDevicesScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeLinkedDevicesScreenAlertType>?
}

enum BipeLinkedDevicesScreenAlertType: Hashable {
    case error
    case notSupported
    case signOut(String)
}

enum BipeLinkedDevicesScreenViewAction {
    case linkComputer
    case signOut(BipeMatrixDevice)
    case dismiss
}
