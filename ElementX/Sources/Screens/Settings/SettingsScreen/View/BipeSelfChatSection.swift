//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: the self-chat row at the top of the Você tab (ADR 0053).
struct BipeSelfChatSection: View {
    let action: () -> Void
    
    var body: some View {
        Section {
            ListRow(label: .default(title: BipeStrings.selfChatTitle,
                                    description: BipeStrings.selfChatSubtitle,
                                    icon: \.edit),
                    kind: .navigationLink(action: action))
        }
    }
}
