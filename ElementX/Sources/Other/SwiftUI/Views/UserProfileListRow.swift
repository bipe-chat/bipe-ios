//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import MatrixRustSDK
import SwiftUI

struct UserProfileListRow: View {
    let user: UserProfile
    let membership: MembershipState?
    let mediaProvider: MediaProviderProtocol?
    
    let kind: ListRow<LoadableAvatarImage, EmptyView, EmptyView, Bool>.Kind<EmptyView, Bool>
    @Environment(\.bipeHandleResolver) private var bipeHandleResolver
    
    /// Bipe: "@handle" in place of the Matrix ID when the handle is known.
    private var displayedUserID: String {
        bipeHandleResolver?.displayText(for: user.id) ?? user.id
    }
    
    var isUnknownProfile: Bool {
        // Bipe: a known handle proves the account exists.
        !user.isVerified && membership == nil && displayedUserID == user.id
    }
    
    private var subtitle: String? {
        guard !isUnknownProfile else { return L10n.commonInviteUnknownProfile }
        
        if let membershipText = membership?.localizedDescription {
            return membershipText
        } else if user.displayName != nil {
            return displayedUserID
        } else {
            return nil
        }
    }
    
    var body: some View {
        ListRow(label: .avatar(title: user.displayName ?? displayedUserID,
                               description: subtitle,
                               icon: avatar,
                               role: isUnknownProfile ? .error : nil),
                kind: kind)
    }
    
    var avatar: LoadableAvatarImage {
        LoadableAvatarImage(url: user.avatarURL,
                            name: user.displayName,
                            contentID: user.id,
                            avatarSize: .user(on: .startChat),
                            mediaProvider: mediaProvider)
    }
}

private extension MembershipState {
    var localizedDescription: String? {
        switch self {
        case .join:
            return L10n.screenInviteUsersAlreadyAMember
        case .invite:
            return L10n.screenInviteUsersAlreadyInvited
        default:
            return nil
        }
    }
}

struct UserProfileCell_Previews: PreviewProvider, TestablePreview {
    static let action: () -> Void = { }
    
    static var previews: some View {
        Form {
            UserProfileListRow(user: .mockAlice, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: true, action: action))
            
            UserProfileListRow(user: .mockBob, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            UserProfileListRow(user: .mockCharlie, membership: .join, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: true, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: .join, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
        }
        .compoundList()
    }
}
