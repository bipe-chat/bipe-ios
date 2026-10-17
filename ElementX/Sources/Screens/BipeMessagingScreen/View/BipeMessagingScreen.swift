//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeMessagingScreen: View {
    @Bindable var context: BipeMessagingScreenViewModel.Context
    
    var body: some View {
        Form {
            Section {
                ForEach(BipeWhoCanMessage.allCases, id: \.self) { option in
                    ListRow(label: .plain(title: option.title, description: option.body),
                            kind: .selection(isSelected: context.viewState.selection == option) {
                                context.send(viewAction: .select(option))
                            })
                            .disabled(context.viewState.isDisabled)
                }
            }
        }
        .compoundList()
        .navigationTitle(BipeStrings.messagingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
}

// MARK: - Previews

struct BipeMessagingScreen_Previews: PreviewProvider {
    static let viewModel = BipeMessagingScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                        clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")))
    
    static var previews: some View {
        ElementNavigationStack {
            BipeMessagingScreen(context: viewModel.context)
        }
    }
}
