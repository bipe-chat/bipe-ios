//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeContactsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeContactsScreenViewModelAction, Never> { get }
    var context: BipeContactsScreenViewModelType.Context { get }
}
