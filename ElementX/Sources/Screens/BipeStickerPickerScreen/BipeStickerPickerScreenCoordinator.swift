//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct BipeStickerPickerScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let roomProxy: JoinedRoomProxyProtocol
    /// Set when the picker opens from a thread.
    let threadRootEventID: String?
    let mediaProvider: MediaProviderProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum BipeStickerPickerScreenCoordinatorAction {
    case dismiss
}

final class BipeStickerPickerScreenCoordinator: CoordinatorProtocol {
    private let viewModel: BipeStickerPickerScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<BipeStickerPickerScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeStickerPickerScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: BipeStickerPickerScreenCoordinatorParameters) {
        viewModel = BipeStickerPickerScreenViewModel(clientProxy: parameters.clientProxy,
                                                     roomProxy: parameters.roomProxy,
                                                     threadRootEventID: parameters.threadRootEventID,
                                                     mediaProvider: parameters.mediaProvider,
                                                     userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .dismiss:
                self?.actionsSubject.send(.dismiss)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeStickerPickerScreen(context: viewModel.context))
    }
}
