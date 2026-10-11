//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

/// Proseio: the sender-side transcript under a voice message (proseio/docs/audio.md).
struct ProseioVoiceTranscriptView: View {
    let text: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProseioStrings.voiceTranscriptTitle)
                .font(.compound.bodyXSSemibold)
                .foregroundStyle(.compound.textSecondary)
            Text(text)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(isExpanded ? nil : Self.collapsedLineLimit)
            // A character count approximates truncation: measuring rendered lines costs a layout pass per row.
            if text.count > Self.collapseThreshold {
                Button(isExpanded ? ProseioStrings.actionShowLess : ProseioStrings.actionShowMore) {
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

struct ProseioVoiceTranscriptView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ProseioVoiceTranscriptView(text: "Oi, chego às sete. Leva o carregador?")
            ProseioVoiceTranscriptView(text: String(repeating: "Mãe, o ônibus atrasou e eu vou chegar mais tarde hoje. ", count: 6))
        }
        .padding()
    }
}
