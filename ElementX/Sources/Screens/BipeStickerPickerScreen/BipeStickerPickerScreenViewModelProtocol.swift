//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeStickerPickerScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeStickerPickerScreenViewModelAction, Never> { get }
    var context: BipeStickerPickerScreenViewModelType.Context { get }
}
