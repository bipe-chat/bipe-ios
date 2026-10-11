//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioSignupScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioSignupScreenViewModelAction, Never> { get }
    var context: ProseioSignupScreenViewModelType.Context { get }
}
