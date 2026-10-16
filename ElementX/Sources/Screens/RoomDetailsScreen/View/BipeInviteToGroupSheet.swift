//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// "Convidar para um grupo" in a DM: the groups you are in. A DM itself never gets more people.
struct BipeInviteToGroupSheet: View {
    let picker: BipeInviteToGroupPicker
    let context: RoomDetailsScreenViewModel.Context
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                if picker.groups.isEmpty {
                    Section {
                        ListRow(kind: .custom {
                            Text(BipeStrings.dmInviteToGroupEmpty)
                                .font(.compound.bodyMD)
                                .foregroundStyle(.compound.textSecondary)
                                .padding(ListRowPadding.insets)
                        })
                    }
                } else {
                    Section {
                        ForEach(picker.groups) { group in
                            ListRow(label: .avatar(title: group.name,
                                                   icon: RoomAvatarImage(avatar: group.avatar,
                                                                         avatarSize: .room(on: .notificationSettings),
                                                                         mediaProvider: context.mediaProvider)
                                                       .accessibilityHidden(true)),
                                    kind: .button {
                                        context.send(viewAction: .inviteToGroup(roomID: group.id))
                                    })
                                    .lineLimit(1)
                        }
                    }
                }
            }
            .compoundList()
            .navigationTitle(BipeStrings.dmInviteToGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
            }
        }
    }
}
