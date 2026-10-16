//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

struct BipeContactsScreen: View {
    @Bindable var context: BipeContactsScreenViewModel.Context
    @Environment(\.bipeHandleResolver) private var handleResolver
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Form {
            BipeInviteButtonsSection(canCreate: context.viewState.canCreateInvite,
                                     footer: context.viewState.inviteFooter,
                                     inviteByLink: { context.send(viewAction: .inviteByLink) },
                                     inviteInPerson: { context.send(viewAction: .inviteInPerson) })
            
            Section {
                ForEach(context.viewState.rows) { row in
                    ListRow(label: .default(title: row.contactName ?? handleResolver?.displayText(for: row.userID) ?? row.userID,
                                            description: description(for: row),
                                            icon: row.joinedWithInvite ? \.checkCircle : \.userProfile),
                            kind: .navigationLink { context.send(viewAction: .openUserProfile(userID: row.userID)) })
                }
                accessRows
                if context.viewState.pendingInviteCount > 0 {
                    ListRow(label: .default(title: BipeStrings.contactsPendingInvites, icon: \.time),
                            details: .title(String(context.viewState.pendingInviteCount)),
                            kind: .navigationLink { context.send(viewAction: .openInvites) })
                }
            } footer: {
                Text(context.viewState.access == .denied ? BipeStrings.contactsDenied : BipeStrings.contactsIntro)
                    .compoundListSectionFooter()
            }
            
            Section {
                ListRow(label: .default(title: BipeStrings.discoveryToggle, icon: \.search),
                        kind: .toggle($context.discoverableByPhone))
            } footer: {
                Text(discoveryFooter)
                    .compoundListSectionFooter()
            }
        }
        .compoundList()
        .navigationTitle(BipeStrings.contactsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .bipeInviteSheets(shareSheetLink: $context.shareSheetLink, qrCodeLink: $context.qrCodeLink)
        .onAppear { context.send(viewAction: .appeared) }
        .onChange(of: context.discoverableByPhone) { context.send(viewAction: .discoverableChanged) }
    }
    
    @ViewBuilder
    private var accessRows: some View {
        switch context.viewState.access {
        case .notDetermined, .unknown:
            ListRow(label: .action(title: BipeStrings.contactsAllow, icon: \.userProfile),
                    kind: .button { context.send(viewAction: .requestAccess) })
        case .denied:
            ListRow(label: .action(title: BipeStrings.contactsOpenSettings, icon: \.settings),
                    kind: .button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    })
        case .granted:
            if context.viewState.isLoading {
                ListRow(kind: .custom { ProgressView().frame(maxWidth: .infinity).padding() })
            } else if context.viewState.hasSearched, context.viewState.rows.isEmpty {
                ListRow(label: .plain(title: BipeStrings.contactsNone), kind: .label)
            }
        }
    }
    
    /// The handle, plus a note when the person joined with the user's invite.
    private func description(for row: BipeContactsScreenRow) -> String? {
        let handle = row.contactName == nil ? nil : handleResolver?.displayText(for: row.userID)
        guard row.joinedWithInvite else { return handle }
        return [handle, BipeStrings.contactsJoinedWithInvite].compactMap(\.self).joined(separator: " · ")
    }
    
    private var discoveryFooter: String {
        switch context.viewState.phoneLinked {
        case .some(false): "\(BipeStrings.discoveryFooter) \(BipeStrings.phoneNotLinked)"
        case .some(true): "\(BipeStrings.discoveryFooter) \(BipeStrings.phoneLinked)"
        case .none: BipeStrings.discoveryFooter
        }
    }
}

// MARK: - Previews

struct BipeContactsScreen_Previews: PreviewProvider {
    static let viewModel = BipeContactsScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                          clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                          userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipeContactsScreen(context: viewModel.context)
        }
    }
}
