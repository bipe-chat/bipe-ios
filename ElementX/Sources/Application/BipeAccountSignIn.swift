//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Signs in to a device-first account with its hidden password (ADR 0057, ADR 0059). No browser opens.
///
/// MAS advertises OAuth, but it also runs the Matrix compatibility layer (`passwords.enabled: true`).
/// `AuthenticationService.login(username:password:…)` calls the SDK's `Client.login`, which posts
/// `m.login.password` to `/_matrix/client/v3/login` directly. The SDK does not force OAuth for that call;
/// the server's OAuth support only decides what Element's own login screens offer.
@MainActor
struct BipeAccountSignIn {
    let authenticationService: AuthenticationServiceProtocol
    let appSettings: AppSettings
    let credentialStore: BipeCredentialStore
    
    init(authenticationService: AuthenticationServiceProtocol, appSettings: AppSettings) {
        self.authenticationService = authenticationService
        self.appSettings = appSettings
        credentialStore = .bipeApp
    }
    
    /// Keeps the credentials (password on this device, token synced) and signs in with them.
    func signIn(with credentials: BipeCredentials) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        // A pending sign-up stays until the caller has signed in and set the app lock: it holds the PIN, and
        // POST /v1/signup/resume can still return these credentials if the keychain lost them (ADR 0094).
        if !credentialStore.save(credentials) {
            MXLog.error("Bipe: the keychain did not keep the password of \(credentials.userId)")
        }
        return await signIn(userID: credentials.userId, password: credentials.password)
    }
    
    /// Finishes a sign-up whose answer never reached this device (ADR 0094). `nil` when there is nothing to finish.
    func resumePendingSignup(apiClient: BipeAPIClient) async -> Result<UserSessionProtocol, AuthenticationServiceError>? {
        guard let pending = credentialStore.pendingSignup() else { return nil }
        do {
            let response = try await apiClient.resumeSignup(signupKey: pending.key)
            guard let credentials = response.credentials else { return nil }
            MXLog.info("Bipe: finishing the sign-up of \(response.userId)")
            return await signIn(with: credentials)
        } catch .server(.notFound, _, _) {
            credentialStore.deletePendingSignup()
            return nil
        } catch {
            MXLog.error("Bipe: could not resume a pending sign-up: \(error)")
            return nil
        }
    }
    
    /// Signs in with the password stored on this device. `nil` when there is none.
    func signInWithStoredPassword() async -> Result<UserSessionProtocol, AuthenticationServiceError>? {
        guard let stored = credentialStore.password() else { return nil }
        MXLog.info("Bipe: signing in \(stored.userID) with the password stored on this device")
        let result = await signIn(userID: stored.userID, password: stored.secret)
        if case .failure(.invalidCredentials) = result {
            // A token recovery on another device set a new password. The token path is next.
            credentialStore.deletePassword(for: stored.userID)
        }
        return result
    }
    
    private func signIn(userID: String, password: String) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        if case .failure(let error) = await authenticationService.configure(for: appSettings.defaultAccountProvider.serverNameOrBaseURL, flow: .login) {
            return .failure(error)
        }
        return await authenticationService.login(username: userID, password: password, initialDeviceName: nil, deviceID: nil)
    }
}

extension BipeCredentialStore {
    /// The store in the app's keychain access group.
    static var bipeApp: BipeCredentialStore {
        BipeCredentialStore(accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier)
    }
}

/// Bipe: the device PIN locks the app and belongs to the phone, not to an account (ADR 0086).
enum BipeDevicePIN {
    /// The device PIN follows the account PIN while the phone holds one account, so a one-account user keeps one PIN.
    static var followsAccountPIN: Bool {
        KeychainController(service: .sessions, accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier).restorationTokens().count <= 1
    }
}

extension AppLockServiceProtocol {
    /// Bipe: an account PIN the user just typed or set becomes the device PIN (ADR 0057) while it follows the account PIN,
    /// or when no app lock is set yet (ADR 0086). Biometric unlock stays on when the device supports it.
    func bipeUseAccountPIN(_ pin: String) {
        guard BipeDevicePIN.followsAccountPIN || !isEnabled else { return }
        guard case .success = setupPINCode(pin) else {
            MXLog.error("Bipe: could not use the account PIN for the app lock")
            return
        }
        if biometryType != .none {
            _ = enableBiometricUnlock()
        }
    }
}
