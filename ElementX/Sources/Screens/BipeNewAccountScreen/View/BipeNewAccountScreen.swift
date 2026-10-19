//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Bipe: "Nova conta" (bipe#445, #446). A personal or company sign-up with an invite from the account on screen, or a
/// sign-in to an account that already exists.
struct BipeNewAccountScreen: View {
    @Bindable var context: BipeNewAccountScreenViewModel.Context
    
    var body: some View {
        Form {
            signUpSection
            signInSection
        }
        .compoundList()
        .navigationTitle(BipeStrings.accountNewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }
    
    private var signUpSection: some View {
        Section {
            ListRow(label: .default(title: BipeStrings.accountNewPersonal,
                                    description: context.viewState.personalBody,
                                    icon: \.user),
                    details: .isWaiting(context.viewState.creatingInviteFor == .personal),
                    kind: .button { context.send(viewAction: .signUp(.personal)) })
                .disabled(!context.viewState.isPersonalEnabled)
            
            if context.viewState.showsCompany {
                ListRow(label: .default(title: BipeStrings.accountNewCompany,
                                        description: BipeStrings.accountNewCompanyBody,
                                        icon: \.company),
                        details: .isWaiting(context.viewState.creatingInviteFor == .company),
                        kind: .button { context.send(viewAction: .signUp(.company)) })
                    .disabled(!context.viewState.isCompanyEnabled)
            }
        } footer: {
            if let footer = context.viewState.inviteFooter {
                Text(footer)
                    .compoundListSectionFooter()
            }
        }
    }
    
    private var signInSection: some View {
        Section {
            ListRow(label: .default(title: BipeStrings.accountNewExisting,
                                    description: BipeStrings.accountNewExistingBody,
                                    icon: \.mobile),
                    kind: .button { context.send(viewAction: .signIn) })
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.actionCancel) {
                context.send(viewAction: .cancel)
            }
        }
    }
}

// MARK: - Previews

struct BipeNewAccountScreen_Previews: PreviewProvider {
    static let viewModel = BipeNewAccountScreenViewModel(accountName: "Ana",
                                                         canAddPersonal: true,
                                                         maxPersonalAccounts: 2,
                                                         showsCompany: true,
                                                         inviteCreator: nil)
    static let capReachedViewModel = BipeNewAccountScreenViewModel(accountName: "Ana",
                                                                   canAddPersonal: false,
                                                                   maxPersonalAccounts: 2,
                                                                   showsCompany: false,
                                                                   inviteCreator: nil)
    
    static var previews: some View {
        ElementNavigationStack {
            BipeNewAccountScreen(context: viewModel.context)
        }
        .previewDisplayName("Rows")
        
        ElementNavigationStack {
            BipeNewAccountScreen(context: capReachedViewModel.context)
        }
        .previewDisplayName("Cap reached")
    }
}
