//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe ADR 0034: opens the chat with the inviter, at the top of the chat list until the user sends them a first message.
/// The avatar is the inviter's, at the size and inset of a chat row, so the row lines up with the chats under it (bipe#449).
struct BipeInviterRow: View {
    let inviterHandle: String
    let inviter: UserProfile
    let mediaProvider: MediaProviderProtocol?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                LoadableAvatarImage(url: inviter.avatarURL,
                                    name: inviter.displayName ?? inviterHandle,
                                    contentID: inviter.id,
                                    avatarSize: .room(on: .chats),
                                    mediaProvider: mediaProvider)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(BipeStrings.inviterCardTitle(inviterHandle))
                        .font(.compound.bodyLGSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Text(BipeStrings.inviterCardBody)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                CompoundIcon(\.chevronRight, size: .small, relativeTo: .compound.bodyLG)
                    .foregroundStyle(.compound.iconTertiaryAlpha)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct BipeInviterRow_Previews: PreviewProvider {
    static var previews: some View {
        BipeInviterRow(inviterHandle: "mz", inviter: UserProfile(userID: "@mz:bipe.net.br", displayName: "MZ"), mediaProvider: nil) { }
    }
}
