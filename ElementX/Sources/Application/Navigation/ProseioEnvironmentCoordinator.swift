//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

/// Proseio: wraps a session's root coordinator and puts the session's Proseio services
/// into the SwiftUI environment of every screen and sheet below it.
final class ProseioEnvironmentCoordinator: CoordinatorProtocol, CustomStringConvertible {
    private let coordinator: CoordinatorProtocol
    private let handleResolver: ProseioHandleResolver?
    
    var description: String {
        "ProseioEnvironmentCoordinator(\(coordinator))"
    }
    
    init(wrapping coordinator: CoordinatorProtocol, handleResolver: ProseioHandleResolver?) {
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
            .environment(\.proseioHandleResolver, handleResolver))
    }
}
