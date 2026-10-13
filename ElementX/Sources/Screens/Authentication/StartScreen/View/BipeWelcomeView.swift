//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe's welcome content on the start screen: the logo, the promise and three value points.
/// Android: `BipeWelcomeView` in libraries/bipe.
struct BipeWelcomeView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if verticalSizeClass == .regular {
                logo
                    .padding(.bottom, 32)
            }

            Text(BipeStrings.onboardingTitle)
                .font(.compound.headingXLBold)
                .foregroundStyle(.compound.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 16) {
                point(icon: \.shield, text: BipeStrings.onboardingPointScam)
                point(icon: \.mention, text: BipeStrings.onboardingPointHandle)
                point(icon: \.block, text: BipeStrings.onboardingPointNoAds)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom)
        .readableFrame()
    }

    private var logo: some View {
        Image(asset: Asset.Images.appLogo)
            .resizable()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .compound.bgAccentRest.opacity(0.35), radius: 24, y: 8)
            .accessibilityHidden(true)
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

/// Bipe's start screen background: a soft açaí wash from the top over the canvas colour.
/// Replaces Element's launch artwork. Works in light, dark and high contrast through Compound tokens.
struct BipeWelcomeBackground: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .compound.gradientSubtleStop1, location: 0),
                               .init(color: .compound.gradientSubtleStop2, location: 0.12),
                               .init(color: .compound.gradientSubtleStop3, location: 0.25),
                               .init(color: .compound.gradientSubtleStop4, location: 0.38),
                               .init(color: .compound.gradientSubtleStop5, location: 0.5),
                               .init(color: .compound.gradientSubtleStop6, location: 0.65)],
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
