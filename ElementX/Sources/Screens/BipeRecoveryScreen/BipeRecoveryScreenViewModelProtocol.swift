//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeRecoveryScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeRecoveryScreenViewModelAction, Never> { get }
    var context: BipeRecoveryScreenViewModelType.Context { get }
}
