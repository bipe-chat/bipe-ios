//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// The clickwrap row (ADR 0113): "Li e aceito os Termos de uso e a Política de privacidade." with both names as links.
/// Sign-up and the re-accept screen use it. Only the box toggles: a tap gesture on the row would swallow the link taps in the text.
struct BipeTermsCheckbox: View {
    @Binding var isAccepted: Bool
    let termsURL: URL
    let privacyURL: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        let sentence = Self.sentence(termsURL: termsURL, privacyURL: privacyURL)
        HStack(alignment: .top, spacing: 12) {
            Button { isAccepted.toggle() } label: {
                CompoundIcon(isAccepted ? \.checkCircleSolid : \.circle)
                    .foregroundColor(isAccepted ? .compound.iconSuccessPrimary : .compound.borderInteractivePrimary)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-10)

            Text(sentence)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
                .tint(.compound.textLinkExternal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // VoiceOver reads a real toggle with its state; the links become actions.
        .accessibilityRepresentation {
            Toggle(String(sentence.characters), isOn: $isAccepted)
        }
        .accessibilityAction(named: BipeStrings.signupTermsLink) { openURL(termsURL) }
        .accessibilityAction(named: BipeStrings.signupPrivacyLink) { openURL(privacyURL) }
    }

    static func sentence(termsURL: URL, privacyURL: URL) -> AttributedString {
        var sentence = AttributedString(BipeStrings.signupTermsAccept("{terms}", "{privacy}"))
        sentence.bipeReplaceLink("{terms}", title: BipeStrings.signupTermsLink, url: termsURL)
        sentence.bipeReplaceLink("{privacy}", title: BipeStrings.signupPrivacyLink, url: privacyURL)
        return sentence
    }
}
