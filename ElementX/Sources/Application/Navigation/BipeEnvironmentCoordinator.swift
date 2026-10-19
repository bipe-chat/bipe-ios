//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Bipe: wraps a session's root coordinator and puts the session's Bipe services
/// into the SwiftUI environment of every screen and sheet below it.
final class BipeEnvironmentCoordinator: CoordinatorProtocol, CustomStringConvertible {
    private let coordinator: CoordinatorProtocol
    private let handleResolver: BipeHandleResolver?
    private let companySeals: BipeCompanySeals?
    
    /// The coordinator this one wraps, for example the home tabs.
    var wrappedCoordinator: CoordinatorProtocol {
        coordinator
    }
    
    var description: String {
        "BipeEnvironmentCoordinator(\(coordinator))"
    }
    
    init(wrapping coordinator: CoordinatorProtocol, handleResolver: BipeHandleResolver?, companySeals: BipeCompanySeals? = nil) {
        self.coordinator = coordinator
        self.handleResolver = handleResolver
        self.companySeals = companySeals
    }
    
    func start() {
        coordinator.start()
    }
    
    func stop() {
        coordinator.stop()
    }
    
    func toPresentable() -> AnyView {
        AnyView(coordinator.toPresentable()
            .environment(\.bipeHandleResolver, handleResolver)
            .environment(\.bipeCompanySeals, companySeals))
    }
}
