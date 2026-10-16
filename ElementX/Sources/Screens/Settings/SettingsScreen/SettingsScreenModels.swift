//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import SwiftUI

enum SettingsScreenViewModelAction {
    case close
    
    case userDetails
    case userStatusEmojiPicker(EmojiPickerScreenContinuation)
    
    case addAccount
    
    case manageAccount(url: URL)
    case linkNewDevice
    case notifications
    case secureBackup
    case moderationAndSafety
    case reportBug
    
    case logout
    case deactivateAccount
    
    case mediaUploadQuality
    case appLock
    case locationSharing
    case analytics
    case labs
    case about
    
    case developerOptions
    
    case bipeHandle
    case bipePublicProfile
    case bipeMessaging
    case bipeContacts
    case bipeSelfChat
    case bipeAccount
    /// Bipe: a settings group row under "Configurações" (ADR 0112).
    case bipeGroup(BipeSettingsGroup)
}

enum SettingsScreenSecuritySectionMode {
    case none
    case secureBackup
}

struct SettingsScreenViewState: BindableState {
    var deviceID: String?
    var userProfile: UserProfile
    var showUserStatusInput = false
    var showLinkNewDeviceButton: Bool
    var showAddAccountButton: Bool
    var accountProfileURL: URL?
    var showAccountDeactivation: Bool
    var showDeveloperOptions: Bool
    /// Bipe: the username row (Bipe accounts only) and the current handle.
    var showBipeHandle = false
    var bipeHandle: String?
    /// Bipe: "Quem pode me mandar mensagem". Same visibility as the username row.
    var bipeWhoCanMessage: BipeWhoCanMessage?
    /// Bipe: the ways back to the account, the subtitle of "Sua conta". `nil` until loaded.
    var bipeWaysBack: BipeWaysBack?
    /// Bipe: notifications on this phone, the subtitle of "Notificações". `nil` until loaded.
    var bipeNotificationsOn: Bool?
    
    /// Bipe: the "Perfil de confiança" card. Same visibility as the username row.
    var bipeTrustProfile: BipeTrustProfile? {
        guard showBipeHandle else { return nil }
        return BipeTrustProfile(displayName: userProfile.displayName,
                                   hasAvatar: userProfile.avatarURL != nil,
                                   handle: bipeHandle)
    }
    
    var securitySectionMode = SettingsScreenSecuritySectionMode.none
    var showSecuritySectionBadge = false
    
    let showAnalyticsSettings: Bool
    
    let isBugReportServiceEnabled: Bool
    
    let navigationBarVisibility: Visibility
    /// Bipe: the screen is the root of the Você tab (ADR 0053), not a sheet.
    var bipeIsInTab = false
    
    var bindings: SettingsScreenViewStateBindings
    
    var userStatusRowMode: SettingsScreenUserStatusRow.Mode {
        if bindings.isShowingCustomStatusField {
            .customStatusInput(emoji: bindings.customStatusEmoji)
        } else if let displayedStatus = userProfile.status.displayed {
            .showingStatus(displayedStatus)
        } else {
            .pickStatusButton
        }
    }
}

struct SettingsScreenViewStateBindings {
    private let userSettings: UserSettings
    
    var isPresentingStatusPicker = false
    var customStatusEmoji: Character = "😄"
    var isShowingCustomStatusField = false {
        didSet {
            if !isShowingCustomStatusField {
                customStatusEmoji = "😄" // Reset the emoji.
            }
        }
    }
    
    var isPresentingAccountDeactivationConfirmation = false
    
    var appAppearance: AppAppearance {
        get { userSettings.app.appAppearance }
        set { userSettings.app.appAppearance = newValue }
    }
    
    init(userSettings: UserSettings) {
        self.userSettings = userSettings
    }
}

enum SettingsScreenViewAction {
    case close
    
    case userDetails
    case userStatus(UserStatusAction)
    
    case addAccount
    
    case manageAccount(url: URL)
    case linkNewDevice
    case notifications
    case secureBackup
    case moderationAndSafety
    case reportBug
    
    case logout
    case deactivateAccount
    
    case mediaUploadQuality
    case appLock
    case locationSharing
    case analytics
    case labs
    case about
    
    case enableDeveloperOptions
    case developerOptions
    
    case bipeHandle
    case bipePublicProfile
    case bipeMessaging
    case bipeLoadHandle
    case bipeContacts
    case bipeSelfChat
    case bipeAccount
    case bipeGroup(BipeSettingsGroup)
    /// Bipe: a long press on the version copies the device ID (ADR 0112).
    case bipeCopyDeviceID
    
    enum UserStatusAction {
        /// Show status picker sheet to select a preset status.
        case pickStatus
        /// Dismiss the picker sheet and show the custom status input.
        case customStatus
        /// Show the emoji picker to select the emoji for the custom status.
        case pickCustomEmoji
        /// Set the user's status to the provided value.
        case set(UserStatus.Raw)
        /// Clears the user's currently displayed status.
        case clear
        /// Cancel user status picking/input.
        case cancel
    }
}
