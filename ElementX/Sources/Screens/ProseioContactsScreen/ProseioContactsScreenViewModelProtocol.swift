//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioContactsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioContactsScreenViewModelAction, Never> { get }
    var context: ProseioContactsScreenViewModelType.Context { get }
}
