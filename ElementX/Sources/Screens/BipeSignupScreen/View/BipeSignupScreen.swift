//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

/// One question per screen (bipe#196): the invite when there is none (ADR 0072), the name, the PIN, the PIN again.
struct BipeSignupScreen: View {
    @Bindable var context: BipeSignupScreenViewModel.Context

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                step
            }
            .readableFrame()
            .padding(.horizontal, 16)
            .padding(.top, UIConstants.iconTopPaddingToNavigationBar)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(BipeStrings.signupTitle)
        .navigationBarBackButtonHidden(context.viewState.previousStep != nil)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .onChange(of: context.inviteCode) { context.send(viewAction: .inviteCodeChanged) }
        .onChange(of: context.pin) { context.send(viewAction: .pinChanged) }
        .onChange(of: context.pinConfirmation) { context.send(viewAction: .pinConfirmationChanged) }
        .onChange(of: context.viewState.step) { isFieldFocused = true }
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: headerIcon)
                .padding(.bottom, 8)

            Text(title)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.compound.bodyMD)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.compound.textSecondary)
            }
        }
    }

    private var headerIcon: KeyPath<CompoundIcons, Image> {
        switch context.viewState.step {
        case .invite: \.email
        case .name: \.userProfileSolid
        case .pin, .pinConfirmation: \.lockSolid
        }
    }

    private var title: String {
        switch context.viewState.step {
        case .invite: BipeStrings.signupInviteTitle
        case .name: BipeStrings.signupNameTitle
        case .pin: BipeStrings.pinCreateTitle
        case .pinConfirmation: BipeStrings.pinConfirmTitle
        }
    }

    private var subtitle: String? {
        switch context.viewState.step {
        case .invite: BipeStrings.signupInviteBody
        case .name: context.viewState.inviterHandle.map(BipeStrings.signupInvitedBy)
        case .pin: BipeStrings.pinCreateBody(String(BipeRegistries.pinLength))
        case .pinConfirmation: nil
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var step: some View {
        switch context.viewState.step {
        case .invite: inviteStep
        case .name: nameStep
        case .pin: pinStep
        case .pinConfirmation: pinConfirmationStep
        }
    }

    private var inviteStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(text: $context.inviteCode) { placeholder("XXXX-XXXX-XXXX") }
                .focused($isFieldFocused)
                .textFieldStyle(.compound(labelText: BipeStrings.signupInviteCode,
                                          footerText: context.viewState.inviterHandle.map(BipeStrings.signupInvitedBy) ?? context.viewState.inviteCodeFooter,
                                          state: context.viewState.inviteCodeFooter == nil ? .default : .error))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { context.send(viewAction: .continueFromInvite) }

            // PasteButton reads the clipboard without the system paste prompt. It takes a link or a whole message.
            if context.viewState.inviteCode == nil {
                PasteButton(payloadType: String.self) { strings in
                    guard let code = strings.lazy.compactMap(BipeInviteCode.init).first else { return }
                    context.inviteCode = code.value
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
            }

            Button { context.send(viewAction: .continueFromInvite) } label: {
                Text(L10n.actionContinue)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canContinueFromInvite)
            .padding(.top, 16)

            if context.viewState.showsNoInviteHelp {
                Text(BipeStrings.signupInviteNoneBody)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                Button { context.send(viewAction: .showNoInviteHelp) } label: {
                    Text(BipeStrings.signupInviteNone)
                }
                .buttonStyle(.compound(.tertiary))
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            TextField(text: $context.displayName) { placeholder("") }
                .focused($isFieldFocused)
                .textFieldStyle(.compound(labelText: BipeStrings.signupDisplayName,
                                          footerText: BipeStrings.signupDisplayNameFooter))
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { context.send(viewAction: .continueFromName) }

            Button { context.send(viewAction: .continueFromName) } label: {
                Text(L10n.actionContinue)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canContinueFromName)
        }
    }

    // The PIN is not a password: no password autofill, no saving in a password manager.
    private var pinStep: some View {
        VStack(spacing: 16) {
            PINTextField(pinCode: $context.pin, isSecure: true, maxLength: BipeRegistries.pinLength, size: .small)
                .focused($isFieldFocused)

            if let footer = context.viewState.pinFooter {
                errorText(footer)
            } else {
                hintText(BipeStrings.pinNeverAsked)
            }
        }
    }

    private var pinConfirmationStep: some View {
        VStack(spacing: 16) {
            PINTextField(pinCode: $context.pinConfirmation, isSecure: true, maxLength: BipeRegistries.pinLength, size: .small)
                .focused($isFieldFocused)
                .disabled(context.viewState.isAccountCreated)

            if context.viewState.pinMismatch {
                errorText(BipeStrings.pinMismatch)
            } else {
                hintText(BipeStrings.pinNeverAsked)
            }

            // The account exists but the sign-in failed: try the sign-in again.
            if context.viewState.isAccountCreated {
                Button { context.send(viewAction: .submit) } label: {
                    Text(L10n.actionContinue)
                }
                .buttonStyle(.compound(.primary))
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Helpers

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.previousStep != nil {
                Button { context.send(viewAction: .back) } label: {
                    CompoundIcon(\.chevronLeft)
                }
                .accessibilityLabel(L10n.actionBack)
            }
        }
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.compound.bodyMD)
            .multilineTextAlignment(.center)
            .foregroundColor(.compound.textCriticalPrimary)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.compound.bodyMD)
            .multilineTextAlignment(.center)
            .foregroundColor(.compound.textSecondary)
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundColor(.compound.textSecondary)
    }
}

// MARK: - Previews

struct BipeSignupScreen_Previews: PreviewProvider {
    static let viewModel = BipeSignupScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                     signIn: BipeAccountSignIn(authenticationService: AuthenticationService.mock, appSettings: .volatile()),
                                                     appLockService: nil,
                                                     userIndicatorController: UserIndicatorControllerMock())

    static var previews: some View {
        ElementNavigationStack {
            BipeSignupScreen(context: viewModel.context)
        }
    }
}
