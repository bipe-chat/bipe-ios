//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

typealias BipeMessagingScreenViewModelType = StateStoreViewModelV2<BipeMessagingScreenViewState, BipeMessagingScreenViewAction>

class BipeMessagingScreenViewModel: BipeMessagingScreenViewModelType, BipeMessagingScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    
    init(apiClient: BipeAPIClient, clientProxy: ClientProxyProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        
        super.init(initialViewState: BipeMessagingScreenViewState())
        
        Task { await load() }
    }
    
    override func process(viewAction: BipeMessagingScreenViewAction) {
        switch viewAction {
        case .select(let value):
            Task { await save(value) }
        }
    }
    
    // MARK: - Private
    
    private func load() async {
        defer { state.isLoading = false }
        
        do {
            state.selection = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeWhoCanMessage in
                try await apiClient.messagingSetting(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe messaging setting load failed: \(error)")
            show(error)
        }
    }
    
    private func save(_ value: BipeWhoCanMessage) async {
        guard !state.isDisabled, value != state.selection else { return }
        
        let previous = state.selection
        state.selection = value
        state.isSaving = true
        defer { state.isSaving = false }
        
        do {
            state.selection = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeWhoCanMessage in
                try await apiClient.setMessagingSetting(value, accessToken: token)
            }
        } catch {
            MXLog.error("Bipe messaging setting change failed: \(error)")
            state.selection = previous
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func show(_ error: BipeAPIError) {
        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
    }
}
