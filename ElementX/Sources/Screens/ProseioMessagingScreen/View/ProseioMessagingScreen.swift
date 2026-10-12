//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

struct ProseioMessagingScreen: View {
    @Bindable var context: ProseioMessagingScreenViewModel.Context
    
    var body: some View {
        Form {
            Section {
                ForEach(ProseioWhoCanMessage.allCases, id: \.self) { option in
                    ListRow(label: .plain(title: option.title, description: option.body),
                            kind: .selection(isSelected: context.viewState.selection == option) {
                                context.send(viewAction: .select(option))
                            })
                            .disabled(context.viewState.isDisabled)
                }
            }
        }
        .compoundList()
        .navigationTitle(ProseioStrings.messagingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
}

// MARK: - Previews

struct ProseioMessagingScreen_Previews: PreviewProvider {
    static let viewModel = ProseioMessagingScreenViewModel(apiClient: ProseioAPIClient(baseURL: "https://api.example.com"),
                                                           clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")))
    
    static var previews: some View {
        ElementNavigationStack {
            ProseioMessagingScreen(context: viewModel.context)
        }
    }
}
