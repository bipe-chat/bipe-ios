//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeAccountScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeAccountScreenViewModelAction, Never> { get }
    var context: BipeAccountScreenViewModelType.Context { get }
}
