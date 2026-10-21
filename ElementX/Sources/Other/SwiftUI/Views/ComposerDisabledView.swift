//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import SwiftUI

struct ComposerDisabledView: View {
    /// Bipe: a DM says "conversa", never "sala" (bipe#507).
    var isDM = false
    
    var body: some View {
        Text(isDM ? BipeStrings.dmNoPermissionToPost : L10n.screenRoomTimelineNoPermissionToPost)
            .font(.compound.bodyLG)
            .foregroundStyle(.compound.textDisabled)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10) // Matches the MessageComposerStyleModifier
            .padding(.bottom, 12)
    }
}
