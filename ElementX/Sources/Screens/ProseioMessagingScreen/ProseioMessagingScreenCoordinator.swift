//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

struct ProseioMessagingScreenCoordinatorParameters {
    let apiClient: ProseioAPIClient
    let clientProxy: ClientProxyProtocol
}

final class ProseioMessagingScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioMessagingScreenViewModelProtocol
    
    init(parameters: ProseioMessagingScreenCoordinatorParameters) {
        viewModel = ProseioMessagingScreenViewModel(apiClient: parameters.apiClient,
                                                    clientProxy: parameters.clientProxy)
    }
    
    func toPresentable() -> AnyView {
        AnyView(ProseioMessagingScreen(context: viewModel.context))
    }
}
