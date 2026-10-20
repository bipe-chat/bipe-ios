//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import SwiftUI

/// The screen shown at the beginning of the onboarding flow.
struct AuthenticationStartScreen: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @Bindable var context: AuthenticationStartScreenViewModel.Context
    
    var body: some View {
        if case let .welcomeBack(classicAppAccount) = context.viewState.classicAppMode,
           classicAppAccount.state.isServerSupported != false {
            AuthenticationClassicAppAccountView(context: context, classicAppAccount: classicAppAccount)
        } else {
            standardContent
        }
    }
    
    var standardContent: some View {
        // This view uses a GeometryReader instead of FullscreenDialog so its content takes the full
        // height available (after taking the buttons out of the equation) in order for the logo
        // and title to appear vertically centred and equally spaced within this content area.
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: UIConstants.spacerHeight(in: geometry))
                    
                    content
                        .frame(width: geometry.size.width)
                        .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.hidden)
                    
                    buttons
                        .frame(width: geometry.size.width)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 16)
                        .padding(.top, 8)
                    
                    Spacer()
                        .frame(height: UIConstants.spacerHeight(in: geometry))
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            // Bipe: açaí background instead of Element's launch artwork.
            BipeWelcomeBackground()
        }
        .navigationBarHidden(context.viewState.classicAppMode == nil)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .introspect(.window, on: .supportedVersions) { window in
            context.send(viewAction: .updateWindow(window))
        }
    }
    
    var content: some View {
        // Bipe: logo, promise and value points instead of Element's logo and welcome text.
        BipeWelcomeView(invitedBy: bipeInvitedBy)
    }
    
    /// "@ana te chamou para o Bipe." when a link brought an invite and the preview named the inviter.
    private var bipeInvitedBy: String? {
        guard context.viewState.bipeStart == .invited, let handle = context.viewState.bipeInviterHandle else { return nil }
        return BipeStrings.onboardingInvitedBy("@\(handle)")
    }
    
    /// The main action buttons.
    var buttons: some View {
        VStack(spacing: 16) {
            if let bipeStart = context.viewState.bipeStart {
                bipeButtons(bipeStart)
            } else {
                elementButtons
            }
            
            versionText
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
                .onTapGesture(count: 7) {
                    context.send(viewAction: .reportProblem)
                }
                .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.appVersion)
                .overlay(alignment: .trailing) {
                    developerOptionsButton
                        .scaledOffset(x: 32, y: -0.5, relativeTo: .compound.bodySM)
                }
                .padding(.top, 16)
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 128 : 24)
        .readableFrame()
    }
    
    /// Bipe: one filled button and its text buttons, from bipe-shared `registries/onboarding.json` (bipe#415).
    @ViewBuilder
    private func bipeButtons(_ start: BipeOnboardingStart) -> some View {
        if start != .invited, context.viewState.bipeOffersPasteInvite {
            bipePasteInvite
        }
        
        Button(start.primary.title) { context.send(viewAction: .bipe(start.primary.target)) }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signIn)
        
        ForEach(start.text, id: \.titleKey) { button in
            Button(button.title) { context.send(viewAction: .bipe(button.target)) }
                .buttonStyle(.compound(.tertiary))
        }
    }
    
    /// bipe#197: the invite page copied the invite link before the install. PasteButton reads it without the paste alert.
    private var bipePasteInvite: some View {
        VStack(spacing: 8) {
            Text(context.viewState.bipePastedNoInvite ? BipeStrings.onboardingPasteInviteNone : BipeStrings.onboardingPasteInviteHint)
                .font(.compound.bodyMD)
                .foregroundStyle(context.viewState.bipePastedNoInvite ? .compound.textCriticalPrimary : .compound.textSecondary)
                .multilineTextAlignment(.center)
            
            PasteButton(payloadType: String.self) { strings in
                context.send(viewAction: .bipePaste(strings))
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var elementButtons: some View {
        if context.viewState.showQRCodeLoginButton {
            Button { context.send(viewAction: .loginWithQR) } label: {
                Label(L10n.screenOnboardingSignInWithQrCode, icon: \.qrCode)
            }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signInWithQr)
        }
        
        Button { context.send(viewAction: .login) } label: {
            Text(context.viewState.loginButtonTitle)
        }
        .buttonStyle(.compound(.primary))
        .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signIn)
        
        if context.viewState.showCreateAccountButton {
            Button { context.send(viewAction: .register) } label: {
                Text(L10n.screenCreateAccountTitle)
            }
            .buttonStyle(.compound(.tertiary))
        }
    }
    
    var versionText: Text {
        // Let's not deal with snapshotting a changing version string.
        let shortVersionString = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        return Text(L10n.screenOnboardingAppVersion(shortVersionString))
    }
    
    @ViewBuilder
    var developerOptionsButton: some View {
        if AppSettings.appBuildType != .release, !ProcessInfo.isRunningTests {
            Button { context.send(viewAction: .developerOptions) } label: {
                CompoundIcon(\.code)
                    .foregroundStyle(.compound.iconSecondary)
            }
            .accessibilityLabel(L10n.commonDeveloperOptions)
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if case let .otherOptions(classicAppAccount) = context.viewState.classicAppMode {
                ToolbarButton(role: .close) {
                    context.send(viewAction: .closeOtherOptions(classicAppAccount))
                }
            }
        }
    }
}

// MARK: - Previews

struct AuthenticationStartScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let provisionedViewModel = makeViewModel(provisionedServerName: "example.com")
    static let classicAppViewModel = makeViewModel(hasClassicAppAccount: true)
    
    static var previews: some View {
        AuthenticationStartScreen(context: viewModel.context)
            .previewDisplayName("Default")
        AuthenticationStartScreen(context: provisionedViewModel.context)
            .previewDisplayName("Provisioned")
        
        ElementNavigationStack {
            AuthenticationStartScreen(context: classicAppViewModel.context)
        }
        .previewDisplayName("Classic App")
    }
    
    static func makeViewModel(provisionedServerName: String? = nil, hasClassicAppAccount: Bool = false) -> AuthenticationStartScreenViewModel {
        let classicAppAccount = ClassicAppAccount.mockDan
        classicAppAccount.state.isServerSupported = true
        classicAppAccount.state.availableSecrets = .complete
        let classicAppManager: ClassicAppManagerMock? = hasClassicAppAccount ? .init(.init(accounts: [classicAppAccount])) : nil
        
        return AuthenticationStartScreenViewModel(authenticationService: AuthenticationService.mock(classicAppManager: classicAppManager),
                                                  provisioningParameters: provisionedServerName.map { .init(accountProvider: $0, loginHint: nil) },
                                                  isBugReportServiceEnabled: true,
                                                  appMediator: AppMediatorMock(),
                                                  appSettings: .volatile(),
                                                  mediaProvider: MediaProviderMock(.init()),
                                                  userIndicatorController: UserIndicatorControllerMock())
    }
}
