//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

struct ProseioPublicProfileScreenCoordinatorParameters {
    let apiClient: ProseioAPIClient
    let userSession: UserSessionProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ProseioPublicProfileScreenCoordinatorAction {
    case openHandle
}

final class ProseioPublicProfileScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioPublicProfileScreenViewModelProtocol

    private var cancellables = Set<AnyCancellable>()

    private let actionsSubject: PassthroughSubject<ProseioPublicProfileScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioPublicProfileScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: ProseioPublicProfileScreenCoordinatorParameters) {
        viewModel = ProseioPublicProfileScreenViewModel(apiClient: parameters.apiClient,
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
        AnyView(ProseioPublicProfileScreen(context: viewModel.context))
    }
}
