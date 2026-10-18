//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: the top of the Você tab (ADR 0112): photo, name and @, never the Matrix ID.
/// A tap opens Seu perfil. The QR code and "Compartilhar perfil" need an @.
struct BipeProfileHeaderSection: View {
    let userProfile: UserProfile
    let handle: String?
    let mediaProvider: MediaProviderProtocol?
    let openProfile: () -> Void
    
    @State private var isShowingQRCode = false
    
    var body: some View {
        Section {
            ListRow(kind: .custom {
                Button(action: openProfile) {
                    HStack(spacing: 12) {
                        LoadableAvatarImage(url: userProfile.avatarURL,
                                            name: userProfile.displayName,
                                            contentID: userProfile.id,
                                            avatarSize: .user(on: .settings),
                                            mediaProvider: mediaProvider)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userProfile.displayName ?? "")
                                .font(.compound.headingMD)
                                .foregroundColor(.compound.textPrimary)
                            
                            if let handle {
                                Text("@\(handle)")
                                    .font(.compound.bodySM)
                                    .foregroundColor(.compound.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        ListRowAccessory.navigationLink
                    }
                    .padding(.horizontal, ListRowPadding.horizontal)
                    .padding(.vertical, 8)
                }
            })
            
            if let handle, let url = BipeProfileLink.url(handle: handle) {
                ListRow(kind: .custom {
                    HStack(spacing: 12) {
                        Button {
                            isShowingQRCode = true
                        } label: {
                            Label(BipeStrings.profileQrAction, icon: \.qrCode)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.compound(.secondary, size: .medium))
                        
                        ShareLink(item: url) {
                            Label(BipeStrings.profileShare, icon: \.shareIos)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.compound(.secondary, size: .medium))
                    }
                    .padding(.horizontal, ListRowPadding.horizontal)
                    .padding(.vertical, 8)
                })
                .sheet(isPresented: $isShowingQRCode) {
                    BipeProfileQRCodeSheet(handle: handle)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
}
