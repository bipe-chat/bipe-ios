//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

typealias ProseioHandleScreenViewModelType = StateStoreViewModelV2<ProseioHandleScreenViewState, ProseioHandleScreenViewAction>

class ProseioHandleScreenViewModel: ProseioHandleScreenViewModelType, ProseioHandleScreenViewModelProtocol {
    private let apiClient: ProseioAPIClient
    private let clientProxy: ClientProxyProtocol
    private let handleResolver: ProseioHandleResolver?
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let handleChecker: ProseioHandleAvailabilityChecker
    
    private let actionsSubject: PassthroughSubject<ProseioHandleScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioHandleScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: ProseioAPIClient,
         clientProxy: ClientProxyProtocol,
         handleResolver: ProseioHandleResolver? = nil,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.handleResolver = handleResolver
        self.userIndicatorController = userIndicatorController
        handleChecker = ProseioHandleAvailabilityChecker(apiClient: apiClient)
        
        super.init(initialViewState: ProseioHandleScreenViewState())
        
        Task { await loadHandle() }
    }
    
    override func process(viewAction: ProseioHandleScreenViewAction) {
        switch viewAction {
        case .handleChanged:
            state.handleError = nil
            let handle = ProseioHandle.sanitize(state.bindings.handle)
            guard handle != state.currentHandle else {
                handleChecker.cancel()
                state.handleStatus = .empty
                return
            }
            handleChecker.check(handle) { [weak self] status in
                self?.state.handleStatus = status
            }
        case .save:
            Task { await save() }
        }
    }
    
    // MARK: - Private
    
    private func loadHandle() async {
        defer { state.isLoading = false }
        
        do {
            let myHandle = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioMyHandle in
                try await apiClient.myHandle(accessToken: token)
            }
            apply(myHandle)
        } catch {
            MXLog.error("Proseio handle load failed: \(error)")
            show(error)
        }
    }
    
    private func save() async {
        guard state.canSave else { return }
        
        let handle = ProseioHandle.sanitize(state.bindings.handle)
        state.isLoading = true
        startLoading()
        defer {
            stopLoading()
            state.isLoading = false
        }
        
        do {
            let myHandle = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioMyHandle in
                try await apiClient.setMyHandle(handle, accessToken: token)
            }
            apply(myHandle)
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.handleSaved, icon: \.checkCircle))
            actionsSubject.send(.done)
        } catch {
            MXLog.error("Proseio handle change failed: \(error)")
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
        try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func apply(_ myHandle: ProseioMyHandle) {
        state.currentHandle = myHandle.handle
        state.changeableAt = myHandle.changeableAt
        state.bindings.handle = myHandle.handle ?? ""
        state.handleStatus = .empty
        handleResolver?.store(handle: myHandle.handle, for: myHandle.userId)
    }
    
    private func show(_ error: ProseioAPIError) {
        switch error {
        case .server(.handleTaken, _, _), .server(.handleInvalid, _, _), .server(.handleCooldown, _, _):
            state.handleError = error.localizedMessage
        default:
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(ProseioHandleScreenViewModel.self)-Loading"
    
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
