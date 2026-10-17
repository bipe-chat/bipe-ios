//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Security

/// Keychain storage for a device-first account (ADR 0057, ADR 0059). Nothing here is ever shown to the user or logged.
///
/// - The hidden MAS password stays on this device: `AfterFirstUnlockThisDeviceOnly`, never synced, not in backups.
/// - The recovery token syncs through iCloud Keychain (`kSecAttrSynchronizable`). On a new phone the token and the PIN
///   get a new password from the API (`POST /v1/recovery/token`). The token alone gives no access.
/// - A pending email recovery (its claim secret) stays on this device.
public nonisolated struct BipeCredentialStore: Sendable {
    /// A credential and the account it belongs to.
    public struct Item: Sendable, Equatable, CustomStringConvertible {
        public let userID: String
        public let secret: String
        
        /// Never prints the secret.
        public var description: String {
            "BipeCredentialStore.Item(\(userID))"
        }
    }
    
    private let accessGroup: String?
    
    private enum Service: String {
        case password = "chat.bipe.account.password"
        case recoveryToken = "chat.bipe.account.recovery-token"
        case pendingRecovery = "chat.bipe.account.pending-recovery"
        case pendingSignup = "chat.bipe.account.pending-signup"
    }
    
    /// A sign-up whose credentials are not stored yet (ADR 0094). The key makes a retry return the same account.
    /// The PIN is the one the first try sent, so the app lock gets the PIN the account really has.
    public struct PendingSignup: Codable, Sendable, Equatable, CustomStringConvertible {
        public let key: String
        public var pin: String?
        
        /// Never prints the key or the PIN.
        public var description: String {
            "PendingSignup"
        }
    }
    
    /// `accessGroup`: the app's keychain access group. `nil` uses the first group in the entitlements.
    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }
    
    // MARK: - Credentials
    
    /// Stores the password on this device and syncs the token. Replaces what was stored before.
    /// `false` when the password cannot be read back: keep any pending sign-up, it is the only other copy.
    @discardableResult
    public func save(_ credentials: BipeCredentials) -> Bool {
        write(.password, account: credentials.userId, value: Data(credentials.password.utf8), synchronizable: false)
        saveRecoveryToken(credentials.recoveryToken, for: credentials.userId)
        return password() == Item(userID: credentials.userId, secret: credentials.password)
    }
    
    public func saveRecoveryToken(_ token: String, for userID: String) {
        write(.recoveryToken, account: userID, value: Data(token.utf8), synchronizable: true)
    }
    
    /// The password stored on this device, if any.
    public func password() -> Item? {
        read(.password).flatMap { item in String(data: item.data, encoding: .utf8).map { Item(userID: item.account, secret: $0) } }
    }
    
    /// The recovery token, from this device or synced from another device of the same Apple account.
    public func recoveryToken() -> Item? {
        read(.recoveryToken).flatMap { item in String(data: item.data, encoding: .utf8).map { Item(userID: item.account, secret: $0) } }
    }
    
    /// After an explicit sign-out: the next sign-in on this device needs the token and the PIN.
    public func deletePassword() {
        delete(.password)
    }
    
    /// After the API rejected the token (`recovery_invalid`).
    public func deleteRecoveryToken() {
        delete(.recoveryToken)
    }
    
    // MARK: - Pending sign-up
    
    /// The pending sign-up, or a new one with a fresh key. A new one is stored before the first request goes out.
    public func pendingSignup(pin: String?) -> PendingSignup {
        if let pending = pendingSignup() {
            return pending
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("SecRandomCopyBytes failed")
        }
        let key = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let pending = PendingSignup(key: key, pin: pin)
        savePendingSignup(pending)
        return pending
    }
    
    public func pendingSignup() -> PendingSignup? {
        read(.pendingSignup).flatMap { try? Self.decoder.decode(PendingSignup.self, from: $0.data) }
    }
    
    /// After the server said it made nothing (a 4xx answer): the next try may send a different PIN.
    public func updatePendingSignupPIN(_ pin: String?) {
        guard var pending = pendingSignup() else { return }
        pending.pin = pin
        savePendingSignup(pending)
    }
    
    public func deletePendingSignup() {
        delete(.pendingSignup)
    }
    
    private func savePendingSignup(_ pending: PendingSignup) {
        guard let data = try? Self.encoder.encode(pending) else { return }
        write(.pendingSignup, account: "pending", value: data, synchronizable: false)
    }
    
    // MARK: - Pending recovery
    
    public func savePendingRecovery(_ recovery: BipeRecoveryStarted) {
        guard let data = try? Self.encoder.encode(recovery) else { return }
        write(.pendingRecovery, account: "pending", value: data, synchronizable: false)
    }
    
    public func pendingRecovery() -> BipeRecoveryStarted? {
        read(.pendingRecovery).flatMap { try? Self.decoder.decode(BipeRecoveryStarted.self, from: $0.data) }
    }
    
    public func deletePendingRecovery() {
        delete(.pendingRecovery)
    }
    
    // MARK: - Private
    
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private func baseQuery(_ service: Service) -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service.rawValue,
                                    // Finds synced and local items alike.
                                    kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    
    /// One item per service: a new account replaces the old one.
    private func write(_ service: Service, account: String, value: Data, synchronizable: Bool) {
        delete(service)
        var item = baseQuery(service)
        item[kSecAttrAccount as String] = account
        item[kSecValueData as String] = value
        item[kSecAttrSynchronizable as String] = synchronizable ? kCFBooleanTrue : kCFBooleanFalse
        // A synchronizable item cannot use a ThisDeviceOnly class.
        item[kSecAttrAccessible as String] = synchronizable ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("Bipe keychain write failed for \(service.rawValue): \(status)")
        }
    }
    
    private func read(_ service: Service) -> (account: String, data: Data)? {
        var query = baseQuery(service)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any],
              let account = attributes[kSecAttrAccount as String] as? String,
              let data = attributes[kSecValueData as String] as? Data else { return nil }
        return (account, data)
    }
    
    private func delete(_ service: Service) {
        SecItemDelete(baseQuery(service) as CFDictionary)
    }
}
