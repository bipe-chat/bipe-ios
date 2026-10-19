//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeNewAccountScreenCoordinatorParameters {
    let userSession: UserSessionProtocol
    /// Every account signed in on this phone, the one on screen included.
    let signedInUserIDs: [String]
}

enum BipeNewAccountScreenCoordinatorAction {
    case choose(BipeNewAccountChoice)
    case dismiss
}

final class BipeNewAccountScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeNewAccountScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeNewAccountScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeNewAccountScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeNewAccountScreenCoordinatorParameters) {
        let clientProxy = parameters.userSession.clientProxy
        let appSettings = parameters.userSession.userSettings.app
        let userID = clientProxy.userID
        let isBipeAccount = clientProxy.userIDServerName == appSettings.bipeSignupServerName
        let inviteCreator = isBipeAccount ? BipeInviteCreator(apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL),
                                                              userID: userID) { clientProxy.accessToken } : nil
        viewModel = BipeNewAccountScreenViewModel(accountName: BipeAccountLabels.label(for: userID),
                                                  canAddPersonal: BipeAccountCap.canAdd(signedInUserIDs: parameters.signedInUserIDs),
                                                  maxPersonalAccounts: BipeAccountCap.maxPersonalAccounts(),
                                                  showsCompany: BipeAppAttest.isSupported && !BipeAccountLabels.isCompany(userID),
                                                  inviteCreator: inviteCreator)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .choose(let choice):
                self?.actionsSubject.send(.choose(choice))
            case .dismiss:
                self?.actionsSubject.send(.dismiss)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeNewAccountScreen(context: viewModel.context))
    }
}
