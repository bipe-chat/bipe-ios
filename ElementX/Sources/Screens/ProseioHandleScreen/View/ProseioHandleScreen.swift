//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

struct ProseioHandleScreen: View {
    @Bindable var context: ProseioHandleScreenViewModel.Context
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                handleField
                if let handle = context.viewState.currentHandle {
                    profileLinkSection(handle: handle)
                }
            }
            .readableFrame()
            .padding(16)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .navigationTitle(ProseioStrings.settingsHandle)
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
                Text(ProseioStrings.handlePlaceholder).foregroundColor(.compound.textSecondary)
            }
            .focused($isFocused)
            .textFieldStyle(.compound(labelText: ProseioStrings.settingsHandle,
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
        if let url = ProseioProfileLink.url(handle: handle) {
            VStack(spacing: 16) {
                ProseioQRCodeView(url: url)
                    .frame(maxWidth: 220)
                Text(ProseioStrings.profileQrFooter)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: url) {
                    Label(ProseioStrings.profileShare, icon: \.shareIos)
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

struct ProseioHandleScreen_Previews: PreviewProvider {
    static let viewModel = ProseioHandleScreenViewModel(apiClient: ProseioAPIClient(baseURL: "https://api.example.com"),
                                                        clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                        userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            ProseioHandleScreen(context: viewModel.context)
        }
    }
}
