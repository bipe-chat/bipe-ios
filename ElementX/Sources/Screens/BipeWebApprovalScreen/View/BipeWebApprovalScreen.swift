//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI
import WebKit

/// The full-access warning with its cooldown, then the private MAS web view (ADR 0118).
struct BipeWebApprovalScreen: View {
    let model: BipeWebApprovalModel
    
    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) {
                        Task { await model.close() }
                    }
                    .disabled(model.step == .finishing)
                }
            }
            .onDisappear { model.end() }
    }
    
    private var closeTitle: String {
        if model.step == .failed {
            return L10n.actionClose
        }
        if case .signOut = model.purpose {
            return L10n.actionDone
        }
        return L10n.actionCancel
    }
    
    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .warning(let secondsLeft):
            warning(secondsLeft: secondsLeft)
        case .failed:
            failed
        case .loading, .page, .finishing:
            page
        }
    }
    
    private func warning(secondsLeft: Int) -> some View {
        FullscreenDialog(topPadding: 24, horizontalPadding: 24) {
            VStack(spacing: 24) {
                TitleAndIcon(title: BipeStrings.linkComputerWarningTitle,
                             subtitle: BipeStrings.linkComputerWarningBody,
                             icon: \.computer,
                             iconStyle: .alertSolid)
                
                Label(BipeStrings.linkComputerWarningScam, icon: \.error)
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.compound.textCriticalPrimary)
            }
        } bottomContent: {
            Button(secondsLeft > 0 ? BipeStrings.pauseCountdown(String(secondsLeft)) : BipeStrings.linkComputerContinue) {
                model.continueAfterWarning()
            }
            .buttonStyle(.compound(.primary))
            .disabled(secondsLeft > 0)
        }
        .background()
        .backgroundStyle(.compound.bgSubtleSecondary)
        .onAppear { BipeHaptics.play(.warning) }
    }
    
    private var failed: some View {
        FullscreenDialog(topPadding: 24, horizontalPadding: 24) {
            TitleAndIcon(title: BipeStrings.linkComputerErrorTitle,
                         subtitle: BipeStrings.linkComputerErrorSignIn,
                         icon: \.error,
                         iconStyle: .alertSolid)
        } bottomContent: {
            EmptyView()
        }
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
    }
    
    private var page: some View {
        VStack(spacing: 0) {
            if model.isConsentPage {
                consentHeader
            }
            ZStack {
                BipePrivateWebView(webView: model.webView)
                    .opacity(model.step == .page ? 1 : 0)
                
                if model.step != .page {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(BipeStrings.linkComputerLoading)
                            .font(.compound.bodyMD)
                            .foregroundStyle(.compound.textSecondary)
                    }
                }
            }
        }
        .background(.compound.bgCanvasDefault)
    }
    
    private var consentHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.placeText ?? BipeStrings.linkComputerPlaceUnknown)
                .font(.compound.bodyMDSemibold)
                .foregroundStyle(.compound.textPrimary)
            Text(BipeStrings.linkComputerConsentHint)
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
            Text(BipeStrings.linkComputerPlaceSource)
                .font(.compound.bodyXS)
                .foregroundStyle(.compound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.compound.bgSubtleSecondary)
    }
}

/// Shows the model's `WKWebView`. The model owns it, so SwiftUI updates never reload the page.
private struct BipePrivateWebView: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

/// Hosts the sign-out web view in its own navigation stack.
final class BipeWebApprovalScreenCoordinator: CoordinatorProtocol {
    private let model: BipeWebApprovalModel
    
    init(model: BipeWebApprovalModel) {
        self.model = model
    }
    
    func toPresentable() -> AnyView {
        AnyView(BipeWebApprovalScreen(model: model))
    }
}
