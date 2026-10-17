//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: entry to the message requests (pending DM invites) at the top of the chat list.
struct BipeRequestsRow: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CompoundIcon(\.userAdd)
                    .foregroundStyle(.compound.iconSecondary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(BipeStrings.requestsTitle)
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Text(BipeStrings.requestsRowBody)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(count, format: .number)
                    .font(.compound.bodySMSemibold)
                    .foregroundStyle(.compound.textOnSolidPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.compound.iconAccentPrimary, in: Capsule())
                
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

struct BipeRequestsRow_Previews: PreviewProvider {
    static var previews: some View {
        BipeRequestsRow(count: 3) { }
    }
}
