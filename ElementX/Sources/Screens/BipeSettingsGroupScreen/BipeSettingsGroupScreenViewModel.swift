//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeSettingsGroupScreenViewModelType = StateStoreViewModelV2<BipeSettingsGroupScreenViewState, BipeSettingsGroupScreenViewAction>

/// Bipe: the values of one settings group (ADR 0112). Rows come from the registry; this reads and writes what they show.
class BipeSettingsGroupScreenViewModel: BipeSettingsGroupScreenViewModelType, BipeSettingsGroupScreenViewModelProtocol {
    private let userSession: UserSessionProtocol
    private let appLockService: AppLockServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let apiClient: BipeAPIClient

    private var clientProxy: ClientProxyProtocol {
        userSession.clientProxy
    }

    private var appSettings: AppSettings {
        userSession.userSettings.app
    }

    private let actionsSubject: PassthroughSubject<BipeSettingsGroupScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeSettingsGroupScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(group: BipeSettingsGroup,
         userSession: UserSessionProtocol,
         appLockService: AppLockServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.userSession = userSession
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController
        apiClient = BipeAPIClient(baseURL: userSession.userSettings.app.bipeAPIBaseURL)

        let appSettings = userSession.userSettings.app
        super.init(initialViewState: BipeSettingsGroupScreenViewState(group: group,
                                                                      isBipeAccount: userSession.clientProxy.userIDServerName == appSettings.bipeSignupServerName),
                   mediaProvider: userSession.mediaProvider)

        appSettings.linkNewDeviceEnabledPublisher
            .sink { [weak self] enabled in
                if enabled {
                    self?.state.flags.insert("linkNewDevice")
                } else {
                    self?.state.flags.remove("linkNewDevice")
                }
            }
            .store(in: &cancellables)

        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in self?.state.displayName = profile.displayName }
            .store(in: &cancellables)
    }

    override func process(viewAction: BipeSettingsGroupScreenViewAction) {
        switch viewAction {
        case .reload:
            reload()
        case .open(let row):
            actionsSubject.send(.open(row))
        }
    }

    private func reload() {
        guard state.isBipeAccount else { return }
        switch state.group {
        case .profile:
            Task { await loadProfile() }
        case .privacy, .account, .notifications, .chats, .help:
            break
        }
    }

    // MARK: - Seu perfil

    private func loadProfile() async {
        do {
            state.handle = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyHandle in
                try await apiClient.myHandle(accessToken: token)
            }.handle
        } catch {
            MXLog.error("Bipe handle load failed: \(error)")
        }
        do {
            state.publicProfileEnabled = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                try await apiClient.myProfile(accessToken: token)
            }.enabled
        } catch {
            MXLog.error("Bipe public profile load failed: \(error)")
        }
    }

    // MARK: - Private

    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
}
