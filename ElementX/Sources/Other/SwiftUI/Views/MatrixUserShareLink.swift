//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import MatrixRustSDK
import SwiftUI

struct MatrixUserShareLink<Label: View>: View {
    private let userID: String
    private let permalink: URL?
    private let label: Label
    @Environment(\.bipeHandleResolver) private var bipeHandleResolver
    
    init(userID: String, @ViewBuilder label: () -> Label) {
        self.userID = userID
        self.label = label()
        permalink = try? URL(string: matrixToUserPermalink(userId: userID))
    }
    
    var body: some View {
        if let profileLink = bipeHandleResolver?.profileLink(for: userID) {
            ShareLink(item: BipeStrings.inviteFriendsText(profileLink.absoluteString)) {
                label
            }
        } else if let permalink {
            ShareLink(item: L10n.inviteFriendsText(InfoPlistReader.main.bundleDisplayName, permalink.absoluteString)) {
                label
            }
        }
    }
}

struct MatrixUserPermalink_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        MatrixUserShareLink(userID: "@someone:somewhere.org") {
            Label("Share", icon: \.shareIos)
        }
    }
}
