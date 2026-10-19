//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: entry to the archived chats at the top of the chat list. Opens the low priority filter.
struct BipeArchivedRow: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.iconSecondary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                
                Text(BipeStrings.archivedTitle)
                    .font(.compound.bodyLGSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(count, format: .number)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                
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

struct BipeArchivedRow_Previews: PreviewProvider {
    static var previews: some View {
        BipeArchivedRow(count: 4) { }
    }
}
