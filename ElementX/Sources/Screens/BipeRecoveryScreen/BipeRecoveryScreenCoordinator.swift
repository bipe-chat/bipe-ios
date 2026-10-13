//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeRecoveryScreenCoordinatorParameters {
    let mode: BipeRecoveryScreenMode
    let apiClient: BipeAPIClient
    let signIn: BipeAccountSignIn
    /// The Bipe account provider, for a beta account's MAS sign-in.
    let serverNameOrBaseURL: String
    /// The account PIN also locks the app.
    let appLockService: AppLockServiceProtocol?
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeRecoveryScreenCoordinatorAction: CustomStringConvertible {
    case signedIn(UserSessionProtocol)
    case loginWithQR
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    
    var description: String {
        switch self {
        case .signedIn: "signedIn"
        case .loginWithQR: "loginWithQR"
        case .continueWithOAuth: "continueWithOAuth"
        }
    }
}

final class BipeRecoveryScreenCoordinator: CoordinatorProtocol {
    private let parameters: BipeRecoveryScreenCoordinatorParameters
    private let viewModel: BipeRecoveryScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeRecoveryScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeRecoveryScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeRecoveryScreenCoordinatorParameters) {
        self.parameters = parameters
        viewModel = BipeRecoveryScreenViewModel(mode: parameters.mode,
                                                apiClient: parameters.apiClient,
                                                signIn: parameters.signIn,
                                                serverNameOrBaseURL: parameters.serverNameOrBaseURL,
                                                appLockService: parameters.appLockService,
                                                userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            MXLog.info("Coordinator: received view model action: \(action)")
            
            guard let self else { return }
            switch action {
            case .signedIn(let userSession):
                actionsSubject.send(.signedIn(userSession))
            case .loginWithQR:
                actionsSubject.send(.loginWithQR)
            case .continueWithOAuth(let data, let window):
                actionsSubject.send(.continueWithOAuth(data: data, window: window))
            }
        }
        .store(in: &cancellables)
    }
    
    func stop() {
        parameters.userIndicatorController.retractAllIndicators()
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeRecoveryScreen(context: viewModel.context))
    }
}
