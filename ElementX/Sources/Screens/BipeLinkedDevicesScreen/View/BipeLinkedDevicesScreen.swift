//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

struct BipeLinkedDevicesScreen: View {
    @Bindable var context: BipeLinkedDevicesScreenViewModel.Context
    
    var body: some View {
        Form {
            if context.viewState.showsLinkComputer {
                Section {
                    ListRow(label: .default(title: context.viewState.needsPIN ? BipeStrings.linkComputerCreatePin : BipeStrings.linkedDevicesLinkComputer,
                                            icon: context.viewState.needsPIN ? \.lock : \.computer),
                            details: .isWaiting(context.viewState.isCheckingSupport),
                            kind: .button { context.send(viewAction: .linkComputer) })
                        .disabled(context.viewState.isCheckingSupport)
                } footer: {
                    Text(context.viewState.needsPIN ? BipeStrings.linkComputerNeedsPin(String(BipeRegistries.pinLength)) : BipeStrings.linkedDevicesFooter)
                        .compoundListSectionFooter()
                }
            }
            
            if context.viewState.isLoading {
                Section {
                    ListRow(kind: .custom {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    })
                }
            } else if context.viewState.devices.isEmpty {
                Section {
                    ListRow(label: .plain(title: BipeStrings.linkedDevicesEmpty), kind: .label)
                }
            } else {
                ForEach(context.viewState.devices) { device in
                    deviceSection(device)
                }
            }
        }
        .compoundList()
        .navigationTitle(BipeStrings.linkedDevicesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.actionClose) {
                    context.send(viewAction: .dismiss)
                }
            }
        }
        .alert(item: $context.alertInfo)
    }
    
    private func deviceSection(_ device: BipeMatrixDevice) -> some View {
        Section {
            ListRow(label: .default(title: device.displayName ?? BipeStrings.linkedDevicesUnknownName,
                                    description: device.lastSeen.map { BipeStrings.linkedDevicesLastUsed($0.formatted(.relative(presentation: .named))) },
                                    icon: \.devices),
                    kind: .label)
            ListRow(label: .action(title: BipeStrings.linkedDevicesSignOut, icon: \.signOut, role: .destructive),
                    kind: .button { context.send(viewAction: .signOut(device)) })
        }
    }
}

// MARK: - Previews

struct BipeLinkedDevicesScreen_Previews: PreviewProvider {
    static let viewModel = BipeLinkedDevicesScreenViewModel(clientProxy: ClientProxyMock(.init(userID: "@alice:example.com")),
                                                            showsLinkComputer: true)
    
    static var previews: some View {
        ElementNavigationStack {
            BipeLinkedDevicesScreen(context: viewModel.context)
        }
    }
}
