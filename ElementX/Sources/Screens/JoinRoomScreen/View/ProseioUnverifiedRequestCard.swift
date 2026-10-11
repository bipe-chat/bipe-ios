//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

/// Proseio: "Conta não verificada" card on a message request (trust-ui.md, neutral level).
struct ProseioUnverifiedRequestCard: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(ProseioStrings.bannerUnverifiedTitle)
                    .font(.compound.bodyMDSemibold)
                Text(ProseioStrings.requestUnverifiedBody)
                    .font(.compound.bodySM)
            }
            .foregroundStyle(.compound.textTrustNeutral)
        } icon: {
            CompoundIcon(\.help, size: .small, relativeTo: .compound.bodyMDSemibold)
                .foregroundStyle(.compound.iconTrustNeutral)
        }
        .labelStyle(.custom(spacing: 8, alignment: .top))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.compound.bgTrustNeutralSubtle, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 0.5)
                .stroke(.compound.borderTrustNeutral)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProseioUnverifiedRequestCard_Previews: PreviewProvider {
    static var previews: some View {
        ProseioUnverifiedRequestCard()
            .padding()
    }
}
