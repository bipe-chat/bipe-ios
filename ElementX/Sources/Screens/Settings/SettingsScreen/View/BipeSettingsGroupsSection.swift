//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: the "Configurações" section of the Você tab (ADR 0112). One row per group, each with its current state.
struct BipeSettingsGroupsSection: View {
    let whoCanMessage: BipeWhoCanMessage?
    let waysBack: BipeWaysBack?
    let notificationsOn: Bool?
    let open: (BipeSettingsGroup) -> Void
    
    var body: some View {
        Section {
            ForEach(BipeSettingsGroup.root, id: \.self) { group in
                ListRow(label: .default(title: group.title,
                                        description: subtitle(for: group),
                                        icon: group.icon),
                        details: badge(for: group),
                        kind: .navigationLink { open(group) })
            }
        } header: {
            Text(BipeStrings.settingsSection)
                .compoundListSectionHeader()
        }
    }
    
    private func subtitle(for group: BipeSettingsGroup) -> String? {
        switch group {
        case .privacy: whoCanMessage?.settingsSummary
        case .account: waysBack?.summary
        case .notifications: notificationsOn.map { $0 ? BipeStrings.settingsNotificationsOn : BipeStrings.settingsNotificationsOff }
        case .profile, .chats, .help: nil
        }
    }
    
    /// The only warning badge in Settings: one way back or none.
    private func badge(for group: BipeSettingsGroup) -> ListRowDetails<BadgeView>? {
        guard group == .account, waysBack?.needsWarning == true else { return nil }
        return .icon(BadgeView(size: 10))
    }
}

private extension BipeSettingsGroup {
    var icon: KeyPath<CompoundIcons, Image> {
        switch self {
        case .profile: \.userProfile
        case .privacy: \.shield
        case .account: \.key
        case .notifications: \.notifications
        case .chats: \.chat
        case .help: \.help
        }
    }
}
