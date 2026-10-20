//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe ADR 0034: above the composer in the chat with the inviter, until the user sends them a first message.
/// ADR 0136: `inviterKnowsName` adds "já sabe que você chegou" above it while the inviter has not written yet.
struct BipeInviterHint: View {
    let inviterHandle: String
    var inviterKnowsName: String?
    let sayHi: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let inviterKnowsName {
                Text(BipeStrings.inviterKnowsYouJoined(inviterKnowsName))
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
            }
            
            HStack(spacing: 12) {
                Text(BipeStrings.inviterHint(inviterHandle))
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(BipeStrings.inviterHintAction, action: sayHi)
                    .buttonStyle(.compound(.primary, size: .small))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.compound.bgSubtleSecondary)
    }
}

struct BipeInviterHint_Previews: PreviewProvider {
    static var previews: some View {
        BipeInviterHint(inviterHandle: "mz") { }
        BipeInviterHint(inviterHandle: "mz", inviterKnowsName: "MZ") { }
    }
}
