//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeInvitesScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeInvitesScreenCoordinatorAction {
    case openUserProfile(userID: String)
}

final class BipeInvitesScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeInvitesScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeInvitesScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeInvitesScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeInvitesScreenCoordinatorParameters) {
        viewModel = BipeInvitesScreenViewModel(apiClient: parameters.apiClient,
                                               clientProxy: parameters.clientProxy,
                                               userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .openUserProfile(let userID):
                self?.actionsSubject.send(.openUserProfile(userID: userID))
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeInvitesScreen(context: viewModel.context))
    }
}
