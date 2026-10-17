//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Client for the Bipe API. Contract: bipe-shared/api/openapi.yaml.
public struct BipeAPIClient: Sendable {
    public let baseURL: URL
    private let session: URLSession
    
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // MARK: - Sign-up
    
    /// `POST /v1/signup`. No auth.
    public func signup(_ request: BipeSignupRequest) async throws(BipeAPIError) -> BipeSignupResponse {
        try await send(method: "POST", path: ["v1", "signup"], body: request)
    }
    
    /// `GET /v1/signup/config`. No auth. The sign-up mode (ADR 0072).
    public func signupConfig() async throws(BipeAPIError) -> BipeSignupConfig {
        try await send(method: "GET", path: ["v1", "signup", "config"], body: Empty?.none)
    }
    
    /// `POST /v1/signup/resume`. No auth. The answer of an earlier sign-up with this key (ADR 0094); `not_found` when none.
    public func resumeSignup(signupKey: String) async throws(BipeAPIError) -> BipeSignupResponse {
        try await send(method: "POST", path: ["v1", "signup", "resume"], body: SignupResumeRequest(signupKey: signupKey))
    }
    
    /// `POST /v1/attest/challenge`. No auth. One-time App Attest challenge, valid 5 minutes.
    public func attestChallenge() async throws(BipeAPIError) -> String {
        let response: AttestChallengeResponse = try await send(method: "POST", path: ["v1", "attest", "challenge"], body: Empty?.none)
        return response.challenge
    }
    
    // MARK: - Terms (ADR 0113)
    
    /// `POST /v1/me/terms`. Records that the person ticked the box for this version. `version` must be ``BipeRegistries/legalVersion``.
    public func acceptTerms(version: String, accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "POST", path: ["v1", "me", "terms"], body: TermsAcceptance(termsVersion: version), accessToken: accessToken)
    }
    
    // MARK: - Device-first accounts (ADR 0057, ADR 0059)
    
    /// `GET /v1/me/account`. PIN state, recovery email and the recoveries of the last 7 days.
    public func account(accessToken: String) async throws(BipeAPIError) -> BipeAccountStatus {
        try await send(method: "GET", path: ["v1", "me", "account"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `PUT /v1/me/pin`. Set or change the PIN. The app checks the device owner first (biometrics).
    public func setPIN(_ pin: String, accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "PUT", path: ["v1", "me", "pin"], body: PINRequest(pin: pin), accessToken: accessToken)
    }
    
    /// `POST /v1/me/device-first`. Moves a beta account to a hidden password. Needs a PIN first.
    public func moveToDeviceFirst(accessToken: String) async throws(BipeAPIError) -> BipeCredentials {
        try await send(method: "POST", path: ["v1", "me", "device-first"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `POST /v1/me/recovery-token`. A new token; the old one stops working.
    public func newRecoveryToken(accessToken: String) async throws(BipeAPIError) -> String {
        let response: RecoveryTokenResponse = try await send(method: "POST", path: ["v1", "me", "recovery-token"], body: Empty?.none, accessToken: accessToken)
        return response.recoveryToken
    }
    
    /// `PUT /v1/me/email`. The server sends a link to confirm the address.
    public func setRecoveryEmail(_ email: String, accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "PUT", path: ["v1", "me", "email"],
                                          body: EmailRequest(email: email, lang: Self.emailLanguage),
                                          accessToken: accessToken)
    }
    
    /// `DELETE /v1/me/email`.
    public func removeRecoveryEmail(accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "DELETE", path: ["v1", "me", "email"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `POST /v1/me/recoveries/{id}/cancel`. An old device cancels a waiting recovery.
    public func cancelRecovery(id: String, accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "POST", path: ["v1", "me", "recoveries", id, "cancel"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `POST /v1/recovery/token`. No auth. The synced token, then the PIN. Returns new credentials once.
    public func recoverWithToken(_ token: String, pin: String) async throws(BipeAPIError) -> BipeCredentials {
        try await send(method: "POST", path: ["v1", "recovery", "token"], body: TokenRecoveryRequest(recoveryToken: token, pin: pin))
    }
    
    /// `POST /v1/recovery/email`. No auth. Always 202 for a well-formed address.
    public func requestRecoveryEmail(_ email: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "POST", path: ["v1", "recovery", "email"], body: RecoveryEmailRequest(email: email))
    }
    
    /// `POST /v1/recovery/email/confirm`. No auth. The link token and exactly one of `pin` (access) or `newPIN` (PIN reset).
    public func confirmRecoveryEmail(linkToken: String, pin: String?, newPIN: String?) async throws(BipeAPIError) -> BipeRecoveryStarted {
        try await send(method: "POST", path: ["v1", "recovery", "email", "confirm"],
                       body: EmailConfirmRequest(token: linkToken, pin: pin, newPin: newPIN))
    }
    
    /// `POST /v1/recovery/{id}/claim`. No auth. Polls a recovery; returns the credentials once when the delay has ended.
    public func claimRecovery(id: String, claimSecret: String) async throws(BipeAPIError) -> BipeRecoveryClaim {
        try await send(method: "POST", path: ["v1", "recovery", id, "claim"], body: ClaimRequest(claimSecret: claimSecret))
    }
    
    /// The `lang` for emails Bipe sends: English for English devices, else Portuguese (the app's fallback).
    public static var emailLanguage: String {
        Locale.preferredLanguages.first?.hasPrefix("en") == true ? "en" : "pt"
    }
    
    // MARK: - Handle changes (ADR 0066)
    
    /// `POST /v1/handle-changes`. At most ``BipeHandleChange/batchSize`` IDs. Oldest first.
    public func handleChanges(userIDs: [String], since: Date?, accessToken: String) async throws(BipeAPIError) -> [BipeHandleChange] {
        let response: HandleChangesResponse = try await send(method: "POST", path: ["v1", "handle-changes"],
                                                             body: HandleChangesRequest(userIds: userIDs, since: since.map(Self.formatDate)),
                                                             accessToken: accessToken)
        return response.changes
    }
    
    /// `DELETE /v1/me/handle`. Removes the caller's handle.
    public func removeMyHandle(accessToken: String) async throws(BipeAPIError) -> BipeMyHandle {
        try await send(method: "DELETE", path: ["v1", "me", "handle"], body: Empty?.none, accessToken: accessToken)
    }
    
    // MARK: - Invites
    
    /// `GET /v1/invites/{code}`. No auth. Validity and the inviter's handle.
    public func invitePreview(code: String) async throws(BipeAPIError) -> BipeInvitePreview {
        try await send(method: "GET", path: ["v1", "invites", code], body: Empty?.none)
    }
    
    /// `GET /v1/me/invites`.
    public func myInvites(accessToken: String) async throws(BipeAPIError) -> BipeMyInvites {
        try await send(method: "GET", path: ["v1", "me", "invites"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `POST /v1/me/invites`. The code is returned once.
    public func createInvite(accessToken: String) async throws(BipeAPIError) -> BipeCreatedInvite {
        try await send(method: "POST", path: ["v1", "me", "invites"], body: Empty?.none, accessToken: accessToken)
    }
    
    // MARK: - Phone-number discovery
    
    /// `POST /v1/contacts/lookup`. At most 500 numbers, already normalised with ``BipePhoneNumber``.
    public func lookupContacts(phones: [String], accessToken: String) async throws(BipeAPIError) -> [BipeContactMatch] {
        let response: LookupResponse = try await send(method: "POST", path: ["v1", "contacts", "lookup"], body: LookupRequest(phones: phones), accessToken: accessToken)
        return response.matches
    }
    
    /// `GET /v1/me/phone`. Status only, never the number.
    public func myPhone(accessToken: String) async throws(BipeAPIError) -> BipeMyPhone {
        try await send(method: "GET", path: ["v1", "me", "phone"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `PUT /v1/me/discovery`.
    public func setDiscoverableByPhone(_ value: Bool, accessToken: String) async throws(BipeAPIError) {
        let _: DiscoverySettings = try await send(method: "PUT", path: ["v1", "me", "discovery"], body: DiscoverySettings(byPhone: value), accessToken: accessToken)
    }
    
    /// `GET /v1/me/invite-connections`. The caller's invite pairs (ADR 0034).
    public func inviteConnections(accessToken: String) async throws(BipeAPIError) -> [String] {
        let response: InviteConnectionsResponse = try await send(method: "GET", path: ["v1", "me", "invite-connections"], body: Empty?.none, accessToken: accessToken)
        return response.userIds
    }
    
    /// `DELETE /v1/me/invites/{inviteId}`. Revokes a pending invite.
    public func revokeInvite(id: String, accessToken: String) async throws(BipeAPIError) {
        let _: NoContent = try await send(method: "DELETE", path: ["v1", "me", "invites", id], body: Empty?.none, accessToken: accessToken)
    }
    
    // MARK: - Messaging
    
    /// `GET /v1/me/messaging`. Who can message the caller.
    public func messagingSetting(accessToken: String) async throws(BipeAPIError) -> BipeWhoCanMessage {
        let response: MessagingSetting = try await send(method: "GET", path: ["v1", "me", "messaging"], body: Empty?.none, accessToken: accessToken)
        return response.whoCanMessage
    }
    
    /// `PUT /v1/me/messaging`. The server enforces it on invites.
    public func setMessagingSetting(_ value: BipeWhoCanMessage, accessToken: String) async throws(BipeAPIError) -> BipeWhoCanMessage {
        let response: MessagingSetting = try await send(method: "PUT", path: ["v1", "me", "messaging"], body: MessagingSetting(whoCanMessage: value), accessToken: accessToken)
        return response.whoCanMessage
    }
    
    // MARK: - Handles
    
    /// `GET /v1/handles/{handle}/availability`. No auth.
    public func handleAvailability(_ handle: String) async throws(BipeAPIError) -> BipeHandleAvailability {
        try await send(method: "GET", path: ["v1", "handles", handle, "availability"], body: Empty?.none)
    }
    
    /// `GET /v1/handles/{handle}`. Exact lookup.
    public func handle(_ handle: String, accessToken: String) async throws(BipeAPIError) -> BipeHandleRecord {
        try await send(method: "GET", path: ["v1", "handles", handle], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `POST /v1/handles/resolve`. Returns Matrix ID to handle. IDs without a handle are absent.
    public func resolveHandles(userIDs: [String], accessToken: String) async throws(BipeAPIError) -> [String: String] {
        let response: ResolveResponse = try await send(method: "POST",
                                                       path: ["v1", "handles", "resolve"],
                                                       body: ResolveRequest(userIds: userIDs),
                                                       accessToken: accessToken)
        return response.handles
    }
    
    /// `GET /v1/me/handle`.
    public func myHandle(accessToken: String) async throws(BipeAPIError) -> BipeMyHandle {
        try await send(method: "GET", path: ["v1", "me", "handle"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `PUT /v1/me/handle`.
    public func setMyHandle(_ handle: String, accessToken: String) async throws(BipeAPIError) -> BipeMyHandle {
        try await send(method: "PUT", path: ["v1", "me", "handle"], body: SetHandleRequest(handle: handle), accessToken: accessToken)
    }
    
    // MARK: - Public profiles
    
    /// `GET /v1/profiles/{handle}`. No auth. 404 for "no such handle" and for "profile off".
    public func publicProfile(handle: String) async throws(BipeAPIError) -> BipePublicProfile {
        try await send(method: "GET", path: ["v1", "profiles", handle], body: Empty?.none)
    }
    
    /// `GET /v1/me/profile`. A user who never saved one gets `enabled` false and an empty name.
    public func myProfile(accessToken: String) async throws(BipeAPIError) -> BipeMyProfile {
        try await send(method: "GET", path: ["v1", "me", "profile"], body: Empty?.none, accessToken: accessToken)
    }
    
    /// `PUT /v1/me/profile`. Turning it on needs a handle.
    public func setMyProfile(_ update: BipeProfileUpdate, accessToken: String) async throws(BipeAPIError) -> BipeMyProfile {
        try await send(method: "PUT", path: ["v1", "me", "profile"], body: update, accessToken: accessToken)
    }
    
    /// `PUT /v1/me/profile/photo`. `jpeg` must already fit the limits: see ``BipeProfilePhoto``.
    public func setMyProfilePhoto(jpeg: Data, accessToken: String) async throws(BipeAPIError) -> BipeMyProfile {
        try await send(method: "PUT", path: ["v1", "me", "profile", "photo"], rawBody: (data: jpeg, contentType: "image/jpeg"), accessToken: accessToken)
    }
    
    /// `DELETE /v1/me/profile/photo`.
    public func deleteMyProfilePhoto(accessToken: String) async throws(BipeAPIError) -> BipeMyProfile {
        try await send(method: "DELETE", path: ["v1", "me", "profile", "photo"], body: Empty?.none, accessToken: accessToken)
    }
    
    // MARK: - Data export (LGPD art. 18, ADR 0112, bipe#364)
    
    /// `GET /v1/me/export`. The server data of the caller as one JSON file. Messages stay on the device and are not in it.
    /// `rate_limited` (429) when asked too often.
    public func exportMyData(accessToken: String) async throws(BipeAPIError) -> BipeDataExport {
        let (data, response) = try await perform(method: "GET", path: ["v1", "me", "export"], rawBody: nil, accessToken: accessToken)
        let filename = BipeDataExport.filename(contentDisposition: response.value(forHTTPHeaderField: "Content-Disposition"))
        return BipeDataExport(data: data, filename: filename)
    }
    
    // MARK: - Auth
    
    /// Runs `request` with the token from `accessToken`. On HTTP 401 it reads the token again and retries once,
    /// because Matrix access tokens are short-lived and the SDK may have refreshed it meanwhile.
    @MainActor public static func withTokenRetry<T>(accessToken: @MainActor () -> String?,
                                                    _ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        guard let token = accessToken() else {
            throw .server(.unauthorized, reason: nil, statusCode: 401)
        }
        do {
            return try await request(token)
        } catch {
            guard error.isUnauthorized, let freshToken = accessToken() else { throw error }
            return try await request(freshToken)
        }
    }
    
    // MARK: - Private
    
    private struct Empty: Encodable { }
    
    /// Stands in for an empty 204 body.
    private struct NoContent: Decodable { }
    
    private struct AttestChallengeResponse: Decodable {
        let challenge: String
    }
    
    private struct ResolveRequest: Encodable {
        let userIds: [String]
    }
    
    private struct LookupRequest: Encodable {
        let phones: [String]
    }
    
    private struct LookupResponse: Decodable {
        let matches: [BipeContactMatch]
    }
    
    private struct DiscoverySettings: Codable {
        let byPhone: Bool
    }
    
    private struct InviteConnectionsResponse: Decodable {
        let userIds: [String]
    }
    
    private struct MessagingSetting: Codable {
        let whoCanMessage: BipeWhoCanMessage
    }
    
    private struct ResolveResponse: Decodable {
        let handles: [String: String]
    }
    
    private struct SetHandleRequest: Encodable {
        let handle: String
    }
    
    private struct TermsAcceptance: Encodable {
        let termsVersion: String
    }
    
    private struct PINRequest: Encodable {
        let pin: String
    }
    
    private struct RecoveryTokenResponse: Decodable {
        let recoveryToken: String
    }
    
    private struct EmailRequest: Encodable {
        let email: String
        let lang: String
    }
    
    private struct TokenRecoveryRequest: Encodable {
        let recoveryToken: String
        let pin: String
    }
    
    private struct RecoveryEmailRequest: Encodable {
        let email: String
    }
    
    private struct EmailConfirmRequest: Encodable {
        let token: String
        let pin: String?
        let newPin: String?
    }
    
    private struct ClaimRequest: Encodable {
        let claimSecret: String
    }
    
    private struct HandleChangesRequest: Encodable {
        let userIds: [String]
        let since: String?
    }
    
    private struct HandleChangesResponse: Decodable {
        let changes: [BipeHandleChange]
    }
    
    private static func formatDate(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
    
    private struct ErrorBody: Decodable {
        let error: String
        let reason: String?
        /// With `pin_wrong`: wrong PINs left before the PIN blocks.
        let triesLeft: Int?
    }
    
    private func send<Body: Encodable, Response: Decodable>(method: String,
                                                            path: [String],
                                                            body: Body?,
                                                            accessToken: String? = nil) async throws(BipeAPIError) -> Response {
        var rawBody: (data: Data, contentType: String)?
        if let body {
            do {
                rawBody = try (data: Self.encoder.encode(body), contentType: "application/json")
            } catch {
                throw .unexpectedResponse(statusCode: nil)
            }
        }
        return try await send(method: method, path: path, rawBody: rawBody, accessToken: accessToken)
    }
    
    /// Sends the request and returns the body of a 2xx answer. Other answers throw the contract's error.
    private func perform(method: String,
                         path: [String],
                         rawBody: (data: Data, contentType: String)?,
                         accessToken: String?) async throws(BipeAPIError) -> (Data, HTTPURLResponse) {
        // appending(path:) percent-encodes each component, so a handle cannot add path segments.
        let url = path.reduce(baseURL) { $0.appending(path: $1, directoryHint: .notDirectory) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let rawBody {
            request.setValue(rawBody.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = rawBody.data
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw .unexpectedResponse(statusCode: nil)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorBody = try? Self.decoder.decode(ErrorBody.self, from: data) {
                let code = BipeAPIErrorCode(rawValue: errorBody.error) ?? .internal
                // pin_wrong carries tries_left, not a reason. See BipeAPIError.pinTriesLeft.
                let reason = code == .pinWrong ? errorBody.triesLeft.map(String.init) : errorBody.reason
                throw .server(code, reason: reason, statusCode: httpResponse.statusCode)
            }
            throw .unexpectedResponse(statusCode: httpResponse.statusCode)
        }
        
        return (data, httpResponse)
    }
    
    private func send<Response: Decodable>(method: String,
                                           path: [String],
                                           rawBody: (data: Data, contentType: String)?,
                                           accessToken: String? = nil) async throws(BipeAPIError) -> Response {
        let (data, httpResponse) = try await perform(method: method, path: path, rawBody: rawBody, accessToken: accessToken)
        
        // 204, and 202 without a body.
        if httpResponse.statusCode == 204 || data.isEmpty, let noContent = NoContent() as? Response {
            return noContent
        }
        
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw .unexpectedResponse(statusCode: httpResponse.statusCode)
        }
    }
    
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Date(string, strategy: .iso8601) {
                return date
            }
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
        }
        return decoder
    }()
}

// MARK: - Models

/// Device-first sign-up (ADR 0057): no `password`. The server makes the password and returns it once.
public struct BipeSignupRequest: Encodable, Sendable, CustomStringConvertible {
    /// Optional while the server runs open sign-up (beta).
    public let inviteCode: String?
    /// A recovery fallback only, never a login. The server sends a link to confirm it.
    public let email: String?
    /// Legacy beta sign-up only. The app never sends it.
    public let password: String?
    /// Set at once. Must pass ``BipePIN/problem(for:)``.
    public let pin: String?
    /// Language of the emails Bipe sends to `email`.
    public let lang: String?
    public let handle: String?
    public let displayName: String?
    /// Absent where App Attest is not supported (simulator). The server decides whether to accept that.
    public let attestation: BipeAttestation?
    /// Same key on a retry: the same account (ADR 0094). From ``BipeCredentialStore/pendingSignup()``.
    public let signupKey: String?
    /// The ``BipeRegistries/legalVersion`` the person accepted with the checkbox (ADR 0113). Without it the server answers `terms_required`.
    public let termsVersion: String?
    
    public init(inviteCode: String? = nil,
                email: String?,
                pin: String?,
                lang: String? = BipeAPIClient.emailLanguage,
                handle: String?,
                displayName: String?,
                attestation: BipeAttestation? = nil,
                signupKey: String? = nil,
                termsVersion: String?) {
        self.signupKey = signupKey
        self.termsVersion = termsVersion
        self.inviteCode = inviteCode
        self.email = email
        password = nil
        self.pin = pin
        self.lang = lang
        self.handle = handle
        self.displayName = displayName
        self.attestation = attestation
    }
    
    /// Never prints the PIN or the email.
    public var description: String {
        "BipeSignupRequest"
    }
}

private struct SignupResumeRequest: Encodable {
    let signupKey: String
}

/// Apple App Attest result for sign-up. Contract: `Attestation`.
public struct BipeAttestation: Encodable, Sendable, CustomStringConvertible {
    /// Base64 key ID, exactly as `DCAppAttestService.generateKey` returns it.
    public let keyId: String
    /// Standard base64 of the attestation object.
    public let attestationObject: String
    public let challenge: String
    
    public init(keyId: String, attestationObject: String, challenge: String) {
        self.keyId = keyId
        self.attestationObject = attestationObject
        self.challenge = challenge
    }
    
    /// Never prints the attestation data.
    public var description: String {
        "BipeAttestation"
    }
}

/// The server's sign-up mode. Contract: `SignupConfig`.
public struct BipeSignupConfig: Decodable, Sendable, Equatable {
    /// `true`: sign-up fails without a valid invite code. An app that cannot read the mode assumes `true`.
    public let inviteRequired: Bool
    /// The current legal version (ADR 0113). Absent from a server older than ADR 0113.
    public let termsVersion: String?
}

public struct BipeSignupResponse: Decodable, Sendable, CustomStringConvertible {
    public let userId: String
    public let handle: String?
    /// Present when a personal invite was used.
    public let inviterUserId: String?
    /// Device-first only. The hidden MAS password, shown once. Keep it on this device only.
    public let password: String?
    /// Device-first only. Shown once. Sync it (iCloud Keychain).
    public let recoveryToken: String?
    
    /// The credentials of a device-first account. `nil` for a legacy response.
    public var credentials: BipeCredentials? {
        guard let password, let recoveryToken else { return nil }
        return BipeCredentials(userId: userId, password: password, recoveryToken: recoveryToken)
    }
    
    /// Never prints the password or the token.
    public var description: String {
        "BipeSignupResponse(\(userId))"
    }
}

public struct BipeContactMatch: Decodable, Sendable, Hashable {
    /// E.164, as normalised by the server.
    public let phone: String
    public let userId: String
}

public struct BipeMyPhone: Decodable, Sendable {
    public let linked: Bool
    public let discoverableByPhone: Bool
    public let linkedAt: Date?
    /// After this date the number stops being discoverable until confirmed again.
    public let confirmBy: Date?
}

public struct BipeInvitePreview: Decodable, Sendable {
    public let valid: Bool
    /// Without @. Only for a valid personal invite whose inviter has a handle.
    public let inviterHandle: String?
}

public enum BipeInviteStatus: String, Decodable, Sendable {
    case pending, used, expired, revoked
}

public struct BipeInvite: Decodable, Sendable, Identifiable, Equatable {
    public let id: String
    public let status: BipeInviteStatus
    public let createdAt: Date
    public let expiresAt: Date
    /// Only when `status` is `used`.
    public let joinedUserId: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, status, createdAt, expiresAt, joinedUserId
    }
    
    public init(id: String, status: BipeInviteStatus, createdAt: Date, expiresAt: Date, joinedUserId: String?) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.joinedUserId = joinedUserId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // An unknown status from a newer server must not fail the whole list.
        status = try BipeInviteStatus(rawValue: container.decode(String.self, forKey: .status)) ?? .expired
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        joinedUserId = try container.decodeIfPresent(String.self, forKey: .joinedUserId)
    }
}

public struct BipeMyInvites: Decodable, Sendable {
    public let quota: Int
    public let available: Int
    /// Only when `available` is 0: when the next slot comes back.
    public let nextAvailableAt: Date?
    public let invites: [BipeInvite]
}

public struct BipeCreatedInvite: Decodable, Sendable, CustomStringConvertible {
    public let id: String
    public let code: String
    public let url: URL
    public let expiresAt: Date
    
    /// Never prints the code.
    public var description: String {
        "BipeCreatedInvite(\(id))"
    }
}

public struct BipeHandleAvailability: Decodable, Sendable {
    public let handle: String
    public let available: Bool
    public let reason: BipeHandleProblem?
    
    private enum CodingKeys: String, CodingKey {
        case handle, available, reason
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handle = try container.decode(String.self, forKey: .handle)
        available = try container.decode(Bool.self, forKey: .available)
        // An unknown reason from a newer server must not fail the whole response.
        reason = try container.decodeIfPresent(String.self, forKey: .reason).map { BipeHandleProblem(rawValue: $0) ?? .taken }
    }
}

public struct BipeHandleRecord: Decodable, Sendable {
    public let handle: String
    public let userId: String
}

/// Contract: `MessagingSetting.who_can_message`.
public enum BipeWhoCanMessage: String, Codable, Sendable, CaseIterable {
    case everyone, verified, contacts
    
    public init(from decoder: Decoder) throws {
        // An unknown value from a newer server must not fail the response.
        self = try Self(rawValue: decoder.singleValueContainer().decode(String.self)) ?? .everyone
    }
    
    public var title: String {
        switch self {
        case .everyone: BipeStrings.messagingEveryone
        case .verified: BipeStrings.messagingVerified
        case .contacts: BipeStrings.messagingContacts
        }
    }
    
    public var body: String {
        switch self {
        case .everyone: BipeStrings.messagingEveryoneBody
        case .verified: BipeStrings.messagingVerifiedBody
        case .contacts: BipeStrings.messagingContactsBody
        }
    }
}

public struct BipeMyHandle: Decodable, Sendable {
    public let userId: String
    public let handle: String?
    /// `nil` when a change is allowed now.
    public let changeableAt: Date?
}

/// Contract: `PublicProfile`. What anyone with the exact handle sees.
public struct BipePublicProfile: Decodable, Sendable, Equatable {
    public let handle: String
    public let name: String
    /// Plain text. Absent when empty.
    public let bio: String?
    /// Absent without a photo. The URL changes when the photo changes.
    public let photoUrl: URL?
    /// Set by the server only. The apps do not show a profile badge yet.
    public let badge: BadgeEnvelope?
}

/// Contract: `MyProfile`. The caller's own profile, published or not.
public struct BipeMyProfile: Decodable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let bio: String
    public let hasPhoto: Bool
    /// Absent when the caller has no handle.
    public let handle: String?
    /// Absent without a photo.
    public let photoUrl: URL?
}

/// Contract: `ProfileUpdate`.
public struct BipeProfileUpdate: Encodable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let bio: String
    
    public init(enabled: Bool, name: String, bio: String) {
        self.enabled = enabled
        self.name = name
        self.bio = bio
    }
}

// MARK: - Errors

/// The contract's `Error.error` enum.
public enum BipeAPIErrorCode: String, Sendable {
    case badRequest = "bad_request"
    case inviteInvalid = "invite_invalid"
    case inviteQuotaExhausted = "invite_quota_exhausted"
    case emailTaken = "email_taken"
    case handleInvalid = "handle_invalid"
    case handleTaken = "handle_taken"
    case handleCooldown = "handle_cooldown"
    case passwordWeak = "password_weak"
    case attestationInvalid = "attestation_invalid"
    case profileInvalid = "profile_invalid"
    case photoInvalid = "photo_invalid"
    case unauthorized
    case notFound = "not_found"
    case rateLimited = "rate_limited"
    case `internal`
    case pinWeak = "pin_weak"
    case pinWrong = "pin_wrong"
    case pinBlocked = "pin_blocked"
    case pinNotSet = "pin_not_set"
    case recoveryInvalid = "recovery_invalid"
    case emailUnavailable = "email_unavailable"
    /// 403. Reason `missing` or `outdated` (ADR 0113).
    case termsRequired = "terms_required"
}

public enum BipeAPIError: Error, Sendable, Equatable {
    /// The server answered with the contract's error body.
    case server(BipeAPIErrorCode, reason: String?, statusCode: Int)
    /// The request did not reach the server or got no answer.
    case network
    /// The server answered with something outside the contract.
    case unexpectedResponse(statusCode: Int?)
    /// The device could not produce an App Attest attestation.
    case attestationFailed
    /// Apple's App Attest service did not answer (`DCError.serverUnavailable`).
    case attestationServiceDown
    
    /// HTTP 401: the access token was rejected.
    public var isUnauthorized: Bool {
        switch self {
        case .server(_, _, let statusCode): statusCode == 401
        case .unexpectedResponse(let statusCode): statusCode == 401
        case .network, .attestationFailed, .attestationServiceDown: false
        }
    }
    
    /// With `pin_wrong`: wrong PINs left before the server blocks the PIN.
    public var pinTriesLeft: Int? {
        guard case .server(.pinWrong, let reason, _) = self else { return nil }
        return reason.flatMap(Int.init)
    }
    
    /// User-facing message (pt-BR / en).
    public var localizedMessage: String {
        switch self {
        case .server(let code, let reason, _):
            switch code {
            case .inviteInvalid: BipeStrings.errorInviteInvalid
            case .inviteQuotaExhausted: BipeStrings.errorInviteQuota
            case .emailTaken: BipeStrings.errorEmailTaken
            case .passwordWeak: BipeStrings.errorPasswordWeak
            case .attestationInvalid: BipeStrings.errorAttestationInvalid
            case .handleTaken: BipeHandleProblem.taken.localizedMessage
            case .handleInvalid: (reason.flatMap(BipeHandleProblem.init(rawValue:)) ?? .invalidCharacters).localizedMessage
            case .handleCooldown: BipeStrings.errorHandleCooldown
            case .profileInvalid: (reason.flatMap(BipeProfileProblem.init(rawValue:))?.localizedMessage) ?? BipeStrings.errorGeneric
            case .photoInvalid: BipeStrings.publicProfilePhotoInvalid
            case .rateLimited: BipeStrings.errorRateLimited
            case .unauthorized: BipeStrings.errorUnauthorized
            case .pinWeak: (reason.flatMap(BipePinProblem.init(rawValue:)) ?? .sequence).localizedMessage
            case .pinWrong: BipeStrings.pinWrong(reason ?? "0")
            case .pinBlocked: BipeStrings.pinBlockedBody(String(BipeRegistries.pinMaxWrongTries))
            case .pinNotSet: BipeStrings.pinCreateBody(String(BipeRegistries.pinLength))
            case .recoveryInvalid: BipeStrings.errorRecoveryInvalid
            case .emailUnavailable: BipeStrings.errorEmailUnavailable
            case .termsRequired: BipeStrings.signupTermsRequired
            case .badRequest, .notFound, .internal: BipeStrings.errorGeneric
            }
        case .network:
            BipeStrings.errorNetwork
        case .unexpectedResponse:
            BipeStrings.errorGeneric
        case .attestationFailed, .attestationServiceDown:
            BipeStrings.errorAttestationFailed
        }
    }
}
