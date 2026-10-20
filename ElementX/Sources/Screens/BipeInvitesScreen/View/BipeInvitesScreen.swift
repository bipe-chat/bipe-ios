//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeInvitesScreen: View {
    @Bindable var context: BipeInvitesScreenViewModel.Context
    @Environment(\.bipeHandleResolver) private var handleResolver
    
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
        .alert(BipeStrings.invitesNameAction, isPresented: isNamingPresented) {
            TextField(BipeStrings.invitesNamePlaceholder, text: $context.nameDraft)
                .textInputAutocapitalization(.words)
            Button(L10n.actionSave) { context.send(viewAction: .saveName) }
            Button(L10n.actionCancel, role: .cancel) { }
        } message: {
            Text(BipeStrings.invitesNameFooter)
        }
        .bipeInviteNoteAlert(destination: $context.noteDestination, note: $context.noteDraft) { context.send(viewAction: .createInvite($0)) }
        .bipeInviteSheets(shareSheetLink: $context.shareSheetLink, qrCodeLink: $context.qrCodeLink)
    }
    
    private var inviteSection: some View {
        BipeInviteButtonsSection(canCreate: context.viewState.canCreate,
                                 footer: context.viewState.footer,
                                 inviteByLink: { context.send(viewAction: .inviteByLink) },
                                 inviteInPerson: { context.send(viewAction: .inviteInPerson) })
    }
    
    @ViewBuilder
    private var joinedSection: some View {
        let joinedInvites = context.viewState.joinedInvites
        if !joinedInvites.isEmpty {
            Section {
                ForEach(joinedInvites) { invite in
                    if let userID = invite.joinedUserId {
                        ListRow(label: .default(title: handleResolver?.displayText(for: userID) ?? userID,
                                                description: joinedDescription(for: invite),
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
                    ListRow(label: .default(title: title(for: invite),
                                            description: description(for: invite),
                                            icon: \.time),
                            kind: .label)
                        .overlay {
                            // A tap opens the menu at the row, so no action needs its own button.
                            Menu {
                                pendingInviteActions(for: invite)
                            } label: {
                                Color.clear.contentShape(Rectangle())
                            }
                            .accessibilityLabel(BipeStrings.invitesLink)
                        }
                }
            } header: {
                Text(BipeStrings.invitesPendingHeader)
                    .compoundListSectionHeader()
            }
        }
    }
    
    @ViewBuilder
    private func pendingInviteActions(for invite: BipeInvite) -> some View {
        Button { context.send(viewAction: .startNaming(inviteID: invite.id)) } label: {
            Label(BipeStrings.invitesNameAction, icon: \.edit)
        }
        // Links live only on the device that made them; the server keeps a hash of the code.
        if context.viewState.shareURLs[invite.id] != nil {
            Button { context.send(viewAction: .share(inviteID: invite.id)) } label: {
                Label(L10n.actionShare, icon: \.shareIos)
            }
            Button { context.send(viewAction: .showQRCode(inviteID: invite.id)) } label: {
                Label(BipeStrings.invitesQrAction, icon: \.qrCode)
            }
        }
        Button(role: .destructive) { context.send(viewAction: .revoke(inviteID: invite.id)) } label: {
            Label(BipeStrings.invitesRevoke, icon: \.delete)
        }
    }
    
    private var isNamingPresented: Binding<Bool> {
        Binding(get: { context.namingInviteID != nil },
                set: {
                    if !$0 {
                        context.namingInviteID = nil
                    }
                })
    }
    
    /// The name the person gave the invite, else its code, so each row can be told apart.
    private func title(for invite: BipeInvite) -> String {
        if let name = context.viewState.names[invite.id] {
            return name
        }
        if let url = context.viewState.shareURLs[invite.id], let code = BipeInviteLink.code(from: url) {
            return code
        }
        return BipeStrings.invitesLink
    }
    
    private func joinedDescription(for invite: BipeInvite) -> String {
        guard let name = context.viewState.names[invite.id] else { return invite.status.title }
        return "\(name) · \(invite.status.title)"
    }
    
    private func description(for invite: BipeInvite) -> String {
        let age = invite.createdAt.formatted(.relative(presentation: .named))
        let expiry = BipeStrings.invitesExpires(invite.expiresAt.formatted(date: .abbreviated, time: .omitted))
        let summary = "\(age) · \(expiry)"
        guard context.viewState.shareURLs[invite.id] == nil else { return summary }
        return "\(summary). \(BipeStrings.invitesOtherDevice)"
    }
}

/// The two invite buttons and the quota under them. The invites and contacts screens both show it.
struct BipeInviteButtonsSection: View {
    let canCreate: Bool
    let footer: String
    let inviteByLink: () -> Void
    let inviteInPerson: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 12) {
                Button(action: inviteByLink) {
                    Label(BipeStrings.invitesInviteSomeone, icon: \.shareIos)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary))
                
                Button(action: inviteInPerson) {
                    Label(BipeStrings.invitesShowQr, icon: \.qrCode)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.secondary))
            }
            .disabled(!canCreate)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text(footer)
                .compoundListSectionFooter()
        }
    }
}

extension View {
    /// Bipe ADR 0136: asks for the note before a new invite is made. The share text never carries the note.
    func bipeInviteNoteAlert(destination: Binding<BipeInviteDestination?>,
                             note: Binding<String>,
                             create: @escaping (BipeInviteDestination) -> Void) -> some View {
        let isPresented = Binding { destination.wrappedValue != nil } set: {
            if !$0 {
                destination.wrappedValue = nil
            }
        }
        return alert(BipeStrings.inviteNoteTitle, isPresented: isPresented, presenting: destination.wrappedValue) { presented in
            TextField(BipeStrings.inviteNotePlaceholder, text: note, axis: .vertical)
            Button(L10n.actionCancel, role: .cancel) { }
            Button(L10n.actionContinue) { create(presented) }
        } message: { _ in
            Text(BipeStrings.inviteNoteFooter)
        }
    }
    
    /// The share sheet and the QR code sheet for a new or pending invite link.
    func bipeInviteSheets(shareSheetLink: Binding<BipeInviteShareLink?>, qrCodeLink: Binding<BipeInviteShareLink?>) -> some View {
        sheet(item: shareSheetLink) { link in
            AppActivityView(activityItems: [BipeStrings.invitesShareMessage(link.url.absoluteString)])
                .ignoresSafeArea(edges: .bottom)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: qrCodeLink) { link in
            BipeInviteQRCodeSheet(url: link.url, shareTitle: L10n.actionShare)
                .presentationDetents([.large])
        }
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
