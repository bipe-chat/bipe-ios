//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import MatrixRustSDK
import SwiftUI

nonisolated struct TimelineItemKeyForwarder: Identifiable, Hashable {
    let id: String
    let displayName: String?
    
    init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
    
    init(forwarderID: String, forwarderProfile: ProfileDetails) {
        switch forwarderProfile {
        case let .ready(displayName, _, _, _, _):
            self.init(id: forwarderID,
                      displayName: displayName)
        default:
            self.init(id: forwarderID,
                      displayName: nil)
        }
    }
    
    /// Bipe: a DM says "conversa", never "sala" (bipe#507).
    func message(isDM: Bool) -> String {
        if isDM {
            return if let displayName {
                BipeStrings.dmKeyForwardedKnown(displayName, id)
            } else {
                BipeStrings.dmKeyForwardedUnknown(id)
            }
        }
        
        // Bipe: grupo, not sala (bipe#508)
        return if let displayName {
            BipeStrings.groupCryptoEventKeyForwardedKnownProfileDialogContent(displayName, id)
        } else {
            BipeStrings.groupCryptoEventKeyForwardedUnknownProfileDialogContent(id)
        }
    }
}
