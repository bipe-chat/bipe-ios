//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

/// Bipe: the "Perfil de confiança" card at the top of Settings (proseio/docs/trust-levels.md).
struct BipeTrustProfileSection: View {
    let profile: BipeTrustProfile
    let send: (SettingsScreenViewAction) -> Void

    var body: some View {
        Section {
            ListRow(kind: .custom { header })

            ForEach(profile.steps) { step in
                stepRow(step)

                if step.id == .profile {
                    ForEach(profile.missingProfileItems, id: \.self) { item in
                        missingItemRow(item)
                    }
                }
            }
        } footer: {
            Text(ProseioStrings.trustFooter)
                .compoundListSectionFooter()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ProseioStrings.trustTitle)
                    .font(.compound.headingSMSemibold)
                    .foregroundStyle(.compound.textPrimary)

                Spacer()

                Text(ProseioStrings.trustProgress(String(profile.completedCount), String(profile.totalCount)))
                    .font(.compound.bodySMSemibold)
                    .foregroundStyle(.compound.textSecondary)
            }

            ProgressView(value: profile.progress)
                .tint(.compound.iconAccentPrimary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, ListRowPadding.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func stepRow(_ step: BipeTrustProfile.Step) -> some View {
        ListRow(label: .default(title: step.title,
                                description: step.description,
                                icon: statusIcon(step.status)),
                details: step.status == .comingSoon ? .icon(comingSoonTag) : nil,
                kind: .label)
    }

    private func missingItemRow(_ item: BipeTrustProfile.ProfileItem) -> some View {
        ListRow(label: .default(title: item.actionTitle, icon: \.plus),
                kind: .navigationLink {
                    switch item {
                    case .displayName, .avatar: send(.userDetails)
                    case .handle: send(.bipeHandle)
                    }
                })
    }

    @ViewBuilder
    private func statusIcon(_ status: BipeTrustProfile.Status) -> some View {
        switch status {
        case .done:
            CompoundIcon(\.checkCircleSolid)
                .foregroundStyle(.compound.iconSuccessPrimary)
        case .todo:
            CompoundIcon(\.circle)
                .foregroundStyle(.compound.iconSecondary)
        case .comingSoon:
            CompoundIcon(\.circle)
                .foregroundStyle(.compound.iconDisabled)
        }
    }

    private var comingSoonTag: some View {
        Text(ProseioStrings.trustComingSoon)
            .font(.compound.bodyXSSemibold)
            .foregroundStyle(.compound.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.compound.bgSubtleSecondary, in: Capsule())
    }
}

private extension BipeTrustProfile.Step {
    var title: String {
        switch id {
        case .account: ProseioStrings.trustStepAccount
        case .profile: ProseioStrings.trustStepProfile
        case .email: ProseioStrings.trustStepEmail
        case .pix: ProseioStrings.trustStepPix
        case .govbr: ProseioStrings.trustStepGovbr
        }
    }

    var description: String {
        switch id {
        case .account: ProseioStrings.trustStepAccountBody
        case .profile: ProseioStrings.trustStepProfileBody
        case .email: ProseioStrings.trustStepEmailBody
        case .pix: ProseioStrings.trustStepPixBody
        case .govbr: ProseioStrings.trustStepGovbrBody
        }
    }
}

private extension BipeTrustProfile.ProfileItem {
    var actionTitle: String {
        switch self {
        case .displayName: ProseioStrings.trustStepProfileAddName
        case .handle: ProseioStrings.trustStepProfileAddHandle
        case .avatar: ProseioStrings.trustStepProfileAddPhoto
        }
    }
}
