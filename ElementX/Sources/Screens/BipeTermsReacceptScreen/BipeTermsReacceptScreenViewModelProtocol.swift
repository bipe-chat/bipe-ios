//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeTermsReacceptScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeTermsReacceptScreenViewModelAction, Never> { get }
    var context: BipeTermsReacceptScreenViewModelType.Context { get }
}
