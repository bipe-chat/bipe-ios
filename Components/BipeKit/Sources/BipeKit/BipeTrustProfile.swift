//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// The "Perfil de confiança" ladder from bipe/docs/trust-levels.md. Only the account owner sees it.
/// Step 2 is computed here from the Matrix profile and the handle; steps 3 to 5 wait for the API.
/// Android mirrors the same step and item ids.
public nonisolated struct BipeTrustProfile: Sendable, Equatable {
    public enum StepID: String, Sendable, CaseIterable {
        case account
        case profile
        case email
        case pix
        case govbr
    }
    
    public enum Status: String, Sendable {
        case done
        case todo
        case comingSoon = "coming_soon"
    }
    
    /// The parts of step 2, in the order the card shows them.
    public enum ProfileItem: String, Sendable, CaseIterable {
        case displayName = "display_name"
        case handle
        case avatar
    }
    
    public struct Step: Sendable, Equatable, Identifiable {
        public let id: StepID
        public let status: Status
    }
    
    public let steps: [Step]
    /// Empty when step 2 is done.
    public let missingProfileItems: [ProfileItem]
    
    public var completedCount: Int {
        steps.filter { $0.status == .done }.count
    }
    
    public var totalCount: Int {
        steps.count
    }
    
    public var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }
    
    public init(displayName: String?, hasAvatar: Bool, handle: String?) {
        var missing: [ProfileItem] = []
        if displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            missing.append(.displayName)
        }
        if handle?.isEmpty ?? true {
            missing.append(.handle)
        }
        if !hasAvatar {
            missing.append(.avatar)
        }
        missingProfileItems = missing
        
        steps = [Step(id: .account, status: .done),
                 Step(id: .profile, status: missing.isEmpty ? .done : .todo),
                 Step(id: .email, status: .comingSoon),
                 Step(id: .pix, status: .comingSoon),
                 Step(id: .govbr, status: .comingSoon)]
    }
}
