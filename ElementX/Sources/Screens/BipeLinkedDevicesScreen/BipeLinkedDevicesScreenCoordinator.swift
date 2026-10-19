//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct BipeLinkedDevicesScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let showsLinkComputer: Bool
}

final class BipeLinkedDevicesScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeLinkedDevicesScreenViewModelProtocol
    
    var actionsPublisher: AnyPublisher<BipeLinkedDevicesScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }
    
    init(parameters: BipeLinkedDevicesScreenCoordinatorParameters) {
        viewModel = BipeLinkedDevicesScreenViewModel(clientProxy: parameters.clientProxy,
                                                     showsLinkComputer: parameters.showsLinkComputer)
    }
    
    func reload() {
        Task { await viewModel.reload() }
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeLinkedDevicesScreen(context: viewModel.context))
    }
}
