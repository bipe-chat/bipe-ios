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
    
    var description: String {
        "BipeEnvironmentCoordinator(\(coordinator))"
    }
    
    init(wrapping coordinator: CoordinatorProtocol, handleResolver: BipeHandleResolver?) {
        self.coordinator = coordinator
        self.handleResolver = handleResolver
    }
    
    func start() {
        coordinator.start()
    }
    
    func stop() {
        coordinator.stop()
    }
    
    func toPresentable() -> AnyView {
        AnyView(coordinator.toPresentable()
            .environment(\.bipeHandleResolver, handleResolver))
    }
}
