//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol BipeSettingsGroupScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<BipeSettingsGroupScreenViewModelAction, Never> { get }
    var context: BipeSettingsGroupScreenViewModelType.Context { get }
}
