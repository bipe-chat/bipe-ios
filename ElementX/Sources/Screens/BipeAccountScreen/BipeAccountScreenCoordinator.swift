//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeAccountScreenCoordinatorParameters {
    let mode: BipeAccountScreenMode
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    /// The account PIN also locks the app.
    let appLockService: AppLockServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeAccountScreenCoordinatorAction {
    case done
}

final class BipeAccountScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeAccountScreenViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeAccountScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeAccountScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeAccountScreenCoordinatorParameters) {
        viewModel = BipeAccountScreenViewModel(mode: parameters.mode,
                                               apiClient: parameters.apiClient,
                                               clientProxy: parameters.clientProxy,
                                               appLockService: parameters.appLockService,
                                               userIndicatorController: parameters.userIndicatorController)
        
        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done:
                    self?.actionsSubject.send(.done)
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeAccountScreen(context: viewModel.context))
    }
}
