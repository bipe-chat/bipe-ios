//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioHandleScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioHandleScreenViewModelAction, Never> { get }
    var context: ProseioHandleScreenViewModelType.Context { get }
}
