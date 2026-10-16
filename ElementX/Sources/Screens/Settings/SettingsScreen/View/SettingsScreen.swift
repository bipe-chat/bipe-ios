//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import BipeKit
import SwiftUI

struct SettingsScreen: View {
    @Bindable var context: SettingsScreenViewModel.Context
    
    // Bipe: the Você tab by the user's question (ADR 0112). The modal settings root shows the same structure.
    // Element's "Account settings" and "App settings" sections, the status row and Add account are gone;
    // their rows live in the groups (`BipeSettingsGroupScreen`).
    var body: some View {
        Form {
            BipeProfileHeaderSection(userProfile: context.viewState.userProfile,
                                     handle: context.viewState.bipeHandle,
                                     mediaProvider: context.mediaProvider) {
                context.send(viewAction: .bipeGroup(.profile))
            }
            
            BipeSelfChatSection { context.send(viewAction: .bipeSelfChat) }
            
            if let trustProfile = context.viewState.bipeTrustProfile {
                BipeTrustProfileSection(profile: trustProfile) { context.send(viewAction: $0) }
            }
            
            if context.viewState.showBipeHandle {
                Section {
                    // Bipe: invites and contacts share one screen.
                    ListRow(label: .default(title: BipeStrings.invitesTitle,
                                            icon: \.userAdd),
                            kind: .navigationLink {
                                context.send(viewAction: .bipeContacts)
                            })
                }
            }
            
            BipeSettingsGroupsSection(whoCanMessage: context.viewState.bipeWhoCanMessage,
                                      waysBack: context.viewState.bipeWaysBack,
                                      notificationsOn: context.viewState.bipeNotificationsOn) { group in
                context.send(viewAction: .bipeGroup(group))
            }
            
            developerSection
        }
        .compoundList()
        // Bipe: reloads the handle on first show and after returning from a pushed screen.
        .onAppear { context.send(viewAction: .bipeLoadHandle) }
        .navigationTitle(context.viewState.bipeIsInTab ? BipeStrings.tabYou : L10n.commonSettings)
        .navigationBarTitleDisplayMode(context.viewState.bipeIsInTab ? .large : .inline)
        .toolbarVisibility(context.viewState.navigationBarVisibility, for: .navigationBar)
        .toolbar { if !context.viewState.bipeIsInTab { toolbar } }
    }
    
    /// Developer options stay behind 7 taps on the version.
    private var developerSection: some View {
        Section {
            if context.viewState.showDeveloperOptions {
                ListRow(label: .default(title: L10n.commonDeveloperOptions,
                                        icon: \.code),
                        kind: .navigationLink {
                            context.send(viewAction: .developerOptions)
                        })
                        .accessibilityIdentifier(A11yIdentifiers.settingsScreen.developerOptions)
            }
        } footer: {
            versionSection
        }
    }
    
    /// Bipe: the version only. A long press copies the device ID (ADR 0112).
    private var versionSection: some View {
        versionText
            .frame(maxWidth: .infinity)
            .compoundListSectionFooter()
            .padding(.top, 24)
            .onTapGesture(count: 7) {
                context.send(viewAction: .enableDeveloperOptions)
            }
            .onLongPressGesture {
                context.send(viewAction: .bipeCopyDeviceID)
            }
    }
    
    private var versionText: Text {
        // Let's not snapshot a changing version string.
        let shortVersion = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        let version = ProcessInfo.isRunningTests ? "1" : InfoPlistReader.main.bundleVersion
        return Text(BipeStrings.helpVersion("\(shortVersion) (\(version))"))
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ToolbarButton(role: .close) { context.send(viewAction: .close) }
                .accessibilityIdentifier(A11yIdentifiers.settingsScreen.done)
        }
    }
}

extension AppAppearance {
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
        .frame(height: 1300)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Default")
        
        ElementNavigationStack {
            SettingsScreen(context: bugReportDisabledViewModel.context)
        }
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
