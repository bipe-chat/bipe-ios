//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import MatrixRustSDK
import UIKit

nonisolated struct RoomStateEventStringBuilder {
    let userID: String
    
    func buildString(for change: MembershipChange?,
                     reason: String?,
                     memberUserID: String,
                     memberDisplayName: String?,
                     sender: TimelineItemSender,
                     isOutgoing: Bool,
                     isDM: Bool = false) -> String? {
        guard let change else {
            MXLog.verbose("Filtering timeline item for membership change that is nil")
            return nil
        }
        
        let senderIsYou = isOutgoing
        let memberIsYou = memberUserID == userID
        let member = memberDisplayName ?? memberUserID
        let senderDisplayName = sender.disambiguatedDisplayName ?? sender.id
        
        // Bipe: a DM has no invite lines, in the timeline or the room list preview. An invite pair's
        // auto-accept made "You accepted the invite" the preview.
        if isDM, change == .invited || change == .invitationAccepted {
            return nil
        }
        
        switch change {
        // Bipe: a DM says "conversa", a group says "grupo", never "sala" (bipe#507, bipe#508).
        case .joined:
            if isDM {
                return memberIsYou ? BipeStrings.dmJoinedByYou : BipeStrings.dmJoined(senderDisplayName)
            }
            return memberIsYou ? BipeStrings.groupStateEventRoomJoinByYou : BipeStrings.groupStateEventRoomJoin(senderDisplayName)
        case .left:
            if isDM {
                return memberIsYou ? BipeStrings.dmLeftByYou : BipeStrings.dmLeft(member)
            }
            return memberIsYou ? BipeStrings.groupStateEventRoomLeaveByYou : BipeStrings.groupStateEventRoomLeave(member)
        case .banned, .kickedAndBanned:
            return switch (senderIsYou, reason) {
            case (true, .some(let reason)): L10n.stateEventRoomBanByYouWithReason(member, reason)
            case (true, .none): L10n.stateEventRoomBanByYou(member)
            case (false, .some(let reason)): L10n.stateEventRoomBanWithReason(senderDisplayName, member, reason)
            case (false, .none): L10n.stateEventRoomBan(senderDisplayName, member)
            }
        case .unbanned:
            return senderIsYou ? L10n.stateEventRoomUnbanByYou(member) : L10n.stateEventRoomUnban(senderDisplayName, member)
        case .kicked:
            return switch (senderIsYou, reason) {
            case (true, .some(let reason)): L10n.stateEventRoomRemoveByYouWithReason(member, reason)
            case (true, .none): L10n.stateEventRoomRemoveByYou(member)
            case (false, .some(let reason)): L10n.stateEventRoomRemoveWithReason(senderDisplayName, member, reason)
            case (false, .none): L10n.stateEventRoomRemove(senderDisplayName, member)
            }
        case .invited:
            if senderIsYou {
                return L10n.stateEventRoomInviteByYou(member)
            } else if memberIsYou {
                return buildInvitedYouString(senderDisplayName)
            } else {
                return L10n.stateEventRoomInvite(senderDisplayName, member)
            }
        case .invitationAccepted:
            return memberIsYou ? L10n.stateEventRoomInviteAcceptedByYou : L10n.stateEventRoomInviteAccepted(member)
        case .invitationRejected:
            return memberIsYou ? L10n.stateEventRoomRejectByYou : L10n.stateEventRoomReject(senderDisplayName)
        case .invitationRevoked:
            // Bipe: a DM says "conversa", never "sala" (bipe#507).
            if isDM {
                return senderIsYou ? BipeStrings.dmThirdPartyRevokedInviteByYou(member) : BipeStrings.dmThirdPartyRevokedInvite(senderDisplayName, member)
            }
            // Bipe: grupo, not sala (bipe#508)
            return senderIsYou ? BipeStrings.groupStateEventRoomThirdPartyRevokedInviteByYou(member) : BipeStrings.groupStateEventRoomThirdPartyRevokedInvite(senderDisplayName, member)
        case .knocked:
            return memberIsYou ? L10n.stateEventRoomKnockByYou : L10n.stateEventRoomKnock(member)
        case .knockAccepted:
            return senderIsYou ? L10n.stateEventRoomKnockAcceptedByYou(member) : L10n.stateEventRoomKnockAccepted(senderDisplayName, member)
        case .knockRetracted:
            return memberIsYou ? L10n.stateEventRoomKnockRetractedByYou : L10n.stateEventRoomKnockRetracted(member)
        case .knockDenied:
            if senderIsYou {
                return L10n.stateEventRoomKnockDeniedByYou(member)
            } else if memberIsYou {
                return L10n.stateEventRoomKnockDeniedYou(senderDisplayName)
            } else {
                return L10n.stateEventRoomKnockDenied(senderDisplayName, member)
            }
        case .none, .error, .notImplemented: // Not useful information for the user.
            MXLog.verbose("Filtering timeline item for membership change: \(change)")
            return nil
        }
    }
    
    func buildInvitedYouString(_ senderDisplayName: String) -> String {
        L10n.stateEventRoomInviteYou(senderDisplayName)
    }
    
    /// - Parameters:
    ///   - displayName: The new display name, only set by the SDK when the display name changed.
    ///   - previousDisplayName: The old display name, only set by the SDK when the display name changed.
    ///   - avatarURLString: The new avatar URL, only set by the SDK when the avatar changed.
    ///   - previousAvatarURLString: The old avatar URL, only set by the SDK when the avatar changed.
    ///   - memberID: The member's user ID, used in the display name change strings.
    ///   - memberDisplayName: The member's disambiguated display name, used when only the avatar changed.
    ///   - memberIsYou: Whether the member is the current user, which selects the "You" variant of the strings.
    func buildProfileChangeString(displayName: String?,
                                  previousDisplayName: String?,
                                  avatarURLString: String?,
                                  previousAvatarURLString: String?,
                                  memberID: String,
                                  memberDisplayName: String,
                                  memberIsYou: Bool) -> String? {
        let displayNameChanged = displayName != previousDisplayName
        let avatarChanged = avatarURLString != previousAvatarURLString
        
        switch (displayNameChanged, avatarChanged, memberIsYou) {
        case (true, false, false):
            if let displayName, let previousDisplayName {
                return L10n.stateEventDisplayNameChangedFrom(memberID, previousDisplayName, displayName)
            } else if let displayName {
                return L10n.stateEventDisplayNameSet(memberID, displayName)
            } else if let previousDisplayName {
                return L10n.stateEventDisplayNameRemoved(memberID, previousDisplayName)
            } else {
                MXLog.error("The display name changed from nil to nil, filtering the item.")
                return nil
            }
        case (false, true, false):
            // The SDK only sets displayName when it changed, so it's nil here and we need the member's current name.
            return L10n.stateEventAvatarUrlChanged(memberDisplayName)
        case (true, false, true):
            if let displayName, let previousDisplayName {
                return L10n.stateEventDisplayNameChangedFromByYou(previousDisplayName, displayName)
            } else if let displayName {
                return L10n.stateEventDisplayNameSetByYou(displayName)
            } else if let previousDisplayName {
                return L10n.stateEventDisplayNameRemovedByYou(previousDisplayName)
            } else {
                MXLog.error("The display name changed from nil to nil, filtering the item.")
                return nil
            }
        case (false, true, true):
            return L10n.stateEventAvatarUrlChangedByYou
        case (true, true, _):
            // When both have changed, get the string for the display name and tack on that the avatar changed too.
            guard let string = buildProfileChangeString(displayName: displayName,
                                                        previousDisplayName: previousDisplayName,
                                                        avatarURLString: nil,
                                                        previousAvatarURLString: nil,
                                                        memberID: memberID,
                                                        memberDisplayName: memberDisplayName,
                                                        memberIsYou: memberIsYou) else { return nil }
            return string + "\n" + L10n.stateEventAvatarChangedToo
        case (false, false, _):
            MXLog.error("Nothing changed, shouldn't be possible. Filtering the item.")
            return nil
        }
    }
    
    func buildString(for state: OtherState, sender: TimelineItemSender, isOutgoing: Bool, isDM: Bool = false) -> String? {
        let displayName = sender.disambiguatedDisplayName ?? sender.id
        
        // Bipe: a DM has no topic, so it has no line about one (bipe#527).
        if isDM, case .roomTopic = state {
            return nil
        }
        
        // Bipe: a DM says "conversa", never "sala" (bipe#507).
        if isDM, let text = buildDMString(for: state, displayName: displayName, isOutgoing: isOutgoing) {
            return text
        }
        
        // Bipe: grupo, not sala (bipe#508)
        switch state {
        case .roomAvatar(let url):
            switch (url, isOutgoing) {
            case (.some, false):
                return BipeStrings.groupStateEventRoomAvatarChanged(displayName)
            case (nil, false):
                return BipeStrings.groupStateEventRoomAvatarRemoved(displayName)
            case (.some, true):
                return BipeStrings.groupStateEventRoomAvatarChangedByYou
            case (nil, true):
                return BipeStrings.groupStateEventRoomAvatarRemovedByYou
            }
        case .roomCreate:
            if isDM { // Bipe: a DM says "conversa" (bipe#508)
                return isOutgoing ? BipeStrings.dmCreatedByYou : BipeStrings.dmCreated(displayName)
            }
            return isOutgoing ? BipeStrings.groupStateEventRoomCreatedByYou : BipeStrings.groupStateEventRoomCreated(displayName)
        case .roomEncryption:
            return L10n.commonEncryptionEnabled
        case .roomName(let name):
            switch (name, isOutgoing) {
            case (.some(let name), false):
                return BipeStrings.groupStateEventRoomNameChanged(displayName, name)
            case (nil, false):
                return BipeStrings.groupStateEventRoomNameRemoved(displayName)
            case (.some(let name), true):
                return BipeStrings.groupStateEventRoomNameChangedByYou(name)
            case (nil, true):
                return BipeStrings.groupStateEventRoomNameRemovedByYou
            }
        case .roomThirdPartyInvite(let displayName):
            guard let displayName else {
                MXLog.error("roomThirdPartyInvite undisplayable due to missing name.")
                return nil
            }
            
            if isOutgoing {
                return BipeStrings.groupStateEventRoomThirdPartyInviteByYou(displayName)
            } else {
                return BipeStrings.groupStateEventRoomThirdPartyInvite(displayName, displayName)
            }
        case .roomTopic(let topic): // Bipe: "descrição", because "tópico" is a thread (bipe#527)
            switch (topic, isOutgoing) {
            case (.some(let topic), false) where !topic.isBlank:
                return BipeStrings.groupStateEventRoomTopicChanged(displayName, topic)
            case (_, false):
                return BipeStrings.groupStateEventRoomTopicRemoved(displayName)
            case (.some(let topic), true) where !topic.isBlank:
                return BipeStrings.groupStateEventRoomTopicChangedByYou(topic)
            case (_, true):
                return BipeStrings.groupStateEventRoomTopicRemovedByYou
            }
        case .roomPinnedEvents(let change):
            switch change {
            case .added:
                return isOutgoing ? L10n.stateEventRoomPinnedEventsPinnedByYou : L10n.stateEventRoomPinnedEventsPinned(displayName)
            case .changed:
                return isOutgoing ? L10n.stateEventRoomPinnedEventsChangedByYou : L10n.stateEventRoomPinnedEventsChanged(displayName)
            case .removed:
                return isOutgoing ? L10n.stateEventRoomPinnedEventsUnpinnedByYou : L10n.stateEventRoomPinnedEventsUnpinned(displayName)
            }
        case .roomPowerLevels: // Long term we might show only the user changes, but we need an SDK filter to fix read receipts in that case.
            break
        case .policyRuleRoom, .policyRuleServer, .policyRuleUser: // No strings available.
            break
        case .roomCanonicalAlias: // Doesn't provide the alias.
            break
        case .roomGuestAccess, .roomHistoryVisibility: // Doesn't provide information about the change.
            break
        case .roomJoinRules: // Doesn't provide information about the change.
            break
        case .roomServerAcl: // Doesn't provide information about the change.
            break
        case .roomTombstone: // Handle as a virtual timeline item with a link to the upgraded room.
            break
        case .spaceChild, .spaceParent: // Users shouldn't see the timeline of a Space.
            break
        case .custom: // Won't provide actionable information to the user.
            break
        }
        
        MXLog.verbose("Filtering timeline item for state: \(state)")
        return nil
    }
    
    /// Bipe: the DM variants of the state lines that say "sala" upstream (bipe#507). `nil` means use the upstream line.
    private func buildDMString(for state: OtherState, displayName: String, isOutgoing: Bool) -> String? {
        switch state {
        case .roomAvatar(let url):
            if url != nil {
                return isOutgoing ? BipeStrings.dmAvatarChangedByYou : BipeStrings.dmAvatarChanged(displayName)
            }
            return isOutgoing ? BipeStrings.dmAvatarRemovedByYou : BipeStrings.dmAvatarRemoved(displayName)
        case .roomName(let name):
            if let name {
                return isOutgoing ? BipeStrings.dmNameChangedByYou(name) : BipeStrings.dmNameChanged(displayName, name)
            }
            return isOutgoing ? BipeStrings.dmNameRemovedByYou : BipeStrings.dmNameRemoved(displayName)
        case .roomThirdPartyInvite(let invitee):
            guard let invitee else { return nil }
            return isOutgoing ? BipeStrings.dmThirdPartyInviteByYou(invitee) : BipeStrings.dmThirdPartyInvite(displayName, invitee)
        default:
            return nil
        }
    }
}
