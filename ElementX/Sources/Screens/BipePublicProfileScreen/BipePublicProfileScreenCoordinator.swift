//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipePublicProfileScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let userSession: UserSessionProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipePublicProfileScreenCoordinatorAction {
    case openHandle
}

final class BipePublicProfileScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipePublicProfileScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipePublicProfileScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipePublicProfileScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipePublicProfileScreenCoordinatorParameters) {
        viewModel = BipePublicProfileScreenViewModel(apiClient: parameters.apiClient,
                                                     userSession: parameters.userSession,
                                                     userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .openHandle:
                self?.actionsSubject.send(.openHandle)
            }
        }
        .store(in: &cancellables)
    }
    
    func reload() {
        viewModel.reload()
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipePublicProfileScreen(context: viewModel.context))
    }
}
