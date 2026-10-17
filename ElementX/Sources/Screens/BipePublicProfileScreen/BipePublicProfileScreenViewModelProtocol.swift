//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipePublicProfileScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipePublicProfileScreenViewModelAction, Never> { get }
    var context: BipePublicProfileScreenViewModelType.Context { get }
    
    /// Loads the profile again, e.g. after the user picked a handle.
    func reload()
}
