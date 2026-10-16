//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeHandleScreen: View {
    @Bindable var context: BipeHandleScreenViewModel.Context
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                handleField
                if let handle = context.viewState.currentHandle {
                    // Bipe ADR 0066: removal is allowed at any time, also during the cooldown.
                    Button(role: .destructive) {
                        context.send(viewAction: .removeHandle)
                    } label: {
                        Label(BipeStrings.handleRemove, icon: \.delete)
                    }
                    .buttonStyle(.compound(.tertiary, size: .medium))
                    .disabled(!context.viewState.canRemove)
                    profileLinkSection(handle: handle)
                }
            }
            .readableFrame()
            .padding(16)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationTitle(BipeStrings.settingsHandle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.actionSave, action: save)
                    .disabled(!context.viewState.canSave)
            }
        }
        .alert(item: $context.alertInfo)
        .onChange(of: context.handle) { context.send(viewAction: .handleChanged) }
    }
    
    private var handleField: some View {
        TextField(text: $context.handle) {
            Text(BipeStrings.handlePlaceholder).foregroundColor(.compound.textSecondary)
        }
        .focused($isFocused)
        .textFieldStyle(.compound(labelText: BipeStrings.settingsHandle,
                                  footerText: context.viewState.footer,
                                  state: context.viewState.fieldState))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit(save)
        .disabled(context.viewState.isLoading || context.viewState.isInCooldown)
    }
    
    /// The user's own profile link: QR code and share button.
    @ViewBuilder
    private func profileLinkSection(handle: String) -> some View {
        if let url = BipeProfileLink.url(handle: handle) {
            VStack(spacing: 16) {
                BipeQRCodeView(url: url)
                    .frame(maxWidth: 220)
                Text(BipeStrings.profileQrFooter)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: url) {
                    Label(BipeStrings.profileShare, icon: \.shareIos)
                }
                .buttonStyle(.compound(.secondary, size: .medium))
            }
        }
    }
    
    private func save() {
        guard context.viewState.canSave else { return }
        isFocused = false
        context.send(viewAction: .save)
    }
}

// MARK: - Previews

struct BipeHandleScreen_Previews: PreviewProvider {
    static let viewModel = BipeHandleScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                     clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                     userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipeHandleScreen(context: viewModel.context)
        }
    }
}
