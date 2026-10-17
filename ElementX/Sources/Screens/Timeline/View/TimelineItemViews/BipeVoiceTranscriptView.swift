//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: the sender-side transcript under a voice message (bipe/docs/audio.md).
struct BipeVoiceTranscriptView: View {
    let text: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BipeStrings.voiceTranscriptTitle)
                .font(.compound.bodyXSSemibold)
                .foregroundStyle(.compound.textSecondary)
            Text(text)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(isExpanded ? nil : Self.collapsedLineLimit)
            // A character count approximates truncation: measuring rendered lines costs a layout pass per row.
            if text.count > Self.collapseThreshold {
                Button(isExpanded ? BipeStrings.actionShowLess : BipeStrings.actionShowMore) {
                    isExpanded.toggle()
                }
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textActionAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    
    private static let collapsedLineLimit = 3
    private static let collapseThreshold = 140
}

struct BipeVoiceTranscriptView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BipeVoiceTranscriptView(text: "Oi, chego às sete. Leva o carregador?")
            BipeVoiceTranscriptView(text: String(repeating: "Mãe, o ônibus atrasou e eu vou chegar mais tarde hoje. ", count: 6))
        }
        .padding()
    }
}
