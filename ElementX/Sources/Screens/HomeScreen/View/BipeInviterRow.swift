//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe ADR 0034: opens the chat with the inviter, at the top of the chat list until the user sends them a first message.
struct BipeInviterRow: View {
    let inviterHandle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CompoundIcon(\.chat)
                    .foregroundStyle(.compound.iconOnSolidPrimary)
                    .frame(width: 32, height: 32)
                    .background(.compound.iconAccentPrimary, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(BipeStrings.inviterCardTitle(inviterHandle))
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Text(BipeStrings.inviterCardBody)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CompoundIcon(\.chevronRight, size: .small, relativeTo: .compound.bodyLG)
                    .foregroundStyle(.compound.iconTertiaryAlpha)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct BipeInviterRow_Previews: PreviewProvider {
    static var previews: some View {
        BipeInviterRow(inviterHandle: "mz") { }
    }
}
