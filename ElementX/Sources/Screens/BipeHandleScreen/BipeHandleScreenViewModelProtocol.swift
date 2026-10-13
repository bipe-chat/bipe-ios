//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeHandleScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeHandleScreenViewModelAction, Never> { get }
    var context: BipeHandleScreenViewModelType.Context { get }
}
