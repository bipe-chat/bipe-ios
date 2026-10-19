//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeSignupScreen: View {
    @Bindable var context: BipeSignupScreenViewModel.Context
    
    private enum Field: Hashable {
        case inviteCode, displayName, email, pin, pinConfirmation, waitlistEmail
    }
    
    @FocusState private var focusedField: Field?
    
    private var step: BipeOnboardingStep {
        context.viewState.step
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, UIConstants.titleTopPaddingToNavigationBar)
                    .padding(.bottom, 32)
                
                switch step {
                case .inviteCode: inviteCodeStep
                case .name: nameStep
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
        .navigationBarBackButtonHidden(step != context.viewState.firstStep)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .sheet(isPresented: $context.isWaitlistPresented) { waitlistSheet }
        .onChange(of: context.inviteCode) { context.send(viewAction: .inviteCodeChanged) }
        .onChange(of: context.email) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.pin) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: context.pinConfirmation) { context.send(viewAction: .clearFieldErrors) }
        .onChange(of: step, initial: true) { _, step in
            focusedField = switch step {
            case .inviteCode: .inviteCode
            case .name: .displayName
            case .pin: .pin
            case .fallback: nil
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if context.viewState.canGoBack {
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
            
            Text(headerTitle)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            if let headerBody {
                Text(headerBody)
                    .font(.compound.bodyLG)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.compound.textSecondary)
            }
        }
    }
    
    private var headerIcon: KeyPath<CompoundIcons, Image> {
        switch step {
        case .inviteCode: \.userAddSolid
        case .name: \.userProfileSolid
        case .pin: \.lockSolid
        case .fallback: \.keySolid
        }
    }
    
    private var headerTitle: String {
        switch step {
        case .inviteCode: BipeStrings.inviteCodeTitle
        case .name: context.viewState.isCompany ? BipeStrings.companyName : BipeStrings.signupNameTitle
        case .pin: BipeStrings.pinCreateTitle
        case .fallback: BipeStrings.fallbackTitle
        }
    }
    
    private var headerBody: String? {
        switch step {
        case .inviteCode: BipeStrings.inviteCodeBody
        case .name: context.viewState.inviterHandle.map(BipeStrings.signupInvitedBy)
        case .pin: BipeStrings.pinCreateBody(String(BipeRegistries.pinLength))
        case .fallback: BipeStrings.fallbackBody
        }
    }
    
    // MARK: Invite code
    
    private var inviteCodeStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(text: $context.inviteCode) { placeholder("XXXX-XXXX-XXXX") }
                    .focused($focusedField, equals: .inviteCode)
                    .textFieldStyle(.compound(labelText: BipeStrings.inviteCodeTitle,
                                              footerText: context.viewState.inviteCodeFooter,
                                              state: context.viewState.isInviteCodeFooterError ? .error : .default))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .onSubmit(primary)
                
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
            
            buttons(isPrimaryEnabled: context.viewState.canContinueInviteCode)
        }
    }
    
    // MARK: Name
    
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            TextField(text: $context.displayName) { placeholder("") }
                .focused($focusedField, equals: .displayName)
                .textFieldStyle(.compound(labelText: context.viewState.isCompany ? BipeStrings.companyName : BipeStrings.signupDisplayName,
                                          footerText: context.viewState.isCompany ? BipeStrings.accountNewCompanyBody : BipeStrings.signupDisplayNameFooter))
                .textContentType(.name)
                .submitLabel(.continue)
                .onSubmit(primary)
                .disabled(context.viewState.isAccountCreated)
            
            VStack(spacing: 20) {
                BipeTermsCheckbox(isAccepted: $context.isTermsAccepted,
                                  termsURL: context.viewState.termsURL,
                                  privacyURL: context.viewState.privacyURL)
                    .disabled(context.viewState.isAccountCreated)
                
                buttons(isPrimaryEnabled: context.viewState.canContinueName)
            }
        }
    }
    
    // MARK: PIN
    
    private var pinStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                // The PIN is not a password: no password autofill, no saving in a password manager.
                SecureField(text: $context.pin) { placeholder("") }
                    .focused($focusedField, equals: .pin)
                    .textFieldStyle(.compound(labelText: BipeStrings.accountPinSection,
                                              footerText: context.viewState.pinFooter,
                                              state: context.viewState.pinFooter != nil ? .error : .default))
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
            
            buttons(isPrimaryEnabled: context.viewState.isPINValid || context.viewState.isAccountCreated)
        }
        .onChange(of: context.pin) { _, pin in
            // A full PIN moves on to the second field.
            if pin.count == BipeRegistries.pinLength, context.viewState.pinProblem == nil {
                focusedField = .pinConfirmation
            }
        }
    }
    
    // MARK: Fallback
    
    private var fallbackStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if context.viewState.isFallbackEmailOpen {
                Text(BipeStrings.fallbackEmailBody(String(BipeRegistries.recoveryDelayHoursEmail)))
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                
                TextField(text: $context.email) { placeholder("") }
                    .focused($focusedField, equals: .email)
                    .textFieldStyle(.compound(labelText: BipeStrings.signupEmail,
                                              footerText: context.viewState.emailError ?? emailFooter,
                                              state: context.viewState.emailError == nil && emailFooter == nil ? .default : .error))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(primary)
                    .onAppear { focusedField = .email }
                
                Button(BipeStrings.signupSubmit, action: primary)
                    .buttonStyle(.compound(.primary))
                    .disabled(!context.viewState.canSubmitFallbackEmail && !context.viewState.isAccountCreated)
                
                textButtons
            } else {
                buttons(isPrimaryEnabled: true)
            }
        }
    }
    
    private var emailFooter: String? {
        let email = context.viewState.trimmedEmail
        return email.isEmpty || BipeSignupRules.isPlausibleEmail(email) ? nil : BipeStrings.signupEmailInvalid
    }
    
    // MARK: Waitlist
    
    private var waitlistSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(BipeStrings.waitlistBody)
                .font(.compound.bodyLG)
                .foregroundColor(.compound.textPrimary)
            
            if context.viewState.isWaitlistJoined {
                Label(BipeStrings.waitlistDone, icon: \.checkCircle)
                    .font(.compound.bodyLGSemibold)
                    .foregroundStyle(.compound.textSuccessPrimary)
            } else {
                TextField(text: $context.waitlistEmail) { placeholder("") }
                    .focused($focusedField, equals: .waitlistEmail)
                    .textFieldStyle(.compound(labelText: BipeStrings.signupEmail,
                                              footerText: context.viewState.waitlistError,
                                              state: context.viewState.waitlistError == nil ? .default : .error))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { context.send(viewAction: .joinWaitlist) }
                
                Button(BipeOnboarding.waitlistPrimary.title) {
                    focusedField = nil
                    context.send(viewAction: .joinWaitlist)
                }
                .buttonStyle(.compound(.primary))
                .disabled(!context.viewState.canJoinWaitlist)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: Buttons
    
    /// The step's buttons from the registry: one filled button, then its text buttons.
    private func buttons(isPrimaryEnabled: Bool) -> some View {
        VStack(spacing: 16) {
            Button(step.primary.title, action: primary)
                .buttonStyle(.compound(.primary))
                .disabled(!isPrimaryEnabled)
            
            textButtons
        }
    }
    
    private var textButtons: some View {
        ForEach(step.text, id: \.titleKey) { button in
            Button(button.title) {
                focusedField = nil
                context.send(viewAction: .text(button.target))
            }
            .buttonStyle(.compound(.tertiary))
            .frame(maxWidth: .infinity)
        }
    }
    
    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundColor(.compound.textSecondary)
    }
    
    private func primary() {
        focusedField = nil
        context.send(viewAction: .primary)
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
