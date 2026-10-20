//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import SwiftUI

struct StartChatScreen: View {
    @ObservedObject var context: StartChatScreenViewModel.Context
    
    var body: some View {
        Form {
            if !context.viewState.isSearching {
                mainContent
            } else {
                searchContent
            }
        }
        .compoundList()
        .track(screen: .StartChat)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(BipeStrings.actionStartChat)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .searchController(query: $context.searchQuery,
                          placeholder: L10n.commonSearchForSomeone,
                          showsCancelButton: false,
                          disablesInteractiveDismiss: true)
        .compoundSearchField()
        .alert(item: $context.alertInfo)
        .bipeInviteSheets(shareSheetLink: $context.bipeInviteShareLink, qrCodeLink: .constant(nil))
        .sheet(item: $context.selectedUserToInvite) { userToInvite in
            SendInviteConfirmationView(userToInvite: userToInvite,
                                       mediaProvider: context.mediaProvider) {
                context.send(viewAction: .createDM(user: userToInvite.user))
            }
        }
        .sheet(isPresented: $context.isJoinRoomByAddressSheetPresented) {
            context.roomAddress = ""
        } content: {
            JoinRoomByAddressView(context: context)
        }
    }
    
    // MARK: - Private
    
    /// The content shown in the form when the search query is empty.
    @ViewBuilder
    private var mainContent: some View {
        createRoomSection
        roomDirectorySearch
        inviteFriendsSection
        joinRoomByAddressSection
        usersSection
    }
    
    private var joinRoomByAddressSection: some View {
        Section {
            ListRow(label: .default(title: L10n.screenStartChatJoinRoomByAddressAction,
                                    icon: \.room),
                    kind: .button {
                        context.isJoinRoomByAddressSheetPresented = true
                    })
        }
    }
    
    private var roomDirectorySearch: some View {
        Section {
            ListRow(label: .default(title: L10n.screenRoomDirectorySearchTitle,
                                    icon: \.listBulleted),
                    kind: .navigationLink {
                        context.send(viewAction: .openRoomDirectorySearch)
                    })
        }
    }
    
    /// The content shown in the form when a search query has been entered.
    @ViewBuilder
    private var searchContent: some View {
        if context.viewState.hasEmptySearchResults {
            noResultsContent
        } else {
            usersSection
        }
    }
    
    private var createRoomSection: some View {
        Section {
            ListRow(label: .default(title: L10n.screenCreateRoomActionCreateRoom,
                                    icon: \.plus),
                    kind: .navigationLink { context.send(viewAction: .createRoom) })
                .accessibilityIdentifier(A11yIdentifiers.startChatScreen.createRoom)
        }
    }
    
    private var inviteFriendsSection: some View {
        Section {
            // Bipe: shares a personal invite, not a profile link (sign-up needs an invite).
            ListRow(label: .default(title: L10n.actionInvitePeopleToApp(InfoPlistReader.main.bundleDisplayName),
                                    icon: \.shareIos),
                    kind: .button { context.send(viewAction: .bipeInviteToApp) })
                .accessibilityIdentifier(A11yIdentifiers.startChatScreen.inviteFriends)
        }
    }
    
    @ViewBuilder
    private var usersSection: some View {
        if !context.viewState.usersSection.users.isEmpty {
            Section {
                ForEach(context.viewState.usersSection.users, id: \.id) { user in
                    UserProfileListRow(user: user,
                                       membership: nil,
                                       mediaProvider: context.mediaProvider,
                                       kind: .button {
                                           context.send(viewAction: .selectUser(user))
                                       })
                }
            } header: {
                if let title = context.viewState.usersSection.title {
                    Text(title)
                        .compoundListSectionHeader()
                }
            }
        } else {
            Section.empty
        }
    }
    
    @ViewBuilder
    private var noResultsContent: some View {
        // Bipe: the search finds exact handles only, so a name finds nobody. Say so (ADR 0111).
        VStack(spacing: 8) {
            Text(context.viewState.bipeHandleNotFound.map(BipeStrings.startChatHandleNotFound) ?? L10n.commonNoResults)
                .font(.compound.bodyLG)
                .foregroundColor(.compound.textSecondary)
            Text(BipeStrings.startChatSearchByHandle)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier(A11yIdentifiers.startChatScreen.searchNoResults)
        
        if let inviter = context.viewState.bipeInviter {
            Section {
                ListRow(label: .avatar(title: BipeStrings.inviterCardTitle(inviter.handle),
                                       description: BipeStrings.inviterCardBody,
                                       icon: LoadableAvatarImage(url: inviter.profile.avatarURL,
                                                                 name: inviter.profile.displayName ?? inviter.handle,
                                                                 contentID: inviter.profile.id,
                                                                 avatarSize: .user(on: .startChat),
                                                                 mediaProvider: context.mediaProvider)),
                        kind: .navigationLink {
                            context.send(viewAction: .selectUser(inviter.profile))
                        })
            }
        }
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.actionCancel) {
                context.send(viewAction: .close)
            }
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.closeStartChat)
        }
    }
}

// MARK: - Previews

struct StartChatScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = {
        let userSettings = UserSettings.mock()
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@userid:example.com"))))
        let userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success([.mockAlice])
        return StartChatScreenViewModel(userSession: userSession,
                                        analytics: AnalyticsServiceMock(.init()),
                                        userIndicatorController: UserIndicatorControllerMock(),
                                        userDiscoveryService: userDiscoveryService)
    }()
    
    static var previews: some View {
        ElementNavigationStack {
            StartChatScreen(context: viewModel.context)
        }
    }
}
