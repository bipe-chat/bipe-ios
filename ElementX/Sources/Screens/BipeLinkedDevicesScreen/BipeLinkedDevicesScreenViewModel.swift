//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeLinkedDevicesScreenViewModelType = StateStoreViewModelV2<BipeLinkedDevicesScreenViewState, BipeLinkedDevicesScreenViewAction>

/// Settings > Linked devices (ADR 0116): the other devices of the account with their last use and a sign-out, and
/// the only entry point to the QR scanner that links a computer.
class BipeLinkedDevicesScreenViewModel: BipeLinkedDevicesScreenViewModelType, BipeLinkedDevicesScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    
    private let actionsSubject: PassthroughSubject<BipeLinkedDevicesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeLinkedDevicesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(clientProxy: ClientProxyProtocol, showsLinkComputer: Bool) {
        self.clientProxy = clientProxy
        
        super.init(initialViewState: BipeLinkedDevicesScreenViewState(showsLinkComputer: showsLinkComputer))
        
        Task { await reload() }
    }
    
    override func process(viewAction: BipeLinkedDevicesScreenViewAction) {
        switch viewAction {
        case .linkComputer:
            Task { await linkComputer() }
        case .signOut(let device):
            let name = device.displayName ?? BipeStrings.linkedDevicesUnknownName
            state.bindings.alertInfo = AlertInfo(id: .signOut(device.deviceId),
                                                 title: BipeStrings.linkedDevicesSignOutTitle(name),
                                                 message: BipeStrings.linkedDevicesSignOutBody,
                                                 primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                                 secondaryButton: .init(title: BipeStrings.linkedDevicesSignOut, role: .destructive) { [weak self] in
                                                     self?.actionsSubject.send(.signOut(deviceID: device.deviceId))
                                                 })
        case .dismiss:
            actionsSubject.send(.dismiss)
        }
    }
    
    func reload() async {
        guard let homeserver = URL(string: clientProxy.homeserver), let accessToken = clientProxy.accessToken else {
            state.isLoading = false
            return
        }
        defer { state.isLoading = false }
        
        do {
            let devices = try await BipeMatrixAccountAPI(homeserver: homeserver).devices(accessToken: accessToken)
            state.devices = devices
                .filter { $0.deviceId != clientProxy.deviceID }
                .sorted { ($0.lastSeenTs ?? 0) > ($1.lastSeenTs ?? 0) }
        } catch {
            MXLog.error("Bipe linked devices: load failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: BipeStrings.linkedDevicesError)
        }
    }
    
    // MARK: - Private
    
    private func linkComputer() async {
        state.isCheckingSupport = true
        defer { state.isCheckingSupport = false }
        
        guard await clientProxy.isLoginWithQRCodeSupported else {
            state.bindings.alertInfo = AlertInfo(id: .notSupported, title: BipeStrings.linkComputerErrorTitle, message: BipeStrings.linkComputerNotSupported)
            return
        }
        actionsSubject.send(.linkComputer)
    }
}
