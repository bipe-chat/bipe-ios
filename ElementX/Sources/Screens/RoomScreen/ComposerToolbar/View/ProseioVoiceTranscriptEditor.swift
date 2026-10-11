//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

/// Proseio: the sender checks and corrects the transcript of a recorded voice message before sending it.
struct ProseioVoiceTranscriptEditor: View {
    @Bindable var draft: VoiceTranscriptDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProseioStrings.voiceTranscriptTitle)
                .font(.compound.bodyXSSemibold)
                .foregroundStyle(.compound.textSecondary)

            switch draft.state {
            case .transcribing:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(ProseioStrings.voiceTranscribing)
                }
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
            case .ready:
                TextField(ProseioStrings.voiceTranscriptPlaceholder, text: $draft.text, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
            case .unavailable:
                Text(ProseioStrings.voiceTranscriptUnavailable)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProseioVoiceTranscriptEditor_Previews: PreviewProvider {
    static var previews: some View {
        ProseioVoiceTranscriptEditor(draft: VoiceTranscriptDraft(transcript: "Oi, chego às sete. Leva o carregador?"))
            .padding()
    }
}
