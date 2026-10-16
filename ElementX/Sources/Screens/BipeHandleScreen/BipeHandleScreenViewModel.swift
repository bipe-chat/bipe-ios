//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeHandleScreenViewModelType = StateStoreViewModelV2<BipeHandleScreenViewState, BipeHandleScreenViewAction>

class BipeHandleScreenViewModel: BipeHandleScreenViewModelType, BipeHandleScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let handleResolver: BipeHandleResolver?
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let handleChecker: BipeHandleAvailabilityChecker
    
    private let actionsSubject: PassthroughSubject<BipeHandleScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeHandleScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         handleResolver: BipeHandleResolver? = nil,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.handleResolver = handleResolver
        self.userIndicatorController = userIndicatorController
        handleChecker = BipeHandleAvailabilityChecker(apiClient: apiClient)
        
        super.init(initialViewState: BipeHandleScreenViewState())
        
        Task { await loadHandle() }
    }
    
    override func process(viewAction: BipeHandleScreenViewAction) {
        switch viewAction {
        case .handleChanged:
            state.handleError = nil
            let handle = BipeHandle.sanitize(state.bindings.handle)
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
        case .removeHandle:
            guard let handle = state.currentHandle else { return }
            state.bindings.alertInfo = AlertInfo(id: .removeHandle,
                                                 title: BipeStrings.handleRemove,
                                                 message: BipeStrings.handleRemoveBody(handle),
                                                 primaryButton: .init(title: BipeStrings.handleRemove, role: .destructive) { [weak self] in
                                                     Task { await self?.removeHandle() }
                                                 },
                                                 secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
        }
    }
    
    // MARK: - Private
    
    private func loadHandle() async {
        defer { state.isLoading = false }
        
        do {
            let myHandle = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyHandle in
                try await apiClient.myHandle(accessToken: token)
            }
            apply(myHandle)
        } catch {
            MXLog.error("Bipe handle load failed: \(error)")
            show(error)
        }
    }
    
    private func save() async {
        guard state.canSave else { return }
        
        let handle = BipeHandle.sanitize(state.bindings.handle)
        state.isLoading = true
        startLoading()
        defer {
            stopLoading()
            state.isLoading = false
        }
        
        do {
            let myHandle = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyHandle in
                try await apiClient.setMyHandle(handle, accessToken: token)
            }
            apply(myHandle)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.handleSaved, icon: \.checkCircle))
            actionsSubject.send(.done)
        } catch {
            MXLog.error("Bipe handle change failed: \(error)")
            show(error)
        }
    }
    
    /// `DELETE /v1/me/handle` (ADR 0066). The cooldown stays.
    private func removeHandle() async {
        guard state.canRemove else { return }
        
        state.isLoading = true
        startLoading()
        defer {
            stopLoading()
            state.isLoading = false
        }
        
        do {
            let myHandle = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyHandle in
                try await apiClient.removeMyHandle(accessToken: token)
            }
            apply(myHandle)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.handleRemoveDone, icon: \.checkCircle))
            actionsSubject.send(.done)
        } catch {
            MXLog.error("Bipe handle removal failed: \(error)")
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func apply(_ myHandle: BipeMyHandle) {
        state.currentHandle = myHandle.handle
        state.changeableAt = myHandle.changeableAt
        state.bindings.handle = myHandle.handle ?? ""
        state.handleStatus = .empty
        handleResolver?.store(handle: myHandle.handle, for: myHandle.userId)
    }
    
    private func show(_ error: BipeAPIError) {
        switch error {
        case .server(.handleTaken, _, _), .server(.handleInvalid, _, _), .server(.handleCooldown, _, _):
            state.handleError = error.localizedMessage
        default:
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(BipeHandleScreenViewModel.self)-Loading"
    
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
