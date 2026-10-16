//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

struct BipeMessagingScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
}

final class BipeMessagingScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeMessagingScreenViewModelProtocol
    
    init(parameters: BipeMessagingScreenCoordinatorParameters) {
        viewModel = BipeMessagingScreenViewModel(apiClient: parameters.apiClient,
                                                 clientProxy: parameters.clientProxy)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeMessagingScreen(context: viewModel.context))
    }
}
