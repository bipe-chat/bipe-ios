//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import BipeKit
import SwiftUI

struct BipeSignupScreen: View {
    @Bindable var context: BipeSignupScreenViewModel.Context

    private enum Field: Hashable {
        case displayName, handle, email, pin, pinConfirmation, inviteCode
    }

    @FocusState private var focusedField: Field?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, UIConstants.titleTopPaddingToNavigationBar)
                    .padding(.bottom, 32)

                switch context.viewState.step {
                case .form: formStep
                case .pin: pinStep
                case .fallback: fallbackStep
                }
            }
            .readableFrame()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(BipeStrings.signupTitle)
        .navigationBarBackButtonHidden(context.viewState.step != .form)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .onChange(of: context.handle) { context.send(viewAction: .handleChanged) }
        .onChange(of: context.inviteCode) { context.send(viewAction: .inviteCodeChanged) }
        .onChange(of: context.email) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.pin) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.pinConfirmation) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.viewState.step) { _, step in
            focusedField = switch step {
            case .form: nil
            case .pin: .pin
            case .fallback: nil
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if context.viewState.step != .form {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    context.send(viewAction: .back)
                } label: {
                    CompoundIcon(\.chevronLeft)
                }
                .accessibilityLabel(L10n.actionBack)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: headerIcon)
                .padding(.bottom, 8)

            if let headerTitle {
                Text(headerTitle)
                    .font(.compound.headingMDBold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.compound.textPrimary)
            }

            Text(headerBody)
                .font(.compound.bodyLG)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
        }
    }

    private var headerIcon: KeyPath<CompoundIcons, Image> {
        switch context.viewState.step {
        case .form: \.userProfileSolid
        case .pin: \.lockSolid
        case .fallback: \.keySolid
        }
    }

    private var headerTitle: String? {
        switch context.viewState.step {
        case .form: nil
        case .pin: BipeStrings.pinCreateTitle
        case .fallback: BipeStrings.fallbackTitle
        }
    }

    private var headerBody: String {
        switch context.viewState.step {
        case .form: context.viewState.inviterHandle.map(BipeStrings.signupInvitedBy) ?? BipeStrings.signupDeviceHeader
        case .pin: BipeStrings.pinCreateBody(String(BipeRegistries.pinLength))
        case .fallback: BipeStrings.fallbackBody
        }
    }

    // MARK: Form

    private var formStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                TextField(text: $context.displayName) { placeholder("") }
                    .focused($focusedField, equals: .displayName)
                    .textFieldStyle(.compound(labelText: BipeStrings.signupDisplayName,
                                              footerText: BipeStrings.signupDisplayNameFooter))
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .handle }

                TextField(text: $context.handle) { placeholder(BipeStrings.handlePlaceholder) }
                    .focused($focusedField, equals: .handle)
                    .textFieldStyle(.compound(labelText: BipeStrings.signupHandle,
                                              footerText: context.viewState.handleFooter,
                                              state: context.viewState.handleFieldState))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .inviteCode }

                inviteCodeField

                emailField
                    .submitLabel(.continue)
                    .onSubmit(continueStep)
            }
            .disabled(context.viewState.isAccountCreated)

            VStack(spacing: 20) {
                termsCheckbox
                    .disabled(context.viewState.isAccountCreated)

                Button(L10n.actionContinue, action: continueStep)
                    .buttonStyle(.compound(.primary))
                    .disabled(!context.viewState.canContinueForm)
            }
        }
    }

    /// Clickwrap (ADR 0113). Only the box toggles: a tap gesture on the row would swallow the link taps in the text.
    private var termsCheckbox: some View {
        let isAccepted = context.isTermsAccepted
        return HStack(alignment: .top, spacing: 12) {
            Button { context.isTermsAccepted.toggle() } label: {
                CompoundIcon(isAccepted ? \.checkCircleSolid : \.circle)
                    .foregroundColor(isAccepted ? .compound.iconSuccessPrimary : .compound.borderInteractivePrimary)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-10)

            Text(context.viewState.termsSentence)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
                .tint(.compound.textLinkExternal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // VoiceOver reads a real toggle with its state; the links become actions.
        .accessibilityRepresentation {
            Toggle(String(context.viewState.termsSentence.characters), isOn: $context.isTermsAccepted)
        }
        .accessibilityAction(named: BipeStrings.signupTermsLink) { openURL(context.viewState.termsURL) }
        .accessibilityAction(named: BipeStrings.signupPrivacyLink) { openURL(context.viewState.privacyURL) }
    }

    private var inviteCodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(text: $context.inviteCode) { placeholder("XXXX-XXXX-XXXX") }
                .focused($focusedField, equals: .inviteCode)
                .textFieldStyle(.compound(labelText: context.viewState.inviteCodeLabel,
                                          footerText: context.viewState.inviteCodeFooter,
                                          state: context.viewState.isInviteCodeFooterError ? .error : .default))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .email }

            // PasteButton reads the clipboard without the system paste prompt. It takes a link or a whole message.
            if context.viewState.inviteCode == nil {
                PasteButton(payloadType: String.self) { strings in
                    guard let code = strings.lazy.compactMap(BipeInviteCode.init).first else { return }
                    context.inviteCode = code.value
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
            }
        }
    }

    private var emailField: some View {
        TextField(text: $context.email) { placeholder("") }
            .focused($focusedField, equals: .email)
            .textFieldStyle(.compound(labelText: BipeStrings.signupEmailOptional,
                                      footerText: context.viewState.emailError ?? emailFooter,
                                      state: context.viewState.emailError == nil && context.viewState.isEmailAcceptable ? .default : .error))
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private var emailFooter: String {
        context.viewState.isEmailAcceptable ? BipeStrings.signupEmailOptionalFooter : BipeStrings.signupEmailInvalid
    }

    // MARK: PIN

    private var pinStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                // The PIN is not a password: no password autofill, no saving in a password manager.
                SecureField(text: $context.pin) { placeholder("") }
                    .focused($focusedField, equals: .pin)
                    .textFieldStyle(.compound(labelText: BipeStrings.pinCreateTitle,
                                              footerText: context.viewState.pinFooter,
                                              state: context.viewState.pinError != nil || context.viewState.pinProblem != nil ? .error : .default))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)

                SecureField(text: $context.pinConfirmation) { placeholder("") }
                    .focused($focusedField, equals: .pinConfirmation)
                    .textFieldStyle(.compound(labelText: BipeStrings.pinConfirmTitle,
                                              footerText: context.viewState.pinMismatch ? BipeStrings.pinMismatch : BipeStrings.pinNeverAsked,
                                              state: context.viewState.pinMismatch ? .error : .default))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
            }
            .disabled(context.viewState.isAccountCreated)

            Button(L10n.actionContinue, action: continueStep)
                .buttonStyle(.compound(.primary))
                .disabled(!context.viewState.isPINValid && !context.viewState.isAccountCreated)
        }
        .onChange(of: context.pin) { _, pin in
            // A full PIN moves on to the second field.
            if pin.count == BipeRegistries.pinLength, context.viewState.pinProblem == nil { focusedField = .pinConfirmation }
        }
    }

    // MARK: Fallback

    private var fallbackStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if context.viewState.isFallbackEmailOpen {
                Text(BipeStrings.fallbackEmailBody(String(BipeRegistries.recoveryDelayHoursEmail)))
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)

                emailField
                    .submitLabel(.done)
                    .onSubmit(continueStep)

                Button(BipeStrings.signupSubmit, action: continueStep)
                    .buttonStyle(.compound(.primary))
                    .disabled(!context.viewState.canSubmitFallbackEmail && !context.viewState.isAccountCreated)
            } else {
                Button(BipeStrings.fallbackEmail) {
                    context.send(viewAction: .openFallbackEmail)
                    focusedField = .email
                }
                .buttonStyle(.compound(.primary))
            }

            Button(BipeStrings.fallbackSkip) {
                focusedField = nil
                context.send(viewAction: .skipFallback)
            }
            .buttonStyle(.compound(.tertiary))
        }
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundColor(.compound.textSecondary)
    }

    private func continueStep() {
        focusedField = nil
        context.send(viewAction: .continue)
    }
}

// MARK: - Previews

struct BipeSignupScreen_Previews: PreviewProvider {
    static let viewModel = makeViewModel(isTermsAccepted: false)
    static let termsAcceptedViewModel = makeViewModel(isTermsAccepted: true)

    static var previews: some View {
        ElementNavigationStack {
            BipeSignupScreen(context: viewModel.context)
        }
        .previewDisplayName("Terms unticked")

        ElementNavigationStack {
            BipeSignupScreen(context: termsAcceptedViewModel.context)
        }
        .previewDisplayName("Terms ticked")
    }

    static func makeViewModel(isTermsAccepted: Bool) -> BipeSignupScreenViewModel {
        let viewModel = BipeSignupScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                  signIn: BipeAccountSignIn(authenticationService: AuthenticationService.mock, appSettings: .volatile()),
                                                  appLockService: nil,
                                                  userIndicatorController: UserIndicatorControllerMock())
        viewModel.context.isTermsAccepted = isTermsAccepted
        return viewModel
    }
}
