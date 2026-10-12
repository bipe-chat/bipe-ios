//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct ProseioStickerPickerScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let roomProxy: JoinedRoomProxyProtocol
    /// Set when the picker opens from a thread.
    let threadRootEventID: String?
    let mediaProvider: MediaProviderProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ProseioStickerPickerScreenCoordinatorAction {
    case dismiss
}

final class ProseioStickerPickerScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ProseioStickerPickerScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ProseioStickerPickerScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioStickerPickerScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ProseioStickerPickerScreenCoordinatorParameters) {
        viewModel = ProseioStickerPickerScreenViewModel(clientProxy: parameters.clientProxy,
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
        AnyView(ProseioStickerPickerScreen(context: viewModel.context))
    }
}
