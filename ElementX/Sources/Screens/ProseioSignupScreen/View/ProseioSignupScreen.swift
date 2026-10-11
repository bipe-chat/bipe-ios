//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

struct ProseioSignupScreen: View {
    @Bindable var context: ProseioSignupScreenViewModel.Context

    private enum Field: Hashable {
        case email, password, passwordConfirmation, handle, displayName, inviteCode
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, UIConstants.titleTopPaddingToNavigationBar)
                    .padding(.bottom, 32)

                form
            }
            .readableFrame()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(ProseioStrings.signupTitle)
        .alert(item: $context.alertInfo)
        .introspect(.window, on: .supportedVersions) { window in
            context.send(viewAction: .updateWindow(window))
        }
        .onChange(of: context.handle) { context.send(viewAction: .handleChanged) }
        .onChange(of: context.inviteCode) { context.send(viewAction: .inviteCodeChanged) }
        .onChange(of: context.email) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.password) { context.send(viewAction: .clearFieldErrors) }
    }

    private var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: \.userProfileSolid)
                .padding(.bottom, 8)

            Text(context.viewState.inviterHandle.map(ProseioStrings.signupInvitedBy) ?? ProseioStrings.signupHeader)
                .font(.compound.bodyLG)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 32) {
            fields
                .disabled(context.viewState.isAccountCreated)
            
            Button(action: submit) {
                Text(context.viewState.isAccountCreated ? L10n.actionContinue : ProseioStrings.signupSubmit)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canSubmit)
        }
    }
    
    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField(text: $context.displayName) { placeholder("") }
                .focused($focusedField, equals: .displayName)
                .textFieldStyle(.compound(labelText: ProseioStrings.signupDisplayName,
                                          footerText: ProseioStrings.signupDisplayNameFooter))
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
            
            TextField(text: $context.email) { placeholder("") }
                .focused($focusedField, equals: .email)
                .textFieldStyle(.compound(labelText: ProseioStrings.signupEmail,
                                          footerText: context.viewState.emailError ?? ProseioStrings.signupEmailFooter,
                                          state: context.viewState.emailError == nil ? .default : .error))
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            SecureField(text: $context.password) { placeholder("") }
                .focused($focusedField, equals: .password)
                .textFieldStyle(.compound(labelText: ProseioStrings.signupPassword,
                                          footerText: context.viewState.passwordError ?? ProseioStrings.signupPasswordFooter(String(ProseioSignupRules.passwordMinLength)),
                                          state: context.viewState.passwordError == nil ? .default : .error))
                .textContentType(.newPassword)
                .submitLabel(.next)
                .onSubmit { focusedField = .passwordConfirmation }

            SecureField(text: $context.passwordConfirmation) { placeholder("") }
                .focused($focusedField, equals: .passwordConfirmation)
                .textFieldStyle(.compound(labelText: ProseioStrings.signupPasswordConfirm,
                                          footerText: context.viewState.passwordMismatch ? ProseioStrings.signupPasswordMismatch : nil,
                                          state: context.viewState.passwordMismatch ? .error : .default))
                .textContentType(.newPassword)
                .submitLabel(.next)
                .onSubmit { focusedField = .handle }

            TextField(text: $context.handle) { placeholder(ProseioStrings.handlePlaceholder) }
                .focused($focusedField, equals: .handle)
                .textFieldStyle(.compound(labelText: ProseioStrings.signupHandle,
                                          footerText: context.viewState.handleFooter,
                                          state: context.viewState.handleFieldState))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .inviteCode }

            VStack(alignment: .leading, spacing: 8) {
                TextField(text: $context.inviteCode) { placeholder("XXXX-XXXX-XXXX") }
                    .focused($focusedField, equals: .inviteCode)
                    .textFieldStyle(.compound(labelText: ProseioStrings.signupInviteCode,
                                              footerText: context.viewState.inviteCodeFooter,
                                              state: context.viewState.inviteCodeFooter == nil ? .default : .error))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(submit)
                
                // PasteButton reads the clipboard without the system paste prompt. It takes a link or a whole message.
                if context.viewState.inviteCode == nil {
                    PasteButton(payloadType: String.self) { strings in
                        guard let code = strings.lazy.compactMap(ProseioInviteCode.init).first else { return }
                        context.inviteCode = code.value
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                }
            }
        }
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundColor(.compound.textSecondary)
    }

    private func submit() {
        guard context.viewState.canSubmit else { return }
        focusedField = nil
        context.send(viewAction: .submit)
    }
}

// MARK: - Previews

struct ProseioSignupScreen_Previews: PreviewProvider {
    static let viewModel = ProseioSignupScreenViewModel(apiClient: ProseioAPIClient(baseURL: "https://api.example.com"),
                                                        authenticationService: AuthenticationService.mock,
                                                        serverNameOrBaseURL: "example.com",
                                                        userIndicatorController: UserIndicatorControllerMock())

    static var previews: some View {
        ElementNavigationStack {
            ProseioSignupScreen(context: viewModel.context)
        }
    }
}
