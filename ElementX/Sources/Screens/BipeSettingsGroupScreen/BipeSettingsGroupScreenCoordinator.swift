//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

struct BipeSettingsGroupScreenCoordinatorParameters {
    let group: BipeSettingsGroup
    let userSession: UserSessionProtocol
    let appLockService: AppLockServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeSettingsGroupScreenCoordinatorAction {
    /// A row that opens another screen or flow.
    case open(BipeSettingsRow)
    /// "Bloquear o app" switched on: create the app lock PIN (ADR 0137).
    case turnOnAppLock
    /// "Bloquear o app" switched off on a phone with no passcode: Element's PIN check, then "Remove PIN".
    case turnOffAppLockWithPIN
}

/// Bipe: one settings group from the registry (ADR 0112): Seu perfil, Privacidade, Sua conta, Conversas e mídia, Ajuda e sobre.
final class BipeSettingsGroupScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeSettingsGroupScreenViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeSettingsGroupScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSettingsGroupScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeSettingsGroupScreenCoordinatorParameters) {
        viewModel = BipeSettingsGroupScreenViewModel(group: parameters.group,
                                                     userSession: parameters.userSession,
                                                     appLockService: parameters.appLockService,
                                                     userIndicatorController: parameters.userIndicatorController)
        
        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .open(let row):
                    self?.actionsSubject.send(.open(row))
                case .turnOnAppLock:
                    self?.actionsSubject.send(.turnOnAppLock)
                case .turnOffAppLockWithPIN:
                    self?.actionsSubject.send(.turnOffAppLockWithPIN)
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeSettingsGroupScreen(context: viewModel.context))
    }
}
