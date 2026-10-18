//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe (ADR 0117, bipe#386): the remote critical banner above the chat list. An outage, a forced update or a change
/// of terms. A notice can be closed; an update banner opens the update link and has no close button.
struct BipeRemoteBannerRow: View {
    let banner: BipeRemoteBanner
    let isUpdate: Bool
    let action: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 12) {
                    CompoundIcon(isUpdate ? \.download : \.info)
                        .foregroundStyle(.compound.iconOnSolidPrimary)
                        .frame(width: 32, height: 32)
                        .background(.compound.iconAccentPrimary, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.title)
                            .font(.compound.bodyLGSemibold)
                            .foregroundStyle(.compound.textPrimary)
                        Text(banner.text)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                        if isUpdate {
                            Text(BipeStrings.remoteBannerUpdate)
                                .font(.compound.bodyMDSemibold)
                                .foregroundStyle(.compound.textActionAccent)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

            if !isUpdate {
                Button(action: onDismiss) {
                    CompoundIcon(\.close, size: .small, relativeTo: .compound.bodyLG)
                        .foregroundStyle(.compound.iconTertiaryAlpha)
                }
                .accessibilityLabel(BipeStrings.remoteBannerDismiss)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct BipeRemoteBannerRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            BipeRemoteBannerRow(banner: notice, isUpdate: false) { } onDismiss: { }
            BipeRemoteBannerRow(banner: notice, isUpdate: true) { } onDismiss: { }
        }
    }

    private static var notice: BipeRemoteBanner {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode(BipeRemoteBanner.self, from: Data("""
        {"id": "aviso-1", "title": "Instabilidade agora", "text": "Algumas mensagens podem demorar. Estamos cuidando disso.",
         "link": "https://bipe.chat/", "expiresAt": "2099-01-01T00:00:00Z"}
        """.utf8))
    }
}
