//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

struct BipeAccountScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    /// The account PIN also locks the app.
    let appLockService: AppLockServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

final class BipeAccountScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeAccountScreenViewModelProtocol
    
    init(parameters: BipeAccountScreenCoordinatorParameters) {
        viewModel = BipeAccountScreenViewModel(apiClient: parameters.apiClient,
                                               clientProxy: parameters.clientProxy,
                                               appLockService: parameters.appLockService,
                                               userIndicatorController: parameters.userIndicatorController)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeAccountScreen(context: viewModel.context))
    }
}
