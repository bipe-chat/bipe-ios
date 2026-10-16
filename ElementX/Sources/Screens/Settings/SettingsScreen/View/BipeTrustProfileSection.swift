//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

/// Bipe: the "Perfil de confiança" card at the top of Settings (bipe/docs/trust-levels.md).
/// It collapses to one row when every live step is done (ADR 0112); a tap opens it again.
struct BipeTrustProfileSection: View {
    let profile: BipeTrustProfile
    let send: (SettingsScreenViewAction) -> Void

    @State private var isExpanded = false

    var body: some View {
        if profile.liveStepsDone, !isExpanded {
            Section {
                ListRow(label: .default(title: BipeStrings.trustTitle, icon: \.verified),
                        details: .title(BipeStrings.trustProgress(String(profile.completedCount), String(profile.totalCount))),
                        kind: .navigationLink { isExpanded = true })
            }
        } else {
            card
        }
    }

    private var card: some View {
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
            Text(BipeStrings.trustFooter)
                .compoundListSectionFooter()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(BipeStrings.trustTitle)
                    .font(.compound.headingSMSemibold)
                    .foregroundStyle(.compound.textPrimary)

                Spacer()

                Text(BipeStrings.trustProgress(String(profile.completedCount), String(profile.totalCount)))
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
        Text(BipeStrings.trustComingSoon)
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
        case .account: BipeStrings.trustStepAccount
        case .profile: BipeStrings.trustStepProfile
        case .email: BipeStrings.trustStepEmail
        case .pix: BipeStrings.trustStepPix
        case .govbr: BipeStrings.trustStepGovbr
        }
    }

    var description: String {
        switch id {
        case .account: BipeStrings.trustStepAccountBody
        case .profile: BipeStrings.trustStepProfileBody
        case .email: BipeStrings.trustStepEmailBody
        case .pix: BipeStrings.trustStepPixBody
        case .govbr: BipeStrings.trustStepGovbrBody
        }
    }
}

private extension BipeTrustProfile.ProfileItem {
    var actionTitle: String {
        switch self {
        case .displayName: BipeStrings.trustStepProfileAddName
        case .handle: BipeStrings.trustStepProfileAddHandle
        case .avatar: BipeStrings.trustStepProfileAddPhoto
        }
    }
}
