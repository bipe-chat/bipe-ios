//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioInvitesScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioInvitesScreenViewModelAction, Never> { get }
    var context: ProseioInvitesScreenViewModelType.Context { get }
}
