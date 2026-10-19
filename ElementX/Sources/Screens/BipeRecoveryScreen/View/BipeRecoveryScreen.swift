//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeRecoveryScreen: View {
    @Bindable var context: BipeRecoveryScreenViewModel.Context
    
    var body: some View {
        Form {
            if let notice = context.viewState.notice {
                Section {
                    ListRow(label: .plain(title: notice), kind: .label)
                }
            }
            
            switch context.viewState.mode {
            case .choose:
                chooseSections
            case .token:
                Section {
                    ListRow(label: .plain(title: BipeStrings.recoveryTokenFound), kind: .label)
                }
                pinSections
            case .emailLink:
                pinSections
            case .waiting:
                waitingSection
            }
        }
        .compoundList()
        .navigationTitle(context.viewState.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .introspect(.window, on: .supportedVersions) { window in
            context.send(viewAction: .updateWindow(window))
        }
        .onChange(of: context.pin) { context.send(viewAction: .pinChanged) }
        .onChange(of: context.pinConfirmation) { context.send(viewAction: .pinChanged) }
    }
    
    // MARK: - Choose
    
    /// Rows in the order of bipe-shared `registries/onboarding.json` (bipe#415), the same as Android.
    /// A row with a `planned:` gate stays hidden until its issue ships.
    private var chooseSections: some View {
        ForEach(BipeOnboardingRecoveryRow.allCases.filter { $0.gate == nil }, id: \.self) { row in
            switch row {
            case .token:
                if context.viewState.hasRecoveryToken {
                    Section {
                        ListRow(label: .default(title: BipeStrings.pinEnterTitle, description: BipeStrings.recoveryTokenFound, icon: \.lock),
                                kind: .button { context.send(viewAction: .useRecoveryToken) })
                    }
                }
            case .oldPhone:
                Section {
                    ListRow(label: .default(title: BipeStrings.recoveryQr, description: BipeStrings.recoveryQrBody, icon: \.qrCode),
                            kind: .button { context.send(viewAction: .loginWithQR) })
                } footer: {
                    Text(BipeStrings.recoveryQrNeverFromOthers)
                        .compoundListSectionFooter()
                }
            case .email:
                emailSection
            case .beta:
                // Beta accounts made before ADR 0057 still sign in with their email and password.
                Section {
                    ListRow(label: .default(title: BipeStrings.recoveryBeta, description: BipeStrings.recoveryBetaBody, icon: \.userProfile),
                            kind: .button { context.send(viewAction: .signInWithEmail) })
                }
            }
        }
    }
    
    private var emailSection: some View {
        Section {
            ListRow(label: .plain(title: BipeStrings.recoveryEmail,
                                  description: BipeStrings.recoveryEmailBody(String(BipeRegistries.recoveryDelayHoursEmail))),
                    kind: .label)
            if context.viewState.emailSent {
                ListRow(label: .plain(title: BipeStrings.recoveryEmailSent), kind: .label)
            } else {
                ListRow(label: .plain(title: BipeStrings.recoveryEmailField),
                        kind: .textField(text: $context.email))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                ListRow(label: .action(title: L10n.actionContinue, icon: \.email),
                        kind: .button { context.send(viewAction: .requestEmail) })
                    .disabled(!context.viewState.canRequestEmail)
            }
        }
    }
    
    // MARK: - PIN
    
    @ViewBuilder
    private var pinSections: some View {
        Section {
            ListRow(kind: .custom {
                VStack(spacing: 16) {
                    PINTextField(pinCode: $context.pin, isSecure: true, maxLength: BipeRegistries.pinLength, size: .dots)
                    if context.viewState.isNewPIN {
                        Text(BipeStrings.pinConfirmTitle)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                        PINTextField(pinCode: $context.pinConfirmation, isSecure: true, maxLength: BipeRegistries.pinLength, size: .dots)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            })
        } header: {
            Text(context.viewState.isNewPIN ? BipeStrings.pinCreateBody(String(BipeRegistries.pinLength)) : BipeStrings.pinEnterTitle)
                .compoundListSectionHeader()
        } footer: {
            if let footer = context.viewState.pinError ?? context.viewState.pinProblem?.localizedMessage ?? (context.viewState.pinMismatch ? BipeStrings.pinMismatch : nil) {
                Text(footer)
                    .compoundListSectionFooter()
                    .foregroundStyle(.compound.textCriticalPrimary)
            } else {
                Text(BipeStrings.pinNeverAsked)
                    .compoundListSectionFooter()
            }
        }
        
        Section {
            ListRow(label: .centeredAction(title: L10n.actionContinue, icon: \.arrowRight),
                    kind: .button { context.send(viewAction: .submitPIN) })
                .disabled(!context.viewState.canSubmitPIN)
            if !context.viewState.isNewPIN {
                ListRow(label: .centeredAction(title: BipeStrings.pinForgot, icon: \.email),
                        kind: .button { context.send(viewAction: .forgotPIN) })
            }
        } footer: {
            Text(BipeStrings.recoveryHistoryNote)
                .compoundListSectionFooter()
        }
    }
    
    // MARK: - Waiting
    
    private var waitingSection: some View {
        Section {
            ListRow(label: .plain(title: context.viewState.waitingBody ?? ""), kind: .label)
            ListRow(label: .centeredAction(title: L10n.actionContinue, icon: \.arrowRight),
                    kind: .button { context.send(viewAction: .refreshClaim) })
        } footer: {
            Text(BipeStrings.recoveryHistoryNote)
                .compoundListSectionFooter()
        }
    }
}

// MARK: - Previews

struct BipeRecoveryScreen_Previews: PreviewProvider {
    static let viewModel = BipeRecoveryScreenViewModel(mode: .choose,
                                                       apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                       signIn: BipeAccountSignIn(authenticationService: AuthenticationService.mock, appSettings: .volatile()),
                                                       serverNameOrBaseURL: "example.com",
                                                       appLockService: nil,
                                                       userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipeRecoveryScreen(context: viewModel.context)
        }
    }
}
