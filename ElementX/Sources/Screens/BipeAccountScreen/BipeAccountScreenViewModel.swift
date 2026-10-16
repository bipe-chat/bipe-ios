//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import LocalAuthentication
import SwiftUI

typealias BipeAccountScreenViewModelType = StateStoreViewModelV2<BipeAccountScreenViewState, BipeAccountScreenViewAction>

/// The PIN and the recovery email of a device-first account (ADR 0057). A beta account (email and own password)
/// sets its first PIN here and moves to a hidden password (`POST /v1/me/device-first`).
class BipeAccountScreenViewModel: BipeAccountScreenViewModelType, BipeAccountScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let appLockService: AppLockServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let credentialStore = BipeCredentialStore.bipeApp

    private let actionsSubject: PassthroughSubject<BipeAccountScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeAccountScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(mode: BipeAccountScreenMode,
         apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         appLockService: AppLockServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.appLockService = appLockService
        self.userIndicatorController = userIndicatorController

        super.init(initialViewState: BipeAccountScreenViewState(mode: mode))

        Task {
            await load()
            // Bipe (ADR 0112): "Trocar senha" in Sua conta goes straight to the check and the form.
            if mode == .pin { await verifyDeviceOwnerThenEditPIN() }
        }
    }

    override func process(viewAction: BipeAccountScreenViewAction) {
        switch viewAction {
        case .editPIN:
            Task { await verifyDeviceOwnerThenEditPIN() }
        case .pinChanged:
            let pin = BipePIN.sanitize(state.bindings.pin)
            if pin != state.bindings.pin { state.bindings.pin = pin }
            let confirmation = BipePIN.sanitize(state.bindings.pinConfirmation)
            if confirmation != state.bindings.pinConfirmation { state.bindings.pinConfirmation = confirmation }
        case .savePIN:
            Task { await savePIN() }
        case .cancelPIN:
            closePINForm()
        case .saveEmail:
            Task { await saveEmail() }
        case .removeEmail:
            state.bindings.alertInfo = AlertInfo(id: .removeEmail,
                                                 title: BipeStrings.emailRemove,
                                                 message: BipeStrings.emailFooter,
                                                 primaryButton: .init(title: BipeStrings.emailRemove, role: .destructive) { [weak self] in
                                                     Task { await self?.removeEmail() }
                                                 },
                                                 secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
        }
    }

    // MARK: - Private

    private func load() async {
        defer { state.isLoading = false }
        do {
            state.status = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeAccountStatus in
                try await apiClient.account(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe account state load failed: \(error)")
            show(error)
        }
    }

    /// ADR 0057: a signed-in device changes the PIN after a biometric check (or the device passcode). No old PIN.
    private func verifyDeviceOwnerThenEditPIN() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            MXLog.error("Bipe PIN change: device owner check unavailable: \(error?.localizedDescription ?? "")")
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: BipeStrings.pinChangeBiometricReason)
            return
        }
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: BipeStrings.pinChangeBiometricReason) else { return }
        } catch {
            MXLog.info("Bipe PIN change: device owner check cancelled or failed")
            return
        }
        state.bindings.pin = ""
        state.bindings.pinConfirmation = ""
        state.isEditingPIN = true
    }

    private func savePIN() async {
        guard state.canSavePIN else { return }
        let pin = state.bindings.pin
        let isBetaAccount = state.isBetaAccount

        startLoading()
        defer { stopLoading() }

        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.setPIN(pin, accessToken: token)
            }
            if isBetaAccount {
                let credentials = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeCredentials in
                    try await apiClient.moveToDeviceFirst(accessToken: token)
                }
                credentialStore.save(credentials)
                MXLog.info("Bipe: moved \(credentials.userId) to device-first")
            } else if credentialStore.recoveryToken() == nil {
                // A device-first account whose token never reached this Apple account: issue one and sync it.
                let token = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> String in
                    try await apiClient.newRecoveryToken(accessToken: token)
                }
                credentialStore.saveRecoveryToken(token, for: clientProxy.userID)
            }
            appLockService.bipeUseAccountPIN(pin)
            closePINForm()
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.pinChanged, icon: \.checkCircle))
            actionsSubject.send(.done)
        } catch {
            MXLog.error("Bipe PIN save failed: \(error)")
            show(error)
        }
    }

    private func closePINForm() {
        state.isEditingPIN = false
        state.bindings.pin = ""
        state.bindings.pinConfirmation = ""
    }

    private func saveEmail() async {
        guard state.canSaveEmail else { return }
        let email = state.bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)

        startLoading()
        defer { stopLoading() }

        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.setRecoveryEmail(email, accessToken: token)
            }
            state.emailSentTo = email
            state.bindings.email = ""
            await load()
        } catch {
            MXLog.error("Bipe recovery email save failed: \(error)")
            show(error)
        }
    }

    private func removeEmail() async {
        startLoading()
        defer { stopLoading() }

        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.removeRecoveryEmail(accessToken: token)
            }
            state.emailSentTo = nil
            await load()
        } catch {
            MXLog.error("Bipe recovery email removal failed: \(error)")
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

    private let loadingIndicatorID = "\(BipeAccountScreenViewModel.self)-Loading"

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
