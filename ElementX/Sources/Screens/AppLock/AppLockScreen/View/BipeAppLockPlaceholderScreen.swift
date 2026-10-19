//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import LocalAuthentication
import SFSafeSymbols
import SwiftUI

/// Bipe: replaces Element's logo placeholder while the app is locked and Face ID or Touch ID runs.
/// Also what the app switcher shows for a locked app.
final class BipeAppLockPlaceholderScreenCoordinator: CoordinatorProtocol {
    private let biometryType: LABiometryType?
    
    /// `biometryType` is nil when biometric unlock is off.
    init(biometryType: LABiometryType?) {
        self.biometryType = biometryType
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeAppLockPlaceholderScreen(biometryType: biometryType))
    }
}

struct BipeAppLockPlaceholderScreen: View {
    let biometryType: LABiometryType?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            BipeAppLogo()
                .padding(.bottom, 32)
            
            Label {
                Text(BipeStrings.appLockTitle)
            } icon: {
                CompoundIcon(\.lockSolid, size: .small, relativeTo: .compound.headingMDBold)
            }
            .font(.compound.headingMDBold)
            .foregroundStyle(.compound.textPrimary)
            .accessibilityAddTraits(.isHeader)
            
            if let biometryType, biometryType != .none {
                VStack(spacing: 12) {
                    Image(systemSymbol: biometryType.systemSymbol)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.compound.iconAccentPrimary)
                        .symbolEffect(.pulse, options: .repeating)
                        .accessibilityHidden(true)
                    
                    Text(BipeStrings.appLockBiometric(biometryType.localizedString))
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { BipeWelcomeBackground() }
        .ignoresSafeArea(.keyboard)
    }
}

struct BipeAppLockPlaceholderScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        BipeAppLockPlaceholderScreen(biometryType: .faceID)
            .previewDisplayName("Face ID")
        BipeAppLockPlaceholderScreen(biometryType: .faceID)
            .preferredColorScheme(.dark)
            .previewDisplayName("Face ID, dark")
        BipeAppLockPlaceholderScreen(biometryType: nil)
            .previewDisplayName("PIN only")
    }
}
