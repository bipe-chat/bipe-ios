//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

struct ProseioSignupScreenCoordinatorParameters {
    /// From an invite link. Pre-fills the code field.
    var inviteCode: ProseioInviteCode?
    let apiClient: ProseioAPIClient
    let authenticationService: AuthenticationServiceProtocol
    /// The Proseio account provider. Login after sign-up goes there.
    let serverNameOrBaseURL: String
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ProseioSignupScreenCoordinatorAction: CustomStringConvertible {
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    
    var description: String {
        switch self {
        case .continueWithOAuth: "continueWithOAuth"
        }
    }
}

final class ProseioSignupScreenCoordinator: CoordinatorProtocol {
    private let parameters: ProseioSignupScreenCoordinatorParameters
    private let viewModel: ProseioSignupScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ProseioSignupScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioSignupScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ProseioSignupScreenCoordinatorParameters) {
        self.parameters = parameters
        
        viewModel = ProseioSignupScreenViewModel(inviteCode: parameters.inviteCode,
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
            }
        }
        .store(in: &cancellables)
    }
    
    func stop() {
        parameters.userIndicatorController.retractAllIndicators()
    }
    
    func toPresentable() -> AnyView {
        AnyView(ProseioSignupScreen(context: viewModel.context))
    }
}
