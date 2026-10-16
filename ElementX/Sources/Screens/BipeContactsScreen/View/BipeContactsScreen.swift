//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeContactsScreen: View {
    @Bindable var context: BipeContactsScreenViewModel.Context
    @Environment(\.bipeHandleResolver) private var handleResolver
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Form {
            Section {
                switch context.viewState.access {
                case .notDetermined, .unknown:
                    ListRow(label: .action(title: BipeStrings.contactsAllow, icon: \.userProfile),
                            kind: .button { context.send(viewAction: .requestAccess) })
                case .denied:
                    ListRow(label: .action(title: BipeStrings.contactsOpenSettings, icon: \.settings),
                            kind: .button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            })
                case .granted:
                    if context.viewState.isLoading {
                        ListRow(kind: .custom { ProgressView().frame(maxWidth: .infinity).padding() })
                    } else if context.viewState.hasSearched, context.viewState.matches.isEmpty {
                        ListRow(label: .plain(title: BipeStrings.contactsNone), kind: .label)
                    }
                    ForEach(context.viewState.matches) { match in
                        ListRow(label: .default(title: match.contactName,
                                                description: handleResolver?.displayText(for: match.userID),
                                                icon: \.userProfile),
                                kind: .navigationLink { context.send(viewAction: .openUserProfile(userID: match.userID)) })
                    }
                }
                ListRow(label: .action(title: BipeStrings.contactsInvite, icon: \.userAdd),
                        kind: .button { context.send(viewAction: .openInvites) })
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
        .onChange(of: context.discoverableByPhone) { context.send(viewAction: .discoverableChanged) }
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
                                                       clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")))
    
    static var previews: some View {
        ElementNavigationStack {
            BipeContactsScreen(context: viewModel.context)
        }
    }
}
