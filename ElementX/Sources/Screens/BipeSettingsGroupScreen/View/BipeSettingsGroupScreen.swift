//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: one settings group, rendered from the registry (ADR 0112).
struct BipeSettingsGroupScreen: View {
    @Bindable var context: BipeSettingsGroupScreenViewModel.Context
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            ForEach(context.viewState.blocks) { block in
                Section {
                    ForEach(block.rows, id: \.self) { row in
                        rowView(row)
                    }
                } header: {
                    if let title = block.title {
                        Text(title)
                            .compoundListSectionHeader()
                    }
                } footer: {
                    if let footer = block.footer {
                        Text(footer)
                            .compoundListSectionFooter()
                    }
                }
            }
        }
        .compoundList()
        .navigationTitle(context.viewState.group.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .onAppear { context.send(viewAction: .reload) }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: BipeSettingsRow) -> some View {
        switch row {
        case .profileNamePhoto:
            linkRow(row, value: context.viewState.displayName)
        case .profileHandle:
            linkRow(row, value: context.viewState.handle.map { "@\($0)" } ?? BipeStrings.settingsHandleNone)
        case .profilePublicProfile:
            linkRow(row, value: context.viewState.publicProfileEnabled.map { $0 ? BipeStrings.publicProfileOn : BipeStrings.publicProfileOff })
        default:
            switch row.kind {
            case .url:
                urlRow(row)
            case .link, .choice, .action:
                linkRow(row, value: nil)
            case .destructive:
                ListRow(label: .action(title: row.title, icon: \.signOut, role: .destructive),
                        kind: .button { context.send(viewAction: .open(row)) })
            case .switch, .info:
                EmptyView()
            }
        }
    }

    private func linkRow(_ row: BipeSettingsRow, value: String?) -> some View {
        ListRow(label: .plain(title: row.title),
                details: value.map { .title($0) },
                kind: .navigationLink { context.send(viewAction: .open(row)) })
    }

    private func urlRow(_ row: BipeSettingsRow) -> some View {
        ListRow(label: .plain(title: row.title),
                details: .systemIcon(.arrowUpRight),
                kind: .button {
                    if let url = row.url(language: BipeSettingsGroup.urlLanguage) {
                        openURL(url)
                    }
                })
    }
}

// MARK: - Previews

struct BipeSettingsGroupScreen_Previews: PreviewProvider {
    static let viewModel = BipeSettingsGroupScreenViewModel(group: .profile,
                                                            userSession: UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@alice:bipe.net.br")))),
                                                            appLockService: AppLockServiceMock.mock(),
                                                            userIndicatorController: UserIndicatorControllerMock())

    static var previews: some View {
        ElementNavigationStack {
            BipeSettingsGroupScreen(context: viewModel.context)
        }
    }
}
