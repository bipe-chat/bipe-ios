//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeInvitesScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeInvitesScreenViewModelAction, Never> { get }
    var context: BipeInvitesScreenViewModelType.Context { get }
}
