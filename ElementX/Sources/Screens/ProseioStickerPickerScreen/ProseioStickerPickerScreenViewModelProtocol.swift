//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioStickerPickerScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioStickerPickerScreenViewModelAction, Never> { get }
    var context: ProseioStickerPickerScreenViewModelType.Context { get }
}
