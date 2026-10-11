//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

struct ProseioInvitesScreenCoordinatorParameters {
    let apiClient: ProseioAPIClient
    let clientProxy: ClientProxyProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ProseioInvitesScreenCoordinatorAction {
    case openUserProfile(userID: String)
}

final class ProseioInvitesScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioInvitesScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ProseioInvitesScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioInvitesScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ProseioInvitesScreenCoordinatorParameters) {
        viewModel = ProseioInvitesScreenViewModel(apiClient: parameters.apiClient,
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
        AnyView(ProseioInvitesScreen(context: viewModel.context))
    }
}
