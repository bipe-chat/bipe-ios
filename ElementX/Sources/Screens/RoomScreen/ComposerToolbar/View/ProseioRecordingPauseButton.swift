//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// Proseio: pause a voice message recording and continue it later (proseio/docs/audio.md).
struct ProseioRecordingPauseButton: View {
    @ObservedObject var recorderState: AudioRecorderState
    let pause: () -> Void
    let resume: () -> Void

    var body: some View {
        Button {
            recorderState.isPaused ? resume() : pause()
        } label: {
            CompoundIcon(recorderState.isPaused ? \.micOn : \.pauseSolid,
                         size: .medium,
                         relativeTo: .compound.headingLG)
                .foregroundStyle(.compound.iconSecondary)
                .scaledPadding(6, relativeTo: .compound.headingLG)
        }
        .accessibilityLabel(recorderState.isPaused ? L10n.a11yVoiceMessageRecord : L10n.a11yPause)
    }
}

struct ProseioRecordingPauseButton_Previews: PreviewProvider {
    static var previews: some View {
        ProseioRecordingPauseButton(recorderState: AudioRecorderState()) { } resume: { }
    }
}
