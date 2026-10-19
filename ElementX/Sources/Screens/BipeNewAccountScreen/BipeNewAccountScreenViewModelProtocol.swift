//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeNewAccountScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeNewAccountScreenViewModelAction, Never> { get }
    var context: BipeNewAccountScreenViewModelType.Context { get }
}
