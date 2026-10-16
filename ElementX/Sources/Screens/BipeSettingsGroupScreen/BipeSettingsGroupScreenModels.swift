//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipeSettingsGroupScreenViewModelAction {
    /// A row that opens another screen or flow.
    case open(BipeSettingsRow)
}

struct BipeSettingsGroupScreenViewState: BindableState {
    let group: BipeSettingsGroup
    /// Bipe API rows show only for accounts on the Bipe server.
    let isBipeAccount: Bool
    /// The `flag:<name>` gates that are on.
    var flags: Set<String> = []

    // MARK: Seu perfil

    var displayName: String?
    var handle: String?
    var publicProfileEnabled: Bool?

    var bindings = BipeSettingsGroupScreenViewStateBindings()

    /// The registry sections, cut into Form sections so that a row footer sits right under its row.
    var blocks: [BipeSettingsBlock] {
        group.sections.flatMap { section in
            BipeSettingsBlock.blocks(for: section, rows: section.rowsShownOnIOS { flags.contains($0) }.filter(isShown))
        }
    }

    private func isShown(_ row: BipeSettingsRow) -> Bool {
        isBipeAccount || !row.needsBipeAccount
    }
}

struct BipeSettingsGroupScreenViewStateBindings {
    var alertInfo: AlertInfo<BipeSettingsGroupScreenAlertType>?
}

enum BipeSettingsGroupScreenAlertType: Hashable {
    case error
}

enum BipeSettingsGroupScreenViewAction {
    /// The screen appeared: first show, or back from a pushed screen that may have changed a value.
    case reload
    case open(BipeSettingsRow)
}

/// One Form section: the registry section's title on the first block, a row footer or the section footer on the last.
struct BipeSettingsBlock: Identifiable {
    let id: String
    let title: String?
    let rows: [BipeSettingsRow]
    let footer: String?

    static func blocks(for section: BipeSettingsSection, rows: [BipeSettingsRow]) -> [BipeSettingsBlock] {
        guard !rows.isEmpty else { return [] }
        var blocks: [BipeSettingsBlock] = []
        var current: [BipeSettingsRow] = []
        for (index, row) in rows.enumerated() {
            current.append(row)
            let isLast = index == rows.count - 1
            let footer = [row.footer, isLast ? section.bipeFooter : nil].compactMap(\.self).joined(separator: "\n\n")
            if !footer.isEmpty || isLast {
                blocks.append(BipeSettingsBlock(id: "\(section.key).\(row.rawValue)",
                                                title: blocks.isEmpty ? section.title : nil,
                                                rows: current,
                                                footer: footer.isEmpty ? nil : footer))
                current = []
            }
        }
        return blocks
    }
}

extension BipeSettingsSection {
    /// The section footer. The senha footer carries the number of digits.
    var bipeFooter: String? {
        footerKey == "bipe_account_pin_footer" ? BipeStrings.accountPinFooter(String(BipeRegistries.pinLength)) : footer
    }
}

extension BipeSettingsRow {
    /// Rows that read or write the Bipe API.
    var needsBipeAccount: Bool {
        switch self {
        case .profileHandle, .profilePublicProfile,
             .privacyMessaging, .privacyNumber, .privacyDiscovery, .privacyContacts, .privacyExport,
             .accountChangePin, .accountEmail, .accountLinkedAccounts:
            true
        default:
            false
        }
    }
}
