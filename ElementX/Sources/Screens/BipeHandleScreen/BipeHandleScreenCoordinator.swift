//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeHandleScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    let handleResolver: BipeHandleResolver?
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeHandleScreenCoordinatorAction {
    case done
}

final class BipeHandleScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeHandleScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeHandleScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeHandleScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeHandleScreenCoordinatorParameters) {
        viewModel = BipeHandleScreenViewModel(apiClient: parameters.apiClient,
                                              clientProxy: parameters.clientProxy,
                                              handleResolver: parameters.handleResolver,
                                              userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .done:
                self?.actionsSubject.send(.done)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeHandleScreen(context: viewModel.context))
    }
}
