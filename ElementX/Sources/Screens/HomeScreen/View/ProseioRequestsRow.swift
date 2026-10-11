//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

/// Proseio: entry to the message requests (pending DM invites) at the top of the chat list.
struct ProseioRequestsRow: View {
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
                    Text(ProseioStrings.requestsTitle)
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Text(ProseioStrings.requestsRowBody)
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

struct ProseioRequestsRow_Previews: PreviewProvider {
    static var previews: some View {
        ProseioRequestsRow(count: 3) { }
    }
}
