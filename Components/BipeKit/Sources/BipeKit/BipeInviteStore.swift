//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Security

/// On-device memory for personal invites, per account.
/// - Invite links: the server keeps only a hash of each code, so the link exists only where it was created.
///   Links are bearer secrets and live in the keychain.
/// - Seen joins: the invite IDs whose join the user was already told about. Not secret; UserDefaults.
public nonisolated struct BipeInviteStore {
    private let userID: String
    private let defaults: UserDefaults
    
    private static let keychainService = "chat.bipe.invites"
    
    public init(userID: String, defaults: UserDefaults = .standard) {
        self.userID = userID
        self.defaults = defaults
    }
    
    // MARK: - Links
    
    /// Links of invites created on this device, by invite ID.
    public func links() -> [String: URL] {
        guard let data = readKeychain(),
              let strings = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return strings.compactMapValues(URL.init(string:))
    }
    
    public func saveLink(_ url: URL, forInviteID id: String) {
        var current = links()
        current[id] = url
        writeLinks(current)
    }
    
    /// Drops links whose invite is no longer pending (used, expired or revoked).
    public func keepLinks(forPendingInviteIDs ids: Set<String>) {
        let current = links()
        let kept = current.filter { ids.contains($0.key) }
        if kept.count != current.count {
            writeLinks(kept)
        }
    }
    
    // MARK: - Names
    
    /// Names the person gave their invites, by invite ID. They stay on this device and never reach the server.
    public func names() -> [String: String] {
        defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
    }
    
    /// An empty name removes the entry.
    public func saveName(_ name: String, forInviteID id: String) {
        var current = names()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        current[id] = trimmed.isEmpty ? nil : trimmed
        defaults.set(current, forKey: namesKey)
    }
    
    /// Drops names of invites the server no longer lists.
    public func keepNames(forInviteIDs ids: Set<String>) {
        let current = names()
        let kept = current.filter { ids.contains($0.key) }
        if kept.count != current.count {
            defaults.set(kept, forKey: namesKey)
        }
    }
    
    // MARK: - Seen joins
    
    /// `nil` until the first check on this device, so the first check can mark old joins as seen without announcing them.
    public func seenJoinedInviteIDs() -> Set<String>? {
        defaults.stringArray(forKey: seenKey).map(Set.init)
    }
    
    public func setSeenJoinedInviteIDs(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: seenKey)
    }
    
    // MARK: - Invite pairs
    
    /// The last known invite pairs (ADR 0034), so trust works before the API answers. Not secret; UserDefaults.
    public func invitePairs() -> Set<String> {
        Set(defaults.stringArray(forKey: pairsKey) ?? [])
    }
    
    public func setInvitePairs(_ userIDs: Set<String>) {
        defaults.set(userIDs.sorted(), forKey: pairsKey)
    }
    
    // MARK: - Private
    
    private var seenKey: String {
        "bipe.invites.seenJoined.\(userID)"
    }
    
    private var namesKey: String {
        "bipe.invites.names.\(userID)"
    }
    
    private var pairsKey: String {
        "bipe.invites.pairs.\(userID)"
    }
    
    private func writeLinks(_ links: [String: URL]) {
        guard let data = try? JSONEncoder().encode(links.mapValues(\.absoluteString)) else { return }
        writeKeychain(data)
    }
    
    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.keychainService,
         kSecAttrAccount as String: userID]
    }
    
    private func readKeychain() -> Data? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private func writeKeychain(_ data: Data) {
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(keychainQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }
}
