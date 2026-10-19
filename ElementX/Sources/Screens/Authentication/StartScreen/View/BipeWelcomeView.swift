//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe's welcome content on the start screen: the logo, the welcome line, the promise and three value points.
/// Android: `BipeWelcomeView` in libraries/bipe.
struct BipeWelcomeView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    /// "@ana te chamou para o Bipe." replaces the welcome line and the title when an invite is pending (bipe#415).
    var invitedBy: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if verticalSizeClass == .regular {
                BipeAppLogo()
                    .padding(.bottom, 32)
            }
            
            if invitedBy == nil {
                Text(BipeStrings.onboardingWelcome)
                    .font(.compound.bodyLGSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            
            Text(invitedBy ?? BipeStrings.onboardingTitle)
                .font(.compound.headingXLBold)
                .foregroundStyle(.compound.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 32)
            
            VStack(alignment: .leading, spacing: 16) {
                point(icon: \.shield, text: BipeStrings.onboardingPointScam)
                point(icon: \.locationPin, text: BipeStrings.onboardingPointBrazil)
                point(icon: \.block, text: BipeStrings.onboardingPointNoAds)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom)
        .readableFrame()
    }
    
    private func point(icon: KeyPath<CompoundIcons, Image>, text: String) -> some View {
        HStack(spacing: 16) {
            CompoundIcon(icon, size: .small, relativeTo: .compound.bodyLG)
                .foregroundStyle(.compound.iconAccentPrimary)
                .padding(10)
                .background(.compound.bgAccentSubtle, in: Circle())
                .accessibilityHidden(true)
            
            Text(text)
                .font(.compound.bodyLG)
                .foregroundStyle(.compound.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The Bipe app icon with the açaí glow. Start screen and app lock.
struct BipeAppLogo: View {
    var body: some View {
        Image(asset: Asset.Images.appLogo)
            .resizable()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .compound.bgAccentRest.opacity(0.35), radius: 24, y: 8)
            .accessibilityHidden(true)
    }
}

/// Bipe's start screen background: an açaí wash from the top over the canvas colour.
/// Replaces Element's launch artwork. Works in light, dark and high contrast through Compound tokens.
///
/// Wash spec (same numbers in Android `Modifier.bipeWelcomeBackground()`, libraries/bipe BipeWelcomeView.kt):
/// - Base: bgCanvasDefault, full screen, behind the system bars.
/// - Vertical gradient over the full screen height, top to bottom:
///   gradientSubtleStop1 at 0, stop2 at 0.2, stop3 at 0.4, stop4 at 0.55, stop5 at 0.7,
///   and stop5 with alpha 0 at 0.85.
/// - The end stop is stop5 with alpha 0, not gradientSubtleStop6 (transparent black). Android (Skia) interpolates
///   unpremultiplied colours, so a fade to transparent black darkens the last segment there. With one RGB at both
///   ends of the last segment, premultiplied and unpremultiplied interpolation give the same pixels.
struct BipeWelcomeBackground: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .compound.gradientSubtleStop1, location: 0),
                               .init(color: .compound.gradientSubtleStop2, location: 0.2),
                               .init(color: .compound.gradientSubtleStop3, location: 0.4),
                               .init(color: .compound.gradientSubtleStop4, location: 0.55),
                               .init(color: .compound.gradientSubtleStop5, location: 0.7),
                               .init(color: .compound.gradientSubtleStop5.opacity(0), location: 0.85)],
                       startPoint: .top,
                       endPoint: .bottom)
            .background(.compound.bgCanvasDefault)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

struct BipeWelcomeView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        BipeWelcomeView()
            .background { BipeWelcomeBackground() }
            .previewDisplayName("Light")
        BipeWelcomeView()
            .background { BipeWelcomeBackground() }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
    }
}
