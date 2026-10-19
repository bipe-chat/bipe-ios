//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Combine
import Foundation
import Macros
import SwiftUI

nonisolated enum AppBuildType {
    case debug
    case nightly
    case release
    
    static var current: AppBuildType {
        #if DEBUG
        return .debug
        #else
        if InfoPlistReader.main.isNightlyBuild {
            .nightly
        } else {
            .release
        }
        #endif
    }
}

/// Store Element specific app settings.
///
/// State is persisted in `UserDefaults`, which is thread-safe per Apple's documentation, hence `@unchecked`.
final nonisolated class AppSettings: @unchecked Sendable {
    static let suiteName: String = InfoPlistReader.main.appGroupIdentifier
    
    /// UserDefaults to be used on reads and writes.
    private let store: UserDefaultsProtocol
    
    static var appBuildType: AppBuildType {
        AppBuildType.current
    }
    
    func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.reset()
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [AccountProvider],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oAuthRedirectURL: URL,
                  oAuthClientURIPath: String?,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL?,
                  deviceVerificationURL: URL?,
                  chatBackupDetailsURL: URL?,
                  identityPinningViolationDetailsURL: URL?,
                  historySharingDetailsURL: URL?,
                  elementWebHosts: [String],
                  accountProvisioningHost: String,
                  bugReportApplicationID: String,
                  analyticsTermsURL: URL?,
                  mapTilerConfiguration: MapTilerConfiguration) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oAuthRedirectURL = oAuthRedirectURL
        self.oAuthClientURIPath = oAuthClientURIPath
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.elementWebHosts = elementWebHosts
        self.accountProvisioningHost = accountProvisioningHost
        self.bugReportApplicationID = bugReportApplicationID
        self.analyticsTermsURL = analyticsTermsURL
        self.mapTilerConfiguration = RemotePreference(mapTilerConfiguration)
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference
    var lastVersionLaunched: String?
    
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(defaultValue: Set<String>())
    var seenInvites: Set<String>
    
    /// Bipe: the inviter from a personal-invite sign-up, shown once after the first sign-in.
    @UserPreference
    var bipePendingInviterUserID: String?
    
    /// Bipe: the inviter's handle from the invite preview, kept with `bipePendingInviterUserID`.
    @UserPreference
    var bipePendingInviterHandle: String?
    
    /// Bipe (bipe#199, bipe#415): the notification ask after the first sent message ran on this device. It shows once.
    @UserPreference(defaultValue: false)
    var bipeHasAskedNotifications: Bool
    
    /// Bipe (bipe#200, bipe#415): the "Escolha seu @" card on the chat list was dismissed or used. It shows no more.
    @UserPreference(defaultValue: false)
    var bipeHasDismissedHandlePrompt: Bool
    
    /// Bipe (ADR 0117, bipe#386): the id of the last remote banner the person closed. A new id shows again.
    @UserPreference
    var bipeDismissedRemoteBannerID: String?
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(defaultValue: true)
    var hasSeenNewSoundBanner: Bool
    
    /// Defaults to `true` so new users never see it. Developer options arms it for now, an upgrade migration will at launch.
    @UserPreference(defaultValue: true)
    var hasSeenMultiAccountAnnouncement: Bool
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders: [AccountProvider] = [.managed(serverName: "bipe.net.br", baseURL: "https://matrix.bipe.net.br")] // Bipe
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = false // Bipe: own server only (closed federation)
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    var backgroundAppRefreshTaskIdentifier: String {
        InfoPlistReader.main.baseBundleIdentifier + ".background.refresh"
    } // Bipe: derived from the bundle ID
    /// The task identifier used for the search index backfill. Also used in main target's the Info.plist
    var searchBackfillTaskIdentifier: String {
        InfoPlistReader.main.baseBundleIdentifier + ".background.search-backfill"
    } // Bipe: derived from the bundle ID
    
    /// A URL where users can go read more about the app.
    private(set) var websiteURL: URL = "https://bipe.chat"
    /// A URL that contains the app's logo that may be used when showing content in a web view.
    private(set) var logoURL: URL = "https://bipe.chat/icone.png"
    /// A URL that contains that app's copyright notice.
    // Bipe: the About page names the steward and the licence (ADR 0040).
    private(set) var copyrightURL: URL = "https://bipe.chat/sobre"
    /// A URL that contains the app's Terms of use.
    private(set) var acceptableUseURL: URL = "https://bipe.chat/termos"
    /// A URL that contains the app's Privacy Policy.
    private(set) var privacyURL: URL = "https://bipe.chat/privacidade"
    // Bipe: no help pages yet, so these are nil and the "Learn more" links they feed are hidden.
    /// A URL where users can go read more about encryption in general.
    private(set) var encryptionURL: URL?
    /// A URL where users can go read more about device verification..
    private(set) var deviceVerificationURL: URL?
    /// A URL where users can go read more about the chat backup.
    private(set) var chatBackupDetailsURL: URL?
    /// A URL where users can go read more about identity pinning violations
    private(set) var identityPinningViolationDetailsURL: URL?
    /// A URL describing how history sharing works
    private(set) var historySharingDetailsURL: URL?
    
    /// Any domains that Element web may be hosted on - used for handling links.
    private(set) var elementWebHosts = ["app.element.io", "staging.element.io", "develop.element.io"]
    /// The domain that account provisioning links will be hosted on - used for handling the links.
    private(set) var accountProvisioningHost = "mobile.element.io"
    /// The App Store URL for Element Pro, shown to the user when a homeserver requires that app.
    /// **Note:** This property isn't overridable as it in unexpected for forks to come across the error (or to even have a "Pro" app).
    let elementProAppStoreURL: URL = "https://apps.apple.com/app/element-pro-for-work/id6502951615"
    
    @UserPreference(defaultValue: AppAppearance.system)
    var appAppearance: AppAppearance
    
    /// Tracks previous servers the user connected to for autocompletion purposes. Entries are made lowercase on write.
    @UserPreference(key: "previousServers", defaultValue: [])
    var previousServers: [String]
    
    var defaultAccountProvider: AccountProvider {
        if allowOtherAccountProviders {
            previousServers.first.map { .generic($0) } ?? accountProviders[0]
        } else {
            accountProviders[0]
        }
    }
    
    // MARK: - Security
    
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = false
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 0
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// Bipe: a new app lock PIN is the account PIN (ADR 0057): 8 digits, checked with the shared PIN rule.
    /// Same value as `BipeRegistries.pinLength`; the extensions that compile this file do not link BipeKit.
    let appLockPINCodeLength = 8
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(defaultValue: 0)
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// Any pre-defined static client registrations for OAuth issuers.
    let oAuthStaticRegistrations: [URL: String] = ["https://id.thirdroom.io/realms/thirdroom": "elementx"]
    /// The redirect URL used for OAuth. For the normal case we don't actually need the bundle ID as the web authentication session handles the redirect internally.
    /// However in the case where MAS sends the user to an external app, we need to make sure that the system will open the correct variant of the app (e.g. Nightly).
    private(set) nonisolated(unsafe) var oAuthRedirectURL: URL! = URL(string: "\(InfoPlistReader.main.bundleIdentifier):/oauth/callback") // Bipe: private-use scheme (RFC 8252); MAS requires it to be the reverse of the client URI host.
    /// A path that is appended to `websiteURL` to form the OAuth `clientURI`. MAS uses `clientURI` as the identifier for a specific app, allowing us to
    /// distinguish the various clients we have for Android, iOS and Web from each other.
    /// Intentionally a distinct property so it can be easily overridden without having to manipulate the website URL.
    private(set) var oAuthClientURIPath: String? = "apps/ios"
    
    var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                           redirectURI: oAuthRedirectURL,
                           clientURI: oAuthClientURIPath.map { websiteURL.appending(path: $0) } ?? websiteURL,
                           logoURI: logoURL,
                           tosURI: acceptableUseURL,
                           policyURI: privacyURL,
                           staticRegistrations: oAuthStaticRegistrations.mapKeys { $0.absoluteString })
    }
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    let showCreateAccountButton = true
    
    // MARK: - Notifications
    
    var pusherAppID: String {
        #if DEBUG
        InfoPlistReader.main.baseBundleIdentifier + ".ios.dev"
        #else
        InfoPlistReader.main.baseBundleIdentifier + ".ios.prod"
        #endif
    }
    
    private(set) var pushGatewayBaseURL: URL = "https://push.bipe.net.br" // Bipe: own Sygnal (issue #61); never matrix.org
    var pushGatewayNotifyEndpoint: URL {
        pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify")
    }
    
    /// Bipe API (sign-up, handles). Contract: bipe-shared/api/openapi.yaml.
    private(set) var bipeAPIBaseURL: URL = "https://api.bipe.net.br" // Bipe
    /// Bipe: "Create account" for this provider opens the invite sign-up screen instead of MAS registration.
    private(set) var bipeSignupServerName = "bipe.net.br"
    var usesBipeSignup: Bool {
        defaultAccountProvider.serverNameOrBaseURL == bipeSignupServerName
    }
    
    @UserPreference(defaultValue: true)
    var enableNotifications: Bool
    
    @UserPreference(defaultValue: true)
    var enableInAppNotifications: Bool
    
    @UserPreference(defaultValue: false)
    var hideQuietNotificationAlerts: Bool
    
    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference
    var pusherProfileTag: String?
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference
    var lastNotificationBootTime: TimeInterval?
    
    /// The app icon badge value the app last computed from the SDK's unread notification counts.
    @UserPreference(defaultValue: 0)
    var lastKnownBadgeCount: Int
    
    /// The sound played when delivering noisy notifications. If nil, use the ElementX default
    @UserPreference
    var selectedNotificationTone: NotificationTone?
    
    // MARK: - Logging
    
    @UserPreference(defaultValue: LogLevel.info)
    var logLevel: LogLevel
    
    @UserPreference(defaultValue: Set<TraceLogPack>())
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    let bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> = .init(Secrets.rageshakeURL.map { .url(URL(string: $0)!) } ?? .disabled) // swiftlint:disable:this force_unwrapping
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = "element-x-ios"
    
    // MARK: - Content scanner
    
    /// The base URL of the content scanner server used to scan media before it is downloaded.
    /// `nil` when content scanning is disabled.
    let contentScannerURL: RemotePreference<URL?> = .init(nil)
    
    // MARK: - Encryption
    
    /// Whether the server forbids the use of E2EE: new rooms are created unencrypted and
    /// enabling encryption on existing rooms is not offered.
    let forceDisableE2EE: RemotePreference<Bool> = .init(false)
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Bipe: always `nil`, the app has no analytics (bipe#55).
    let analyticsConfiguration: AnalyticsConfiguration? = nil
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? // Bipe: no analytics
    /// Whether or not there the app is able ask for user consent to enable analytics.
    var canPromptForAnalytics: Bool {
        analyticsConfiguration != nil
    }
    
    /// Whether the user has opted in to send analytics.
    @UserPreference(defaultValue: AnalyticsConsentState.unknown)
    var analyticsConsentState: AnalyticsConsentState
    
    /// Whether a user session has ever been set up on this device. Deliberately not cleared on
    /// logout: it stops the Classic app migration prompt from reappearing when an Element X
    /// user is signed out unexpectedly (invalidated token, corrupted storage, etc).
    @UserPreference(defaultValue: false)
    var hasSignedInBefore: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunNotificationPermissionsOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRequestedLocationAlwaysLocationAuthorization: Bool
    
    @UserPreference(defaultValue: [FrequentlyUsedEmoji]())
    var frequentlyUsedSystemEmojis: [FrequentlyUsedEmoji]
    
    // MARK: - Live Location
    
    @UserPreference(key: "liveLocationSharingTimeoutDatesByRoomID", defaultValue: [String: LiveLocationSession]())
    var liveLocationSharingSessionsByRoomID: [String: LiveLocationSession]
    
    @UserPreference(defaultValue: 10)
    var liveLocationMinimumDistanceUpdate: Int
    
    @UserPreference(defaultValue: false)
    var liveLocationDisclaimerDisplayed: Bool
    
    // MARK: - Home Screen
    
    @UserPreference(defaultValue: true)
    var showAllRoomListActivity: Bool
    
    // MARK: - Room Screen
    
    @UserPreference(defaultValue: AppBuildType.current == .debug)
    var viewSourceEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var optimizeMediaUploads: Bool
    
    @UserPreference(defaultValue: AudioPlaybackSpeed.default)
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed
    
    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = true
    
    // MARK: - Element Call
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    @UserPreference
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    /// The locally-bundled MapTiler configuration.
    static let bundledMapTilerConfiguration = MapTilerConfiguration(baseURL: "https://api.maptiler.com/maps",
                                                                    apiKey: Secrets.mapLibreAPIKey,
                                                                    lightStyleID: "9bc819c8-e627-474a-a348-ec144fe3d810",
                                                                    darkStyleID: "dea61faf-292b-4774-9660-58fcef89a7f3")
    
    /// The MapTiler configuration used to build map URLs, which defaults to the bundled one.
    private(set) var mapTilerConfiguration = RemotePreference(AppSettings.bundledMapTilerConfiguration)
    
    // MARK: - Presence
    
    @UserPreference(defaultValue: true)
    var sharePresence: Bool
    
    // MARK: - Feature Flags
    
    /// Others
    @UserPreference(defaultValue: false)
    var fuzzyRoomListSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var lowPriorityFilterEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var mentionsFilterEnabled: Bool
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    /// Bipe: on by default, so a server-added device never receives room keys (bipe docs/security.md, E2EE rules).
    @UserPreference(defaultValue: true)
    var enableOnlySignedDeviceIsolationMode: Bool
    
    @UserPreference(defaultValue: false)
    var knockingEnabled: Bool
    
    /// Bipe: threads are on for everyone. The V2 key drops any old Labs opt-out.
    @UserPreference(key: "threadsEnabledV2", defaultValue: true)
    var threadsEnabled: Bool
    
    /// Bipe: reads the old Labs key. False means the event cache was built without threads and needs one rebuild.
    @UserPreference(key: "threadsEnabled", defaultValue: false)
    var isEventCacheBuiltWithThreads: Bool
    
    @UserPreference(defaultValue: false)
    var messageMultiSelectEnabled: Bool
    
    @UserPreference(key: "globalSearchEnabledV2", defaultValue: true)
    var globalSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var focusEventOnNotificationTap: Bool
    
    @UserPreference(defaultValue: false)
    var linkPreviewsEnabled: Bool
    
    /// Enables *sending* gallery messages (multiple media in a single message).
    /// Received galleries are always rendered regardless of this flag.
    /// Bipe: on for everyone. The V2 key drops any old Labs opt-out.
    @UserPreference(key: "galleryEnabledV2", defaultValue: true)
    var galleryEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var jumpToReadMarkerEnabled: Bool
    
    /// Bipe: Settings > Linked devices > Link a computer (ADR 0116). On for everyone; the new key drops an old opt-out.
    @UserPreference(key: "bipeLinkNewDeviceEnabled", defaultValue: true)
    var linkNewDeviceEnabled: Bool
    
    @UserPreference(key: "clientPausingAndResumingEnabledV2", defaultValue: false, volatile: true)
    var clientPausingAndResumingEnabled: Bool
    
    @UserPreference(defaultValue: AppBuildType.current != .release)
    var developerOptionsEnabled: Bool
    
    /// Runs calls through the native matrix-rust-rtc stack instead of the Element Call web view.
    @UserPreference(defaultValue: false)
    var nativeCallEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var multiAccountEnabled: Bool
    
    init(store: UserDefaultsProtocol) {
        self.store = store
    }
    
    func userSettings(for userID: String) -> UserSettings {
        UserSettings(appSettings: self, accountSettings: .init(userID: userID, store: store))
    }
    
    static func volatile() -> AppSettings {
        AppSettings(store: VolatileUserDefaults())
    }
}
