//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeTermsReacceptScreenCoordinatorParameters {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    /// The public site with the terms and privacy pages.
    let site: URL
}

enum BipeTermsReacceptScreenCoordinatorAction {
    case accepted
}

final class BipeTermsReacceptScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeTermsReacceptScreenViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeTermsReacceptScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeTermsReacceptScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeTermsReacceptScreenCoordinatorParameters) {
        viewModel = BipeTermsReacceptScreenViewModel(apiClient: parameters.apiClient,
                                                     clientProxy: parameters.clientProxy,
                                                     site: parameters.site)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .accepted:
                self?.actionsSubject.send(.accepted)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeTermsReacceptScreen(context: viewModel.context))
    }
}
