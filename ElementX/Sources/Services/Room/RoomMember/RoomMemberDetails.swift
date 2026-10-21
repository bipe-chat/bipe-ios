//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

nonisolated struct RoomMemberDetails: Identifiable, Hashable {
    let id: String
    let name: String?
    let avatarURL: URL?
    let status: UserStatus
    
    let permalink: URL?
    
    var isInvited: Bool
    var isIgnored: Bool
    var isBanned: Bool
    var isActive: Bool
    
    let role: RoomRole
    let powerLevel: RoomPowerLevel
    
    func matches(searchQuery: String) -> Bool {
        guard !searchQuery.isEmpty else { return true }
        return id.localizedStandardContains(searchQuery) || name?.localizedStandardContains(searchQuery) == true
    }
}

nonisolated extension RoomMemberDetails {
    init(withProxy proxy: RoomMemberProxyProtocol) {
        id = proxy.userID
        name = proxy.displayName
        avatarURL = proxy.avatarURL
        status = proxy.status
        permalink = proxy.permalink
        isActive = proxy.isActive
        isInvited = proxy.membership == .invite
        isIgnored = proxy.isIgnored
        isBanned = proxy.membership == .ban
        role = proxy.role
        powerLevel = proxy.powerLevel
    }
    
    /// Bipe (bipe#524): the other person in a DM when the member list has no entry for them, e.g. after they left.
    init(withHero hero: RoomHero, isIgnored: Bool) {
        let profile = UserProfile(rustRoomHero: hero)
        id = profile.id
        name = profile.displayName
        avatarURL = profile.avatarURL
        status = profile.status
        permalink = try? URL(string: matrixToUserPermalink(userId: profile.id))
        isActive = false
        isInvited = false
        self.isIgnored = isIgnored
        isBanned = false
        role = .user
        powerLevel = .value(0)
    }
}
