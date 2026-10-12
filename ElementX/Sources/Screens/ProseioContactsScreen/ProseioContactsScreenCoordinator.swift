//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

struct ProseioContactsScreenCoordinatorParameters {
    let apiClient: ProseioAPIClient
    let clientProxy: ClientProxyProtocol
}

enum ProseioContactsScreenCoordinatorAction {
    case openUserProfile(userID: String)
    case openInvites
}

final class ProseioContactsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioContactsScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ProseioContactsScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioContactsScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ProseioContactsScreenCoordinatorParameters) {
        viewModel = ProseioContactsScreenViewModel(apiClient: parameters.apiClient, clientProxy: parameters.clientProxy)
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
        AnyView(ProseioContactsScreen(context: viewModel.context))
    }
}
