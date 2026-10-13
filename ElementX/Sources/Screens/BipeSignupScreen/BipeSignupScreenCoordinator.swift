//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import BipeKit
import SwiftUI

struct BipeSignupScreenCoordinatorParameters {
    /// From an invite link. Pre-fills the code field.
    var inviteCode: BipeInviteCode?
    let apiClient: BipeAPIClient
    let authenticationService: AuthenticationServiceProtocol
    /// The Bipe account provider. Login after sign-up goes there.
    let serverNameOrBaseURL: String
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeSignupScreenCoordinatorAction: CustomStringConvertible {
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case createdWithInvite(inviterUserID: String)
    
    var description: String {
        switch self {
        case .continueWithOAuth: "continueWithOAuth"
        case .createdWithInvite: "createdWithInvite"
        }
    }
}

final class BipeSignupScreenCoordinator: CoordinatorProtocol {
    private let parameters: BipeSignupScreenCoordinatorParameters
    private let viewModel: BipeSignupScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeSignupScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSignupScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeSignupScreenCoordinatorParameters) {
        self.parameters = parameters
        
        viewModel = BipeSignupScreenViewModel(inviteCode: parameters.inviteCode,
                                                 apiClient: parameters.apiClient,
                                                 authenticationService: parameters.authenticationService,
                                                 serverNameOrBaseURL: parameters.serverNameOrBaseURL,
                                                 userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            MXLog.info("Coordinator: received view model action: \(action)")
            
            guard let self else { return }
            switch action {
            case .continueWithOAuth(let data, let window):
                actionsSubject.send(.continueWithOAuth(data: data, window: window))
            case .createdWithInvite(let inviterUserID):
                actionsSubject.send(.createdWithInvite(inviterUserID: inviterUserID))
            }
        }
        .store(in: &cancellables)
    }
    
    func stop() {
        parameters.userIndicatorController.retractAllIndicators()
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeSignupScreen(context: viewModel.context))
    }
}
