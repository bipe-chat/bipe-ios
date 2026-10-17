//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import CryptoKit
import Foundation

/// Verifies signed badge envelopes (bipe-shared/docs/badge-attestation.md, v1).
/// Must match bipe-shared/test-vectors/badges.json.
public nonisolated struct BadgeVerifier: Sendable {
    public enum KeyError: Error, Equatable {
        case invalidPublicKey(kid: String)
    }
    
    private let trustedKeys: [String: Data]
    
    /// - Parameter trustedKeys: `kid` to raw 32-byte Ed25519 public key. Release builds must not include `test-only-*` keys.
    public init(trustedKeys: [String: Data]) throws(KeyError) {
        for (kid, key) in trustedKeys where (try? Curve25519.Signing.PublicKey(rawRepresentation: key)) == nil {
            throw .invalidPublicKey(kid: kid)
        }
        self.trustedKeys = trustedKeys
    }
    
    /// Decodes and verifies envelope JSON. Undecodable JSON is `malformed`.
    public func verify(envelopeJSON: Data, sender: String, senderDevice: String, now: Date = .now) -> BadgeVerificationResult {
        // Check `v` before the full shape: a future version may have other fields.
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: envelopeJSON) else {
            return .invalid(.malformed)
        }
        guard probe.v == BadgeEnvelope.supportedVersion else {
            return .invalid(.unsupportedVersion)
        }
        guard let envelope = try? JSONDecoder().decode(BadgeEnvelope.self, from: envelopeJSON) else {
            return .invalid(.malformed)
        }
        return verify(envelope, sender: sender, senderDevice: senderDevice, now: now)
    }
    
    /// Runs the documented checks in order and returns the first failure.
    public func verify(_ envelope: BadgeEnvelope, sender: String, senderDevice: String, now: Date = .now) -> BadgeVerificationResult {
        guard envelope.v == BadgeEnvelope.supportedVersion else {
            return .invalid(.unsupportedVersion)
        }
        guard let keyData = trustedKeys[envelope.kid],
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            return .invalid(.unknownKID)
        }
        // Undecodable base64url is not a signature over any payload bytes, so it fails closed as malformed.
        guard let payloadBytes = Data(base64URLEncoded: envelope.payload),
              let signature = Data(base64URLEncoded: envelope.sig) else {
            return .invalid(.malformed)
        }
        // Verify the exact bytes. Never re-serialise the JSON before this check.
        guard publicKey.isValidSignature(signature, for: payloadBytes) else {
            return .invalid(.invalidSignature)
        }
        guard let payload = try? JSONDecoder().decode(BadgePayload.self, from: payloadBytes) else {
            return .invalid(.malformed)
        }
        
        let nowSeconds = now.timeIntervalSince1970
        if nowSeconds >= Double(payload.exp) {
            return .invalid(.expired)
        }
        if nowSeconds < Double(payload.iat) {
            return .invalid(.notYetValid)
        }
        guard payload.sub == sender else {
            return .invalid(.subjectMismatch)
        }
        guard payload.dev == senderDevice else {
            return .invalid(.deviceMismatch)
        }
        return .valid(payload)
    }
}

public nonisolated struct BadgeEnvelope: Sendable, Equatable, Codable {
    public static let supportedVersion = 1
    
    public let v: Int
    public let kid: String
    /// base64url without padding: the UTF-8 JSON payload bytes.
    public let payload: String
    /// base64url without padding: Ed25519 signature over the decoded payload bytes.
    public let sig: String
    
    public init(v: Int, kid: String, payload: String, sig: String) {
        self.v = v
        self.kid = kid
        self.payload = payload
        self.sig = sig
    }
}

public nonisolated enum BadgeLevel: String, Sendable, Codable {
    case pix
    case govbr
    case institution
}

public nonisolated struct BadgePayload: Sendable, Equatable, Decodable {
    /// Matrix user ID.
    public let sub: String
    public let lvl: BadgeLevel
    /// Verified legal name or institution name.
    public let name: String
    /// Institution CNPJ, digits only. Present only for `institution`.
    public let cnpj: String?
    /// Fingerprint of the device key the badge is bound to.
    public let dev: String
    /// Issued at, Unix seconds.
    public let iat: Int64
    /// Expires at, Unix seconds.
    public let exp: Int64
    
    private enum CodingKeys: String, CodingKey {
        case sub, lvl, name, cnpj, dev, iat, exp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sub = try container.decode(String.self, forKey: .sub)
        lvl = try container.decode(BadgeLevel.self, forKey: .lvl)
        name = try container.decode(String.self, forKey: .name)
        cnpj = try container.decodeIfPresent(String.self, forKey: .cnpj)
        dev = try container.decode(String.self, forKey: .dev)
        iat = try container.decode(Int64.self, forKey: .iat)
        exp = try container.decode(Int64.self, forKey: .exp)
        if lvl == .institution, cnpj == nil {
            throw DecodingError.keyNotFound(CodingKeys.cnpj, .init(codingPath: [], debugDescription: "institution badge without cnpj"))
        }
    }
}

public nonisolated enum BadgeVerificationResult: Sendable, Equatable {
    case valid(BadgePayload)
    case invalid(BadgeVerificationFailure)
}

/// Raw values are the codes in badge-attestation.md and test-vectors/badges.json.
public nonisolated enum BadgeVerificationFailure: String, Sendable, Equatable, Error {
    case unsupportedVersion = "unsupported_version"
    case unknownKID = "unknown_kid"
    case invalidSignature = "invalid_signature"
    case malformed
    case expired
    case notYetValid = "not_yet_valid"
    case subjectMismatch = "subject_mismatch"
    case deviceMismatch = "device_mismatch"
}

// MARK: - Private

private nonisolated struct VersionProbe: Decodable {
    let v: Int
}

private nonisolated extension Data {
    /// Strict base64url without padding (RFC 4648 section 5). Rejects padding and the standard alphabet.
    init?(base64URLEncoded string: String) {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        guard string.allSatisfy(allowed.contains), string.count % 4 != 1 else {
            return nil
        }
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))
        self.init(base64Encoded: base64)
    }
}
