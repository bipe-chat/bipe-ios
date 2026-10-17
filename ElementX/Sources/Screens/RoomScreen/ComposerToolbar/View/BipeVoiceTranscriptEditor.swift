//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: the sender checks and corrects the transcript of a recorded voice message before sending it.
struct BipeVoiceTranscriptEditor: View {
    @Bindable var draft: VoiceTranscriptDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BipeStrings.voiceTranscriptTitle)
                .font(.compound.bodyXSSemibold)
                .foregroundStyle(.compound.textSecondary)
            
            switch draft.state {
            case .transcribing:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(BipeStrings.voiceTranscribing)
                }
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
            case .ready:
                TextField(BipeStrings.voiceTranscriptPlaceholder, text: $draft.text, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
            case .unavailable:
                Text(BipeStrings.voiceTranscriptUnavailable)
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

struct BipeVoiceTranscriptEditor_Previews: PreviewProvider {
    static var previews: some View {
        BipeVoiceTranscriptEditor(draft: VoiceTranscriptDraft(transcript: "Oi, chego às sete. Leva o carregador?"))
            .padding()
    }
}
