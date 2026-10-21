//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import SwiftUI

struct AuthenticationStartScreenParameters {
    let authenticationService: AuthenticationServiceProtocol
    let provisioningParameters: AccountProvisioningParameters?
    let isBugReportServiceEnabled: Bool
    let appMediator: AppMediatorProtocol
    let appSettings: AppSettings
    let mediaProvider: MediaProviderProtocol?
    let userIndicatorController: UserIndicatorControllerProtocol
    /// Bipe: the invite from a link, and the API that reads the sign-up mode (bipe#415).
    var bipePendingInviteCode: BipeInviteCode?
    var bipeAPIClient: BipeAPIClient?
}

enum AuthenticationStartScreenCoordinatorAction {
    case loginWithQR
    case login
    case register
    /// Bipe: the start screen's sign-up button. `startsWithInviteCode` is false when the code is known or not needed.
    case bipeSignup(startsWithInviteCode: Bool)
    /// Bipe: an invite code from the pasteboard (bipe#197).
    case bipeInvitePasted(BipeInviteCode)
    
    case loginDirectlyWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

final class AuthenticationStartScreenCoordinator: CoordinatorProtocol {
    private var viewModel: AuthenticationStartScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<AuthenticationStartScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<AuthenticationStartScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: AuthenticationStartScreenParameters) {
        viewModel = AuthenticationStartScreenViewModel(authenticationService: parameters.authenticationService,
                                                       provisioningParameters: parameters.provisioningParameters,
                                                       isBugReportServiceEnabled: parameters.isBugReportServiceEnabled,
                                                       appMediator: parameters.appMediator,
                                                       appSettings: parameters.appSettings,
                                                       mediaProvider: parameters.mediaProvider,
                                                       userIndicatorController: parameters.userIndicatorController,
                                                       bipePendingInviteCode: parameters.bipePendingInviteCode,
                                                       bipeAPIClient: parameters.bipeAPIClient)
    }
    
    // MARK: - Public
    
    func start() {
        viewModel.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .loginWithQR:
                    actionsSubject.send(.loginWithQR)
                case .login:
                    actionsSubject.send(.login)
                case .register:
                    actionsSubject.send(.register)
                case .bipeSignup(let startsWithInviteCode):
                    actionsSubject.send(.bipeSignup(startsWithInviteCode: startsWithInviteCode))
                case .bipeInvitePasted(let code):
                    actionsSubject.send(.bipeInvitePasted(code))
                    
                case .loginDirectlyWithOAuth(let data, let window):
                    actionsSubject.send(.loginDirectlyWithOAuth(data: data, window: window))
                case .loginDirectlyWithPassword(let loginHint):
                    actionsSubject.send(.loginDirectlyWithPassword(loginHint: loginHint))
                    
                case .reportProblem:
                    actionsSubject.send(.reportProblem)
                case .developerOptions:
                    actionsSubject.send(.developerOptions)
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(AuthenticationStartScreen(context: viewModel.context))
    }
}
