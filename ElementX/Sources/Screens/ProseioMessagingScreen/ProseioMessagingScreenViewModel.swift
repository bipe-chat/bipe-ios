//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

typealias ProseioMessagingScreenViewModelType = StateStoreViewModelV2<ProseioMessagingScreenViewState, ProseioMessagingScreenViewAction>

class ProseioMessagingScreenViewModel: ProseioMessagingScreenViewModelType, ProseioMessagingScreenViewModelProtocol {
    private let apiClient: ProseioAPIClient
    private let clientProxy: ClientProxyProtocol
    
    init(apiClient: ProseioAPIClient, clientProxy: ClientProxyProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        
        super.init(initialViewState: ProseioMessagingScreenViewState())
        
        Task { await load() }
    }
    
    override func process(viewAction: ProseioMessagingScreenViewAction) {
        switch viewAction {
        case .select(let value):
            Task { await save(value) }
        }
    }
    
    // MARK: - Private
    
    private func load() async {
        defer { state.isLoading = false }
        
        do {
            state.selection = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioWhoCanMessage in
                try await apiClient.messagingSetting(accessToken: token)
            }
        } catch {
            MXLog.error("Proseio messaging setting load failed: \(error)")
            show(error)
        }
    }
    
    private func save(_ value: ProseioWhoCanMessage) async {
        guard !state.isDisabled, value != state.selection else { return }
        
        let previous = state.selection
        state.selection = value
        state.isSaving = true
        defer { state.isSaving = false }
        
        do {
            state.selection = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioWhoCanMessage in
                try await apiClient.setMessagingSetting(value, accessToken: token)
            }
        } catch {
            MXLog.error("Proseio messaging setting change failed: \(error)")
            state.selection = previous
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
        try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func show(_ error: ProseioAPIError) {
        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
    }
}
