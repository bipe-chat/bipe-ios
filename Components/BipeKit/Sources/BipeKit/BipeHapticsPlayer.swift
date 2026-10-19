//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

#if canImport(UIKit)
import SwiftUI

/// Plays the Bipe haptics language (ADR 0134, bipe/docs/design/haptics.md). The only place that touches UIKit feedback generators.
@MainActor
public enum BipeHaptics {
    private static var selection: UISelectionFeedbackGenerator?
    private static var impacts: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private static var notification: UINotificationFeedbackGenerator?
    
    public static func play(_ haptic: BipeHaptic) {
        switch haptic.primitive {
        case .selection:
            selectionGenerator().selectionChanged()
        case let .impact(style, intensity):
            impactGenerator(style).impactOccurred(intensity: intensity)
        case let .notification(type):
            notificationGenerator().notificationOccurred(type)
        }
    }
    
    /// Call when a gesture starts, so the first haptic plays without lag.
    public static func prepare(_ haptic: BipeHaptic) {
        switch haptic.primitive {
        case .selection: selectionGenerator().prepare()
        case let .impact(style, _): impactGenerator(style).prepare()
        case .notification: notificationGenerator().prepare()
        }
    }
    
    private static func selectionGenerator() -> UISelectionFeedbackGenerator {
        if let selection {
            return selection
        }
        let generator = UISelectionFeedbackGenerator()
        selection = generator
        return generator
    }
    
    private static func impactGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let generator = impacts[style] {
            return generator
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        impacts[style] = generator
        return generator
    }
    
    private static func notificationGenerator() -> UINotificationFeedbackGenerator {
        if let notification {
            return notification
        }
        let generator = UINotificationFeedbackGenerator()
        notification = generator
        return generator
    }
}

public extension View {
    /// Plays `haptic` each time `trigger` changes to a value for which `when` is true.
    func bipeHaptic<T: Equatable>(_ haptic: BipeHaptic, trigger: T, when condition: @escaping (T) -> Bool = { _ in true }) -> some View {
        onChange(of: trigger) { _, newValue in
            if condition(newValue) {
                BipeHaptics.play(haptic)
            }
        }
    }
}
#endif
