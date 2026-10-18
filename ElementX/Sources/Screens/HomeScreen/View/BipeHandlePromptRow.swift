//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe (bipe#200, bipe#415): "Escolha seu @" at the top of the chat list while the account has no @.
/// Sign-up does not ask for the @. A tap or "Agora não" removes the card for good.
struct BipeHandlePromptRow: View {
    let action: () -> Void
    let onDismiss: () -> Void
    
    private let prompt = BipeOnboardingPrompt.handle
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(verbatim: "@")
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.iconOnSolidPrimary)
                        .frame(width: 32, height: 32)
                        .background(.compound.iconAccentPrimary, in: Circle())
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(BipeStrings.handlePromptTitle)
                            .font(.compound.bodyLGSemibold)
                            .foregroundStyle(.compound.textPrimary)
                        Text(BipeStrings.handlePromptBody)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(prompt.primary.title)
            
            if let skip = prompt.text.first {
                Button(action: onDismiss) {
                    CompoundIcon(\.close, size: .small, relativeTo: .compound.bodyLG)
                        .foregroundStyle(.compound.iconTertiaryAlpha)
                }
                .accessibilityLabel(skip.title)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct BipeHandlePromptRow_Previews: PreviewProvider {
    static var previews: some View {
        BipeHandlePromptRow { } onDismiss: { }
    }
}
