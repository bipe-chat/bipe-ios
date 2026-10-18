//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import SwiftUI

enum AuthenticationStartScreenViewModelAction: Equatable {
    case loginWithQR
    case login
    case register
    case bipeSignup(startsWithInviteCode: Bool)
    
    case loginDirectlyWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

struct AuthenticationStartScreenViewState: BindableState {
    /// The presentation anchor used for OAuth authentication.
    var window: UIWindow?
    
    let serverNameOrBaseURL: String?
    let showCreateAccountButton: Bool
    let showQRCodeLoginButton: Bool
    
    enum ClassicAppMode { case welcomeBack(ClassicAppAccount), otherOptions(ClassicAppAccount) }
    var classicAppMode: ClassicAppMode?
    
    let hideBrandChrome: Bool
    
    var bindings = AuthenticationStartScreenViewStateBindings()
    
    /// Bipe: "Get back into your account" instead of "Sign in to …".
    var bipeLoginButtonTitle: String?
    /// Bipe: the start screen variant from bipe-shared `registries/onboarding.json` (bipe#415). `nil` outside Bipe sign-up.
    var bipeStart: BipeOnboardingStart?
    /// Bipe: the inviter's handle from the invite preview, without @.
    var bipeInviterHandle: String?
    
    var loginButtonTitle: String {
        if let bipeLoginButtonTitle {
            bipeLoginButtonTitle
        } else if let serverNameOrBaseURL {
            L10n.screenOnboardingSignInTo(serverNameOrBaseURL)
        } else if showQRCodeLoginButton {
            L10n.screenOnboardingSignInManually
        } else {
            L10n.actionContinue
        }
    }
}

struct AuthenticationStartScreenViewStateBindings {
    var alertInfo: AlertInfo<AuthenticationStartScreenAlertType>?
    var showClassicAppBackupInstructions = false
}

enum AuthenticationStartScreenAlertType {
    case genericError
}

enum AuthenticationStartScreenViewAction {
    /// Updates the window used as the OAuth presentation anchor.
    case updateWindow(UIWindow)
    case developerOptions
    case reportProblem
    
    case loginWithQR
    case login
    case register
    /// Bipe: a start screen button, by its target in the registry.
    case bipe(BipeOnboardingTarget)
    
    case continueWithClassic(ClassicAppAccount)
    case otherOptions(ClassicAppAccount)
    case closeOtherOptions(ClassicAppAccount)
    case openClassicApp
}
