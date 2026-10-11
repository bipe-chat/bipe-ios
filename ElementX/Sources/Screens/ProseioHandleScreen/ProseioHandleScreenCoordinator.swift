//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

struct ProseioHandleScreenCoordinatorParameters {
    let apiClient: ProseioAPIClient
    let clientProxy: ClientProxyProtocol
    let handleResolver: ProseioHandleResolver?
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ProseioHandleScreenCoordinatorAction {
    case done
}

final class ProseioHandleScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioHandleScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ProseioHandleScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioHandleScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ProseioHandleScreenCoordinatorParameters) {
        viewModel = ProseioHandleScreenViewModel(apiClient: parameters.apiClient,
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
        AnyView(ProseioHandleScreen(context: viewModel.context))
    }
}
