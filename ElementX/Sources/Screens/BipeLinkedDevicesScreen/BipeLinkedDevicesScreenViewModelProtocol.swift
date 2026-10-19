//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeLinkedDevicesScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeLinkedDevicesScreenViewModelAction, Never> { get }
    var context: BipeLinkedDevicesScreenViewModelType.Context { get }
    
    func reload() async
}
