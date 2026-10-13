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
    @State private var qrCodeInvite: QRCodeInvite?
    
    var body: some View {
        Form {
            Section {
                ListRow(label: .plain(title: BipeStrings.invitesAvailable(String(context.viewState.available))),
                        kind: .label)
                ListRow(label: .action(title: BipeStrings.invitesCreate, icon: \.plus),
                        kind: .button { context.send(viewAction: .create) })
                    .disabled(!context.viewState.canCreate)
            } footer: {
                Text(context.viewState.footer)
                    .compoundListSectionFooter()
            }
            
            Section {
                if context.viewState.invites.isEmpty, !context.viewState.isLoading {
                    ListRow(label: .plain(title: BipeStrings.invitesEmpty), kind: .label)
                }
                ForEach(context.viewState.invites) { invite in
                    row(for: invite)
                }
            }
        }
        .compoundList()
        .navigationTitle(BipeStrings.invitesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .sheet(item: $qrCodeInvite) { invite in
            BipeInviteQRCodeSheet(url: invite.url, shareTitle: L10n.actionShare)
                .presentationDetents([.large])
        }
    }
    
    @ViewBuilder
    private func row(for invite: BipeInvite) -> some View {
        switch invite.status {
        case .pending:
            VStack(alignment: .leading, spacing: 8) {
                ListRow(label: .default(title: invite.status.title,
                                        description: BipeStrings.invitesExpires(invite.expiresAt.formatted(date: .abbreviated, time: .omitted)),
                                        icon: \.time),
                        kind: .label)
                HStack(spacing: 12) {
                    if let url = context.viewState.shareURLs[invite.id] {
                        ShareLink(item: BipeStrings.invitesShareMessage(url.absoluteString)) {
                            Label(L10n.actionShare, icon: \.shareIos)
                        }
                        .buttonStyle(.compound(.secondary, size: .medium))
                        Button {
                            qrCodeInvite = QRCodeInvite(id: invite.id, url: url)
                        } label: {
                            Label(BipeStrings.invitesQrAction, icon: \.qrCode)
                        }
                        .buttonStyle(.compound(.secondary, size: .medium))
                    }
                    Button(role: .destructive) {
                        context.send(viewAction: .revoke(inviteID: invite.id))
                    } label: {
                        Text(BipeStrings.invitesRevoke)
                    }
                    .buttonStyle(.compound(.tertiary, size: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        case .used:
            if let userID = invite.joinedUserId {
                ListRow(label: .default(title: handleResolver?.displayText(for: userID) ?? userID,
                                        description: invite.status.title,
                                        icon: \.checkCircle),
                        kind: .navigationLink { context.send(viewAction: .openUserProfile(userID: userID)) })
            }
        case .expired, .revoked:
            ListRow(label: .default(title: invite.status.title,
                                    description: invite.createdAt.formatted(date: .abbreviated, time: .omitted),
                                    icon: \.close),
                    kind: .label)
        }
    }
}

private struct QRCodeInvite: Identifiable {
    let id: String
    let url: URL
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
