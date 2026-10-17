//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: caution card under an incoming message that looks like a common scam pattern (trust-ui.md, caution level).
struct BipeScamWarningView: View {
    let kind: ScamWarningKind
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(BipeStrings.scamWarningTitle)
                    .font(.compound.bodySMSemibold)
                Text(kind.message)
                    .font(.compound.bodySM)
            }
            .foregroundStyle(.compound.textTrustCaution)
        } icon: {
            CompoundIcon(\.warning, size: .small, relativeTo: .compound.bodySMSemibold)
                .foregroundStyle(.compound.iconTrustCaution)
        }
        .labelStyle(.custom(spacing: 8, alignment: .top))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.compound.bgTrustCautionSubtle, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(.compound.borderTrustCaution)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BipeScamWarningView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            BipeScamWarningView(kind: .pixKey)
            BipeScamWarningView(kind: .newNumber)
        }
        .padding()
    }
}
