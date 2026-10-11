//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

typealias ProseioInvitesScreenViewModelType = StateStoreViewModelV2<ProseioInvitesScreenViewState, ProseioInvitesScreenViewAction>

class ProseioInvitesScreenViewModel: ProseioInvitesScreenViewModelType, ProseioInvitesScreenViewModelProtocol {
    private let apiClient: ProseioAPIClient
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let actionsSubject: PassthroughSubject<ProseioInvitesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioInvitesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: ProseioAPIClient,
         clientProxy: ClientProxyProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: ProseioInvitesScreenViewState())
        
        Task { await load() }
    }
    
    override func process(viewAction: ProseioInvitesScreenViewAction) {
        switch viewAction {
        case .create:
            Task { await create() }
        case .revoke(let inviteID):
            Task { await revoke(inviteID) }
        case .openUserProfile(let userID):
            actionsSubject.send(.openUserProfile(userID: userID))
        }
    }
    
    // MARK: - Private
    
    private func load() async {
        defer { state.isLoading = false }
        
        do {
            let myInvites = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
            state.quota = myInvites.quota
            state.available = myInvites.available
            state.invites = myInvites.invites
        } catch {
            MXLog.error("Proseio invites load failed: \(error)")
            show(error)
        }
    }
    
    private func create() async {
        guard state.canCreate else { return }
        
        startLoading()
        defer { stopLoading() }
        
        do {
            let created = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioCreatedInvite in
                try await apiClient.createInvite(accessToken: token)
            }
            MXLog.info("Proseio invite created \(created)")
            state.shareURLs[created.id] = created.url
            await load()
        } catch {
            MXLog.error("Proseio invite creation failed: \(error)")
            show(error)
        }
    }
    
    private func revoke(_ inviteID: String) async {
        startLoading()
        defer { stopLoading() }
        
        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) in
                try await apiClient.revokeInvite(id: inviteID, accessToken: token)
            }
            state.shareURLs[inviteID] = nil
            await load()
        } catch {
            MXLog.error("Proseio invite revoke failed: \(error)")
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
        try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func show(_ error: ProseioAPIError) {
        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(ProseioInvitesScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
}
