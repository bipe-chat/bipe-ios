//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeSignupScreenCoordinatorParameters {
    /// From an invite link. Skips the code step.
    var inviteCode: BipeInviteCode?
    /// False when the start screen's button goes straight to the name (open sign-up, ADR 0072).
    var startsWithInviteCode = true
    let apiClient: BipeAPIClient
    let signIn: BipeAccountSignIn
    /// The new account's PIN also locks the app.
    let appLockService: AppLockServiceProtocol?
    let userIndicatorController: UserIndicatorControllerProtocol
    /// ADR 0087: "Criar conta da empresa" makes a company account.
    var accountType = BipeAccountType.personal
}

enum BipeSignupScreenCoordinatorAction: CustomStringConvertible {
    case signedIn(UserSessionProtocol)
    case createdWithInvite(inviterUserID: String, inviterHandle: String?)
    
    var description: String {
        switch self {
        case .signedIn: "signedIn"
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
                                              startsWithInviteCode: parameters.startsWithInviteCode,
                                              apiClient: parameters.apiClient,
                                              signIn: parameters.signIn,
                                              appLockService: parameters.appLockService,
                                              userIndicatorController: parameters.userIndicatorController,
                                              accountType: parameters.accountType)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            MXLog.info("Coordinator: received view model action: \(action)")
            
            guard let self else { return }
            switch action {
            case .signedIn(let userSession):
                actionsSubject.send(.signedIn(userSession))
            case .createdWithInvite(let inviterUserID, let inviterHandle):
                actionsSubject.send(.createdWithInvite(inviterUserID: inviterUserID, inviterHandle: inviterHandle))
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
