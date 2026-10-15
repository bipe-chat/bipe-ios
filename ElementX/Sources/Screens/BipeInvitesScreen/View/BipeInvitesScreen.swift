//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

struct BipeInvitesScreen: View {
    @Bindable var context: BipeInvitesScreenViewModel.Context
    @Environment(\.bipeHandleResolver) private var handleResolver
    @State private var selectedPendingInvite: BipeInvite?
    
    var body: some View {
        Form {
            inviteSection
            joinedSection
            pendingSection
        }
        .compoundList()
        .navigationTitle(BipeStrings.invitesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .confirmationDialog(BipeStrings.invitesLink,
                            isPresented: isPendingInviteDialogPresented,
                            titleVisibility: .hidden,
                            presenting: selectedPendingInvite) { invite in
            pendingInviteActions(for: invite)
        }
        .sheet(item: $context.shareSheetLink) { link in
            AppActivityView(activityItems: [BipeStrings.invitesShareMessage(link.url.absoluteString)])
                .ignoresSafeArea(edges: .bottom)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $context.qrCodeLink) { link in
            BipeInviteQRCodeSheet(url: link.url, shareTitle: L10n.actionShare)
                .presentationDetents([.large])
        }
    }
    
    private var inviteSection: some View {
        Section {
            VStack(spacing: 12) {
                Button { context.send(viewAction: .inviteByLink) } label: {
                    Label(BipeStrings.invitesInviteSomeone, icon: \.shareIos)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary))
                
                Button { context.send(viewAction: .inviteInPerson) } label: {
                    Label(BipeStrings.invitesShowQr, icon: \.qrCode)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.secondary))
            }
            .disabled(!context.viewState.canCreate)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text(context.viewState.footer)
                .compoundListSectionFooter()
        }
    }
    
    @ViewBuilder
    private var joinedSection: some View {
        let joinedInvites = context.viewState.joinedInvites
        if !joinedInvites.isEmpty {
            Section {
                ForEach(joinedInvites) { invite in
                    if let userID = invite.joinedUserId {
                        ListRow(label: .default(title: handleResolver?.displayText(for: userID) ?? userID,
                                                description: invite.status.title,
                                                icon: \.checkCircle),
                                kind: .navigationLink { context.send(viewAction: .openUserProfile(userID: userID)) })
                    }
                }
            } header: {
                Text("\(BipeStrings.invitesJoinedHeader) (\(joinedInvites.count))")
                    .compoundListSectionHeader()
            }
        }
    }
    
    @ViewBuilder
    private var pendingSection: some View {
        let pendingInvites = context.viewState.pendingInvites
        if !pendingInvites.isEmpty {
            Section {
                ForEach(pendingInvites) { invite in
                    ListRow(label: .default(title: BipeStrings.invitesLink,
                                            description: description(for: invite),
                                            icon: \.time),
                            kind: .button { selectedPendingInvite = invite })
                }
            } header: {
                Text(BipeStrings.invitesPendingHeader)
                    .compoundListSectionHeader()
            }
        }
    }
    
    @ViewBuilder
    private func pendingInviteActions(for invite: BipeInvite) -> some View {
        // Links live only on the device that made them; the server keeps a hash of the code.
        if context.viewState.shareURLs[invite.id] != nil {
            Button(L10n.actionShare) { context.send(viewAction: .share(inviteID: invite.id)) }
            Button(BipeStrings.invitesQrAction) { context.send(viewAction: .showQRCode(inviteID: invite.id)) }
        }
        Button(BipeStrings.invitesRevoke, role: .destructive) { context.send(viewAction: .revoke(inviteID: invite.id)) }
    }
    
    private var isPendingInviteDialogPresented: Binding<Bool> {
        Binding(get: { selectedPendingInvite != nil },
                set: { if !$0 { selectedPendingInvite = nil } })
    }
    
    private func description(for invite: BipeInvite) -> String {
        let expiry = BipeStrings.invitesExpires(invite.expiresAt.formatted(date: .abbreviated, time: .omitted))
        guard context.viewState.shareURLs[invite.id] == nil else { return expiry }
        return "\(expiry). \(BipeStrings.invitesOtherDevice)"
    }
}

// MARK: - Previews

struct BipeInvitesScreen_Previews: PreviewProvider {
    static let viewModel = BipeInvitesScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                         clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                         userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipeInvitesScreen(context: viewModel.context)
        }
    }
}
