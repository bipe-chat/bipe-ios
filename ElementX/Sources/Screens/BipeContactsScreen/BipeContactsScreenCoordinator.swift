//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import BipeKit
import SwiftUI

struct BipeContactsScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeContactsScreenCoordinatorAction {
    case openUserProfile(userID: String)
    case openInvites
}

final class BipeContactsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeContactsScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeContactsScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeContactsScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeContactsScreenCoordinatorParameters) {
        viewModel = BipeContactsScreenViewModel(apiClient: parameters.apiClient,
                                                clientProxy: parameters.clientProxy,
                                                userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .openUserProfile(let userID):
                self?.actionsSubject.send(.openUserProfile(userID: userID))
            case .openInvites:
                self?.actionsSubject.send(.openInvites)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeContactsScreen(context: viewModel.context))
    }
}
