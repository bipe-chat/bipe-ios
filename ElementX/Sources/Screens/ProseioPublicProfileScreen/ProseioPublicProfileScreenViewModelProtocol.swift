//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol ProseioPublicProfileScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ProseioPublicProfileScreenViewModelAction, Never> { get }
    var context: ProseioPublicProfileScreenViewModelType.Context { get }

    /// Loads the profile again, e.g. after the user picked a handle.
    func reload()
}
