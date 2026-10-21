//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import SwiftUI

struct JoinRoomByAddressView: View {
    @ObservedObject var context: StartChatScreenViewModel.Context
    
    @State private var sheetHeight: CGFloat = .zero
    @FocusState private var textFieldFocus
    private let topPadding: CGFloat = 22
    
    private var footerText: String {
        // Bipe: grupo, not sala (bipe#508)
        switch context.viewState.joinByAddressState {
        case .example:
            BipeStrings.groupScreenStartChatJoinRoomByAddressSupportingText
        case .addressNotFound:
            BipeStrings.groupScreenStartChatJoinRoomByAddressRoomNotFound
        case .addressFound:
            BipeStrings.groupScreenStartChatJoinRoomByAddressRoomFound
        case .invalidAddress:
            L10n.screenStartChatJoinRoomByAddressInvalidAddress
        }
    }
    
    private var textFieldState: CompoundTextFieldStyle.State {
        switch context.viewState.joinByAddressState {
        case .addressFound:
            .success
        case .example:
            .default
        case .addressNotFound, .invalidAddress:
            .error
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TextField(L10n.screenStartChatJoinRoomByAddressPlaceholder,
                          text: $context.roomAddress)
                    // Bipe: grupo, not sala (bipe#508)
                    .textFieldStyle(.compound(labelText: BipeStrings.groupScreenStartChatJoinRoomByAddressAction,
                                              footerText: footerText,
                                              state: textFieldState))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .accessibilityLabel(L10n.screenStartChatJoinRoomByAddressPlaceholder)
                    .focused($textFieldFocus)
                    .onChange(of: context.roomAddress) { _, newValue in
                        context.roomAddress = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                
                Button(L10n.actionContinue) {
                    context.send(viewAction: .joinRoomByAddress)
                }
                .buttonStyle(.compound(.primary))
            }
            .padding(.horizontal, 16)
            .readHeight($sheetHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top, topPadding) // For the drag indicator
        .presentationDetents([.height(sheetHeight + topPadding)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.compound.bgCanvasDefault)
        .onAppear {
            textFieldFocus = true
        }
    }
}

struct JoinRoomByAddressView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = {
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@userid:example.com"))))
        let userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success([.mockAlice])
        
        return StartChatScreenViewModel(userSession: userSession,
                                        analytics: AnalyticsServiceMock(.init()),
                                        userIndicatorController: UserIndicatorControllerMock(),
                                        userDiscoveryService: userDiscoveryService)
    }()
    
    static var previews: some View {
        JoinRoomByAddressView(context: viewModel.context)
    }
}
