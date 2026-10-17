//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeAccountScreen: View {
    @Bindable var context: BipeAccountScreenViewModel.Context
    
    var body: some View {
        Form {
            switch context.viewState.mode {
            case .pin:
                if context.viewState.isEditingPIN {
                    pinFormSections
                } else {
                    pinSection
                }
            case .email:
                emailSection
            }
        }
        .compoundList()
        .navigationTitle(context.viewState.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
        .onChange(of: context.pin) { context.send(viewAction: .pinChanged) }
        .onChange(of: context.pinConfirmation) { context.send(viewAction: .pinChanged) }
    }
    
    // MARK: - PIN
    
    @ViewBuilder
    private var pinSection: some View {
        if let status = context.viewState.status {
            Section {
                if status.pinBlocked {
                    ListRow(label: .plain(title: BipeStrings.pinBlockedTitle,
                                          description: BipeStrings.pinBlockedBody(String(BipeRegistries.pinMaxWrongTries)),
                                          role: .destructive),
                            kind: .label)
                }
                if context.viewState.isBetaAccount {
                    ListRow(label: .default(title: BipeStrings.pinCreateTitle,
                                            description: BipeStrings.pinCreateBody(String(BipeRegistries.pinLength)),
                                            icon: \.lock),
                            kind: .navigationLink { context.send(viewAction: .editPIN) })
                } else {
                    ListRow(label: .default(title: BipeStrings.pinChangeTitle, icon: \.lock),
                            kind: .navigationLink { context.send(viewAction: .editPIN) })
                }
            }
        } else if context.viewState.isLoading {
            Section {
                ListRow(label: .plain(title: L10n.commonLoading), kind: .label)
            }
        }
    }
    
    @ViewBuilder
    private var pinFormSections: some View {
        Section {
            ListRow(kind: .custom {
                VStack(spacing: 16) {
                    PINTextField(pinCode: $context.pin, isSecure: true, maxLength: BipeRegistries.pinLength, size: .small)
                    Text(BipeStrings.pinConfirmTitle)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                    PINTextField(pinCode: $context.pinConfirmation, isSecure: true, maxLength: BipeRegistries.pinLength, size: .small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            })
        } header: {
            Text(BipeStrings.pinCreateBody(String(BipeRegistries.pinLength)))
                .compoundListSectionHeader()
        } footer: {
            if let footer = context.viewState.pinProblem?.localizedMessage ?? (context.viewState.pinMismatch ? BipeStrings.pinMismatch : nil) {
                Text(footer)
                    .compoundListSectionFooter()
                    .foregroundStyle(.compound.textCriticalPrimary)
            } else {
                Text(BipeStrings.pinNeverAsked)
                    .compoundListSectionFooter()
            }
        }
        
        Section {
            ListRow(label: .centeredAction(title: L10n.actionSave, icon: \.check),
                    kind: .button { context.send(viewAction: .savePIN) })
                .disabled(!context.viewState.canSavePIN)
            ListRow(label: .centeredAction(title: L10n.actionCancel, icon: \.close),
                    kind: .button { context.send(viewAction: .cancelPIN) })
        }
    }
    
    // MARK: - Email
    
    @ViewBuilder
    private var emailSection: some View {
        if let status = context.viewState.status {
            Section {
                if let email = status.email {
                    ListRow(label: .plain(title: email, description: BipeStrings.emailConfirmed), kind: .label)
                }
                if let pending = status.emailPending {
                    ListRow(label: .plain(title: pending, description: BipeStrings.emailPending), kind: .label)
                }
                if let sentTo = context.viewState.emailSentTo {
                    ListRow(label: .plain(title: BipeStrings.emailSent(sentTo)), kind: .label)
                }
                ListRow(label: .plain(title: BipeStrings.recoveryEmailField),
                        kind: .textField(text: $context.email))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                ListRow(label: .action(title: L10n.actionSave, icon: \.email),
                        kind: .button { context.send(viewAction: .saveEmail) })
                    .disabled(!context.viewState.canSaveEmail)
                if status.email != nil || status.emailPending != nil {
                    ListRow(label: .action(title: BipeStrings.emailRemove, icon: \.delete, role: .destructive),
                            kind: .button { context.send(viewAction: .removeEmail) })
                }
            } header: {
                Text(BipeStrings.emailTitle)
                    .compoundListSectionHeader()
            } footer: {
                Text(status.email == nil && status.emailPending == nil ? BipeStrings.fallbackReminder : BipeStrings.emailFooter)
                    .compoundListSectionFooter()
            }
        }
    }
}

// MARK: - Previews

struct BipeAccountScreen_Previews: PreviewProvider {
    static let viewModel = BipeAccountScreenViewModel(mode: .email,
                                                      apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                      clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                      appLockService: AppLockServiceMock.mock(),
                                                      userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipeAccountScreen(context: viewModel.context)
        }
    }
}
