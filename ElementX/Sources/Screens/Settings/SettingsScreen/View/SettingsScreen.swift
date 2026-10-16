//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import BipeKit
import SFSafeSymbols
import SwiftUI

struct SettingsScreen: View {
    @Bindable var context: SettingsScreenViewModel.Context
    @Environment(\.openURL) private var openURL
    @Environment(\.bipeHandleResolver) private var bipeHandleResolver
    
    var body: some View {
        Form {
            if context.viewState.bipeIsInTab {
                BipeSelfChatSection { context.send(viewAction: .bipeSelfChat) }
            }
            
            userSection
            
            if let trustProfile = context.viewState.bipeTrustProfile {
                BipeTrustProfileSection(profile: trustProfile) { context.send(viewAction: $0) }
            }
            
            if context.viewState.showAddAccountButton {
                addAccountSection
            }
            
            accountSettingsSection
            
            signOutSection
            
            appSettingsSection
        }
        .compoundList()
        // Bipe: reloads the handle on first show and after returning from a pushed screen.
        .onAppear { context.send(viewAction: .bipeLoadHandle) }
        .navigationTitle(context.viewState.bipeIsInTab ? BipeStrings.tabYou : L10n.commonSettings)
        .navigationBarTitleDisplayMode(context.viewState.bipeIsInTab ? .large : .inline)
        .toolbarVisibility(context.viewState.navigationBarVisibility, for: .navigationBar)
        .toolbar { if !context.viewState.bipeIsInTab { toolbar } }
        .sheet(isPresented: $context.isPresentingStatusPicker) {
            SettingsScreenUserStatusPickerView { action in
                context.send(viewAction: .userStatus(action))
            }
            .presentationDetents([.medium])
            .presentationBackground(.compound.bgCanvasDefault)
        }
    }
    
    private var userSection: some View {
        Section {
            ListRow(kind: .custom {
                Button {
                    context.send(viewAction: .userDetails)
                } label: {
                    HStack(spacing: 12) {
                        LoadableAvatarImage(url: context.viewState.userProfile.avatarURL,
                                            name: context.viewState.userProfile.displayName,
                                            contentID: context.viewState.userProfile.id,
                                            avatarSize: .user(on: .settings),
                                            mediaProvider: context.mediaProvider)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.viewState.userProfile.displayName ?? "")
                                .font(.compound.headingMD)
                                .foregroundColor(.compound.textPrimary)
                            
                            Text(bipeHandleResolver?.displayText(for: context.viewState.userProfile.id) ?? context.viewState.userProfile.id)
                                .font(.compound.bodySM)
                                .foregroundColor(.compound.textSecondary)
                        }
                        
                        Spacer()
                        
                        ListRowAccessory.navigationLink
                    }
                    .padding(.horizontal, ListRowPadding.horizontal)
                    .padding(.vertical, 8)
                }
            })
            
            if context.viewState.showUserStatusInput {
                SettingsScreenUserStatusRow(mode: context.viewState.userStatusRowMode) { action in
                    context.send(viewAction: .userStatus(action))
                }
            }
        }
    }
    
    private var addAccountSection: some View {
        Section {
            ListRow(label: .default(title: L10n.screenSettingsAddAccount,
                                    icon: \.plus),
                    kind: .navigationLink {
                        context.send(viewAction: .addAccount)
                    })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.addAccount)
        }
    }
    
    private var accountSettingsSection: some View {
        Section {
            if let url = context.viewState.accountProfileURL {
                ListRow(label: .default(title: L10n.actionManageAccountAndDevices,
                                        icon: \.userProfile),
                        kind: .button {
                            context.send(viewAction: .manageAccount(url: url))
                        })
                        .accessibilityIdentifier(A11yIdentifiers.settingsScreen.account)
            }
            
            if context.viewState.showLinkNewDeviceButton {
                ListRow(label: .default(title: L10n.commonLinkNewDevice,
                                        icon: \.devices),
                        kind: .navigationLink {
                            context.send(viewAction: .linkNewDevice)
                        })
            }
            
            ListRow(label: .default(title: L10n.screenNotificationSettingsTitle,
                                    icon: \.notifications),
                    kind: .navigationLink {
                        context.send(viewAction: .notifications)
                    })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.notifications)
            
            switch context.viewState.securitySectionMode {
            case .secureBackup:
                ListRow(label: .default(title: L10n.commonEncryption,
                                        icon: \.key),
                        details: context.viewState.showSecuritySectionBadge ? .icon(securitySectionBadge) : nil,
                        kind: .navigationLink { context.send(viewAction: .secureBackup) })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.secureBackup)
            default:
                EmptyView()
            }
            
            ListRow(label: .default(title: L10n.commonModerationAndSafety,
                                    icon: \.admin),
                    kind: .navigationLink {
                        context.send(viewAction: .moderationAndSafety)
                    })
            
            if context.viewState.isBugReportServiceEnabled {
                ListRow(label: .default(title: L10n.commonReportAProblem,
                                        icon: \.chatProblem),
                        kind: .navigationLink {
                            context.send(viewAction: .reportBug)
                        })
                        .accessibilityIdentifier(A11yIdentifiers.settingsScreen.reportBug)
            }
        } header: {
            Text(L10n.commonAccountSettings)
                .compoundListSectionHeader()
        }
    }
    
    private var signOutSection: some View {
        Section {
            ListRow(label: .action(title: L10n.screenSignoutPreferenceItem,
                                   icon: \.close,
                                   role: .destructive),
                    kind: .button {
                        context.send(viewAction: .logout)
                    })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.logout)
            
            if context.viewState.showAccountDeactivation {
                ListRow(label: .action(title: L10n.actionDeleteAccount,
                                       icon: \.delete,
                                       role: .destructive),
                        kind: .navigationLink {
                            context.send(viewAction: .deactivateAccount)
                        })
            }
        }
    }
    
    private var appSettingsSection: some View {
        Section {
            ListRow(label: .default(title: L10n.commonAppearance,
                                    icon: \.darkMode),
                    kind: .picker(selection: $context.appAppearance,
                                  items: AppAppearance.allCases.map { (title: $0.name, tag: $0) }))
            
            if context.viewState.showBipeHandle {
                ListRow(label: .default(title: BipeStrings.settingsHandle,
                                        icon: \.userProfile),
                        details: .title(context.viewState.bipeHandle.map { "@\($0)" } ?? BipeStrings.settingsHandleNone),
                        kind: .navigationLink {
                            context.send(viewAction: .bipeHandle)
                        })
                
                ListRow(label: .default(title: BipeStrings.settingsPublicProfile,
                                        icon: \.webBrowser),
                        details: context.viewState.bipePublicProfileEnabled.map { .title($0 ? BipeStrings.publicProfileOn : BipeStrings.publicProfileOff) },
                        kind: .navigationLink {
                            context.send(viewAction: .bipePublicProfile)
                        })
                
                ListRow(label: .default(title: BipeStrings.messagingTitle,
                                        icon: \.chat),
                        details: context.viewState.bipeWhoCanMessage.map { .title($0.title) },
                        kind: .navigationLink {
                            context.send(viewAction: .bipeMessaging)
                        })
                
                ListRow(label: .default(title: BipeStrings.invitesTitle,
                                        icon: \.userAdd),
                        kind: .navigationLink {
                            context.send(viewAction: .bipeInvites)
                        })
                
                ListRow(label: .default(title: BipeStrings.contactsTitle,
                                        icon: \.userProfile),
                        kind: .navigationLink {
                            context.send(viewAction: .bipeContacts)
                        })
                
                // Bipe ADR 0057: PIN, recovery email, and the move from a beta password to a PIN.
                ListRow(label: .default(title: BipeStrings.pinChangeTitle,
                                        description: BipeStrings.emailTitle,
                                        icon: \.lock),
                        kind: .navigationLink {
                            context.send(viewAction: .bipeAccount)
                        })
            }
            
            // Bipe: pt-BR / en switch lives in iOS per-app language settings.
            ListRow(label: .default(title: BipeStrings.settingsLanguage,
                                    description: BipeStrings.settingsLanguageFooter,
                                    icon: \.translate),
                    kind: .button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    })
            
            ListRow(label: .default(title: L10n.commonMediaUploadQuality,
                                    icon: \.image),
                    kind: .navigationLink {
                        context.send(viewAction: .mediaUploadQuality)
                    })
            
            ListRow(label: .default(title: L10n.commonScreenLock,
                                    icon: \.lock),
                    kind: .navigationLink {
                        context.send(viewAction: .appLock)
                    })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.screenLock)
            
            ListRow(label: .default(title: L10n.commonLocationSharing,
                                    icon: \.locationPin),
                    kind: .navigationLink {
                        context.send(viewAction: .locationSharing)
                    })
            
            if context.viewState.showAnalyticsSettings {
                ListRow(label: .default(title: L10n.commonAnalytics,
                                        icon: \.chart),
                        kind: .navigationLink {
                            context.send(viewAction: .analytics)
                        })
                        .accessibilityIdentifier(A11yIdentifiers.settingsScreen.analytics)
            }
            
            // Bipe: no Labs entry. Threads and galleries are on by default; "Ask to join" stays off.
            
            ListRow(label: .default(title: L10n.commonAbout,
                                    icon: \.info),
                    kind: .navigationLink {
                        context.send(viewAction: .about)
                    })
                    .accessibilityIdentifier(A11yIdentifiers.settingsScreen.about)
            
            if context.viewState.showDeveloperOptions {
                ListRow(label: .default(title: L10n.commonDeveloperOptions,
                                        icon: \.code),
                        kind: .navigationLink {
                            context.send(viewAction: .developerOptions)
                        })
                        .accessibilityIdentifier(A11yIdentifiers.settingsScreen.developerOptions)
            }
        } header: {
            Text(L10n.commonAppSettings)
                .compoundListSectionHeader()
        } footer: {
            versionSection
        }
    }
    
    private var versionSection: some View {
        VStack(spacing: 0) {
            versionText
                .frame(maxWidth: .infinity)
            
            if let deviceID = context.viewState.deviceID {
                Text(deviceID)
            }
        }
        .compoundListSectionFooter()
        .textSelection(.enabled)
        .padding(.top, 24)
        .onTapGesture(count: 7) {
            context.send(viewAction: .enableDeveloperOptions)
        }
    }
    
    private var versionText: Text {
        // Let's not snapshot a changing version string.
        let shortVersion = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        let version = ProcessInfo.isRunningTests ? "1" : InfoPlistReader.main.bundleVersion
        return Text(L10n.settingsVersionNumber(shortVersion, version))
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ToolbarButton(role: .close) { context.send(viewAction: .close) }
                .accessibilityIdentifier(A11yIdentifiers.settingsScreen.done)
        }
    }
    
    @ViewBuilder
    private var securitySectionBadge: some View {
        if context.viewState.showSecuritySectionBadge {
            BadgeView(size: 10)
        }
    }
}

private extension AppAppearance {
    var name: String {
        switch self {
        case .system:
            L10n.themeSystem
        case .light:
            L10n.themeLight
        case .dark:
            L10n.themeDark
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, *)
struct SettingsScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let bugReportDisabledViewModel = makeViewModel(isBugReportServiceEnabled: false)
    
    static var previews: some View {
        ElementNavigationStack {
            SettingsScreen(context: viewModel.context)
        }
        .snapshotPreferences(expect: viewModel.context.observe(\.viewState.accountProfileURL).map { $0 != nil })
        .frame(height: 1300)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Default")
        
        ElementNavigationStack {
            SettingsScreen(context: bugReportDisabledViewModel.context)
        }
        .snapshotPreferences(expect: bugReportDisabledViewModel.context.observe(\.viewState.accountProfileURL).map { $0 != nil })
        .frame(height: 1250)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Bug report disabled")
    }
    
    static func makeViewModel(isBugReportServiceEnabled: Bool = true) -> SettingsScreenViewModel {
        let userSettings = UserSettings.mock()
        userSettings.app.multiAccountEnabled = true
        userSettings.app.linkNewDeviceEnabled = true
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@alice:example.com",
                                                                                   deviceID: "AAAAAAAAAAA",
                                                                                   displayName: "Alice Liddell",
                                                                                   status: .mockFocussing)),
                                                userSettings: userSettings))
        return SettingsScreenViewModel(userSession: userSession,
                                       isBugReportServiceEnabled: isBugReportServiceEnabled,
                                       isInSecondaryWindow: false,
                                       userIndicatorController: UserIndicatorControllerMock())
    }
}
