//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

extension View {
    /// Bipe: a trailing swipe action for a row in a `LazyVStack`, where `swipeActions` does not work.
    /// A short swipe reveals the button, a long swipe runs the action.
    func bipeSwipeAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        modifier(BipeSwipeActionModifier(title: title, systemImage: systemImage, action: action))
    }
}

private struct BipeSwipeActionModifier: ViewModifier {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var isPastFullSwipe = false
    
    private let buttonWidth: CGFloat = 88
    private let fullSwipeWidth: CGFloat = 200
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                if offset < 0 {
                    Button(action: run) {
                        VStack(spacing: 4) {
                            Image(systemName: systemImage)
                                .font(.compound.headingMD)
                            Text(title)
                                .font(.compound.bodySMSemibold)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.compound.textOnSolidPrimary)
                        .frame(width: -offset)
                        .frame(maxHeight: .infinity)
                        .background(.compound.iconSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipped()
            .gesture(BipeHorizontalPanGesture(onChange: change, onEnd: end))
            .accessibilityAction(named: title, action)
    }
    
    private func change(_ translation: CGFloat) {
        offset = min(0, restingOffset + translation)
        
        let isPast = offset < -fullSwipeWidth
        guard isPast != isPastFullSwipe else { return }
        isPastFullSwipe = isPast
        BipeHaptics.play(isPast ? .threshold : .release)
    }
    
    private func end(_ translation: CGFloat, _ velocity: CGFloat) {
        isPastFullSwipe = false
        let target = restingOffset + translation
        if target < -fullSwipeWidth {
            run()
        } else if target < -buttonWidth / 2 || velocity < -500 {
            settle(at: -buttonWidth)
        } else {
            settle(at: 0)
        }
    }
    
    private func run() {
        settle(at: 0)
        action()
    }
    
    private func settle(at value: CGFloat) {
        restingOffset = value
        withAnimation(.snappy) { offset = value }
    }
}

/// A pan that starts only on a horizontal drag, so vertical scrolling in the list still works.
private struct BipeHorizontalPanGesture: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat, CGFloat) -> Void
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began:
            BipeHaptics.prepare(.threshold)
        case .changed:
            onChange(translation)
        case .ended, .cancelled:
            onEnd(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
