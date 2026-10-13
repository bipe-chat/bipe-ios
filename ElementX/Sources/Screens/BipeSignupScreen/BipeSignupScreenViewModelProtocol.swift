//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeSignupScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeSignupScreenViewModelAction, Never> { get }
    var context: BipeSignupScreenViewModelType.Context { get }
}
