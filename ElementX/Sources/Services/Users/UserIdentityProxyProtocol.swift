//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

nonisolated enum UserIdentityVerificationState {
    case notVerified
    case verified
    case verificationViolation
}

// sourcery: AutoMockable
nonisolated protocol UserIdentityProxyProtocol: Sendable {
    var verificationState: UserIdentityVerificationState { get }
    /// Bipe: the cross-signing master key (unpadded base64). Company badges bind to it (bipe#252).
    var masterKey: String? { get }
}
