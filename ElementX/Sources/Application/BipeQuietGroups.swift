//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import MatrixRustSDK
import SwiftUI

/// Groups MVP (bipe#97): groups notify only for mentions, replies and new polls. Runs once per account.
///
/// Mentions in encrypted rooms need the server to push every encrypted event so the NSE can check them after decryption
/// (Synapse `msc4028_push_encrypted_events`). Without it, mentions-only silences an encrypted group completely, so this
/// waits until the server reports support. Turn the server flag on only after Apple grants the NSE filtering entitlement:
/// without it the NSE cannot drop the pushes for the other messages.
@MainActor
struct BipeQuietGroups {
    let clientProxy: ClientProxyProtocol
    
    private static let pollRuleID = "chat.bipe.poll_start"
    
    private var appliedKey: String {
        "bipe.quietGroupsApplied.\(clientProxy.userID)"
    }
    
    func run() async {
        guard !UserDefaults.standard.bool(forKey: appliedKey) else { return }
        
        let settings = clientProxy.notificationSettings
        guard await settings.canPushEncryptedEventsToDevice() else {
            MXLog.info("Bipe quiet groups: waiting for encrypted event push support on the server")
            return
        }
        
        do {
            // A user who already picked a group default keeps it.
            for isEncrypted in [true, false] {
                let current = await settings.getDefaultRoomNotificationMode(isEncrypted: isEncrypted, isOneToOne: false)
                if current == .allMessages {
                    try await settings.setDefaultRoomNotificationMode(isEncrypted: isEncrypted, isOneToOne: false, mode: .mentionsAndKeywordsOnly)
                }
            }
            // A user override rule outranks the room rule that mentions-only adds. A room muted before this rule exists
            // ranks below it, so polls still notify there; rooms muted later rank above it and stay silent.
            try await settings.setCustomPushRule(ruleID: Self.pollRuleID,
                                                 ruleKind: .override,
                                                 actions: [.notify],
                                                 conditions: [.eventMatch(key: "type", pattern: "*.poll.start")])
            UserDefaults.standard.set(true, forKey: appliedKey)
            MXLog.info("Bipe quiet groups: applied")
        } catch {
            MXLog.error("Bipe quiet groups failed: \(error)")
        }
    }
}
