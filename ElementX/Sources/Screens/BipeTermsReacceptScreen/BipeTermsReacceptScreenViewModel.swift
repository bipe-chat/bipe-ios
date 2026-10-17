//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeTermsReacceptScreenViewModelType = StateStoreViewModelV2<BipeTermsReacceptScreenViewState, BipeTermsReacceptScreenViewAction>

/// Asks an account without the current terms version to accept it (ADR 0113, bipe#366). `POST /v1/me/terms`.
class BipeTermsReacceptScreenViewModel: BipeTermsReacceptScreenViewModelType, BipeTermsReacceptScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol

    private let actionsSubject: PassthroughSubject<BipeTermsReacceptScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeTermsReacceptScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(apiClient: BipeAPIClient, clientProxy: ClientProxyProtocol, site: URL) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        super.init(initialViewState: BipeTermsReacceptScreenViewState(termsURL: BipeLegalLinks.termsURL(site: site),
                                                                      privacyURL: BipeLegalLinks.privacyURL(site: site)))
    }

    override func process(viewAction: BipeTermsReacceptScreenViewAction) {
        switch viewAction {
        case .continue:
            Task { await accept() }
        }
    }

    // MARK: - Private

    private func accept() async {
        guard state.canContinue else { return }
        state.isSaving = true
        state.isFailed = false
        defer { state.isSaving = false }

        do {
            try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.acceptTerms(version: BipeRegistries.legalVersion, accessToken: token)
            }
            actionsSubject.send(.accepted)
        } catch {
            MXLog.error("Bipe terms acceptance failed: \(error)")
            state.isFailed = true
        }
    }
}
