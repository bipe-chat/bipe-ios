//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import BipeKit
import SwiftUI

typealias BipeInvitesScreenViewModelType = StateStoreViewModelV2<BipeInvitesScreenViewState, BipeInvitesScreenViewAction>

class BipeInvitesScreenViewModel: BipeInvitesScreenViewModelType, BipeInvitesScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let store: BipeInviteStore
    private let creator: BipeInviteCreator
    
    private let actionsSubject: PassthroughSubject<BipeInvitesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeInvitesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController
        store = BipeInviteStore(userID: clientProxy.userID)
        creator = BipeInviteCreator(apiClient: apiClient, userID: clientProxy.userID) { [clientProxy] in clientProxy.accessToken }
        
        var initialState = BipeInvitesScreenViewState()
        initialState.shareURLs = store.links()
        initialState.names = store.names()
        super.init(initialViewState: initialState)
        
        Task { await load() }
    }
    
    override func process(viewAction: BipeInvitesScreenViewAction) {
        switch viewAction {
        case .inviteByLink:
            Task {
                guard let link = await create() else { return }
                state.bindings.shareSheetLink = link
            }
        case .inviteInPerson:
            Task {
                guard let link = await create() else { return }
                state.bindings.qrCodeLink = link
            }
        case .share(let inviteID):
            state.bindings.shareSheetLink = link(for: inviteID)
        case .showQRCode(let inviteID):
            state.bindings.qrCodeLink = link(for: inviteID)
        case .startNaming(let inviteID):
            state.bindings.nameDraft = state.names[inviteID] ?? ""
            state.bindings.namingInviteID = inviteID
        case .saveName:
            guard let inviteID = state.bindings.namingInviteID else { return }
            store.saveName(state.bindings.nameDraft, forInviteID: inviteID)
            state.names = store.names()
            state.bindings.namingInviteID = nil
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
            let myInvites = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
            state.quota = myInvites.quota
            state.available = myInvites.available
            state.nextAvailableAt = myInvites.nextAvailableAt
            state.invites = myInvites.invites
            // Forget links of invites that can no longer be used; the list itself shows who joined.
            let pendingIDs = Set(myInvites.invites.filter { $0.status == .pending }.map(\.id))
            store.keepLinks(forPendingInviteIDs: pendingIDs)
            state.shareURLs = state.shareURLs.filter { pendingIDs.contains($0.key) }
            store.keepNames(forInviteIDs: Set(myInvites.invites.map(\.id)))
            state.names = store.names()
            let joinedIDs = Set(myInvites.invites.filter { $0.status == .used }.map(\.id))
            store.setSeenJoinedInviteIDs((store.seenJoinedInviteIDs() ?? []).union(joinedIDs))
        } catch {
            MXLog.error("Bipe invites load failed: \(error)")
            show(error)
        }
    }
    
    /// Creates an invite and returns its link, so the caller can open the share sheet or the QR code at once.
    private func create() async -> BipeInviteShareLink? {
        guard state.canCreate else { return nil }
        
        startLoading()
        defer { stopLoading() }
        
        do {
            let created = try await creator.create()
            MXLog.info("Bipe invite created \(created)")
            state.shareURLs[created.id] = created.url
            await load()
            return BipeInviteShareLink(id: created.id, url: created.url)
        } catch {
            MXLog.error("Bipe invite creation failed: \(error)")
            show(error)
            return nil
        }
    }
    
    private func link(for inviteID: String) -> BipeInviteShareLink? {
        state.shareURLs[inviteID].map { BipeInviteShareLink(id: inviteID, url: $0) }
    }
    
    private func revoke(_ inviteID: String) async {
        startLoading()
        defer { stopLoading() }
        
        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.revokeInvite(id: inviteID, accessToken: token)
            }
            state.shareURLs[inviteID] = nil
            await load()
        } catch {
            MXLog.error("Bipe invite revoke failed: \(error)")
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    private func show(_ error: BipeAPIError) {
        state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(BipeInvitesScreenViewModel.self)-Loading"
    
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
