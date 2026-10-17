//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// Blocking: no close button, no swipe down, no sign-out. The only way on is to accept (ADR 0113).
struct BipeTermsReacceptScreen: View {
    @Bindable var context: BipeTermsReacceptScreenViewModel.Context
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                
                BipeTermsCheckbox(isAccepted: $context.isTermsAccepted,
                                  termsURL: context.viewState.termsURL,
                                  privacyURL: context.viewState.privacyURL)
                    .disabled(context.viewState.isSaving)
                
                VStack(spacing: 12) {
                    if context.viewState.isFailed {
                        Text(BipeStrings.termsReacceptFailed)
                            .font(.compound.bodyMD)
                            .foregroundColor(.compound.textCriticalPrimary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button { context.send(viewAction: .continue) } label: {
                        HStack(spacing: 8) {
                            if context.viewState.isSaving {
                                ProgressView()
                            }
                            Text(L10n.actionContinue)
                        }
                    }
                    .buttonStyle(.compound(.primary))
                    .disabled(!context.viewState.canContinue)
                }
            }
            .readableFrame()
            .padding(.horizontal, 16)
            .padding(.top, 64)
            .padding(.bottom, 16)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: \.document)
                .padding(.bottom, 8)
            
            Text(BipeStrings.termsReacceptTitle)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
            
            Text(BipeStrings.termsReacceptBody)
                .font(.compound.bodyLG)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
        }
    }
}

// MARK: - Previews

struct BipeTermsReacceptScreen_Previews: PreviewProvider {
    static let untickedViewModel = makeViewModel()
    static let tickedViewModel = makeViewModel(isTermsAccepted: true)
    static let savingViewModel = makeViewModel(isTermsAccepted: true, isSaving: true)
    static let failedViewModel = makeViewModel(isTermsAccepted: true, isFailed: true)
    
    static var previews: some View {
        BipeTermsReacceptScreen(context: untickedViewModel.context)
            .previewDisplayName("Unticked")
        BipeTermsReacceptScreen(context: tickedViewModel.context)
            .previewDisplayName("Ticked")
        BipeTermsReacceptScreen(context: savingViewModel.context)
            .previewDisplayName("Saving")
        BipeTermsReacceptScreen(context: failedViewModel.context)
            .previewDisplayName("Failed")
    }
    
    static func makeViewModel(isTermsAccepted: Bool = false, isSaving: Bool = false, isFailed: Bool = false) -> BipeTermsReacceptScreenViewModel {
        let viewModel = BipeTermsReacceptScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                         clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                         site: "https://bipe.chat")
        viewModel.context.isTermsAccepted = isTermsAccepted
        viewModel.state.isSaving = isSaving
        viewModel.state.isFailed = isFailed
        return viewModel
    }
}
