//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Client for the Proseio API. Contract: proseio-shared/api/openapi.yaml.
public struct ProseioAPIClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Sign-up

    /// `POST /v1/signup`. No auth.
    public func signup(_ request: ProseioSignupRequest) async throws(ProseioAPIError) -> ProseioSignupResponse {
        try await send(method: "POST", path: ["v1", "signup"], body: request)
    }

    // MARK: - Invites

    /// `GET /v1/invites/{code}`. No auth. Validity and the inviter's handle.
    public func invitePreview(code: String) async throws(ProseioAPIError) -> ProseioInvitePreview {
        try await send(method: "GET", path: ["v1", "invites", code], body: Empty?.none)
    }

    /// `GET /v1/me/invites`.
    public func myInvites(accessToken: String) async throws(ProseioAPIError) -> ProseioMyInvites {
        try await send(method: "GET", path: ["v1", "me", "invites"], body: Empty?.none, accessToken: accessToken)
    }

    /// `POST /v1/me/invites`. The code is returned once.
    public func createInvite(accessToken: String) async throws(ProseioAPIError) -> ProseioCreatedInvite {
        try await send(method: "POST", path: ["v1", "me", "invites"], body: Empty?.none, accessToken: accessToken)
    }

    /// `DELETE /v1/me/invites/{inviteId}`. Revokes a pending invite.
    public func revokeInvite(id: String, accessToken: String) async throws(ProseioAPIError) {
        let _: NoContent = try await send(method: "DELETE", path: ["v1", "me", "invites", id], body: Empty?.none, accessToken: accessToken)
    }

    // MARK: - Handles

    /// `GET /v1/handles/{handle}/availability`. No auth.
    public func handleAvailability(_ handle: String) async throws(ProseioAPIError) -> ProseioHandleAvailability {
        try await send(method: "GET", path: ["v1", "handles", handle, "availability"], body: Empty?.none)
    }

    /// `GET /v1/handles/{handle}`. Exact lookup.
    public func handle(_ handle: String, accessToken: String) async throws(ProseioAPIError) -> ProseioHandleRecord {
        try await send(method: "GET", path: ["v1", "handles", handle], body: Empty?.none, accessToken: accessToken)
    }

    /// `POST /v1/handles/resolve`. Returns Matrix ID to handle. IDs without a handle are absent.
    public func resolveHandles(userIDs: [String], accessToken: String) async throws(ProseioAPIError) -> [String: String] {
        let response: ResolveResponse = try await send(method: "POST",
                                                       path: ["v1", "handles", "resolve"],
                                                       body: ResolveRequest(userIds: userIDs),
                                                       accessToken: accessToken)
        return response.handles
    }

    /// `GET /v1/me/handle`.
    public func myHandle(accessToken: String) async throws(ProseioAPIError) -> ProseioMyHandle {
        try await send(method: "GET", path: ["v1", "me", "handle"], body: Empty?.none, accessToken: accessToken)
    }

    /// `PUT /v1/me/handle`.
    public func setMyHandle(_ handle: String, accessToken: String) async throws(ProseioAPIError) -> ProseioMyHandle {
        try await send(method: "PUT", path: ["v1", "me", "handle"], body: SetHandleRequest(handle: handle), accessToken: accessToken)
    }

    // MARK: - Auth

    /// Runs `request` with the token from `accessToken`. On HTTP 401 it reads the token again and retries once,
    /// because Matrix access tokens are short-lived and the SDK may have refreshed it meanwhile.
    @MainActor public static func withTokenRetry<T>(accessToken: @MainActor () -> String?,
                                                    _ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
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

    private struct ResolveRequest: Encodable {
        let userIds: [String]
    }

    private struct ResolveResponse: Decodable {
        let handles: [String: String]
    }

    private struct SetHandleRequest: Encodable {
        let handle: String
    }

    private struct ErrorBody: Decodable {
        let error: String
        let reason: String?
    }

    private func send<Body: Encodable, Response: Decodable>(method: String,
                                                            path: [String],
                                                            body: Body?,
                                                            accessToken: String? = nil) async throws(ProseioAPIError) -> Response {
        // appending(path:) percent-encodes each component, so a handle cannot add path segments.
        let url = path.reduce(baseURL) { $0.appending(path: $1, directoryHint: .notDirectory) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try Self.encoder.encode(body)
            } catch {
                throw .unexpectedResponse(statusCode: nil)
            }
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
                throw .server(ProseioAPIErrorCode(rawValue: errorBody.error) ?? .internal,
                              reason: errorBody.reason,
                              statusCode: httpResponse.statusCode)
            }
            throw .unexpectedResponse(statusCode: httpResponse.statusCode)
        }

        if httpResponse.statusCode == 204, let noContent = NoContent() as? Response {
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

public struct ProseioSignupRequest: Encodable, Sendable, CustomStringConvertible {
    /// Optional while the server runs open sign-up (beta).
    public let inviteCode: String?
    public let email: String
    public let password: String
    public let handle: String?
    public let displayName: String?

    public init(inviteCode: String? = nil, email: String, password: String, handle: String?, displayName: String?) {
        self.inviteCode = inviteCode
        self.email = email
        self.password = password
        self.handle = handle
        self.displayName = displayName
    }

    /// Never prints the password or the email.
    public var description: String { "ProseioSignupRequest" }
}

public struct ProseioSignupResponse: Decodable, Sendable {
    public let userId: String
    public let handle: String?
    /// Present when a personal invite was used.
    public let inviterUserId: String?
}

public struct ProseioInvitePreview: Decodable, Sendable {
    public let valid: Bool
    /// Without @. Only for a valid personal invite whose inviter has a handle.
    public let inviterHandle: String?
}

public enum ProseioInviteStatus: String, Decodable, Sendable {
    case pending, used, expired, revoked
}

public struct ProseioInvite: Decodable, Sendable, Identifiable, Equatable {
    public let id: String
    public let status: ProseioInviteStatus
    public let createdAt: Date
    public let expiresAt: Date
    /// Only when `status` is `used`.
    public let joinedUserId: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, createdAt, expiresAt, joinedUserId
    }

    public init(id: String, status: ProseioInviteStatus, createdAt: Date, expiresAt: Date, joinedUserId: String?) {
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
        status = try ProseioInviteStatus(rawValue: container.decode(String.self, forKey: .status)) ?? .expired
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        joinedUserId = try container.decodeIfPresent(String.self, forKey: .joinedUserId)
    }
}

public struct ProseioMyInvites: Decodable, Sendable {
    public let quota: Int
    public let available: Int
    /// Only when `available` is 0: when the next slot comes back.
    public let nextAvailableAt: Date?
    public let invites: [ProseioInvite]
}

public struct ProseioCreatedInvite: Decodable, Sendable, CustomStringConvertible {
    public let id: String
    public let code: String
    public let url: URL
    public let expiresAt: Date

    /// Never prints the code.
    public var description: String { "ProseioCreatedInvite(\(id))" }
}

public struct ProseioHandleAvailability: Decodable, Sendable {
    public let handle: String
    public let available: Bool
    public let reason: ProseioHandleProblem?

    private enum CodingKeys: String, CodingKey {
        case handle, available, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handle = try container.decode(String.self, forKey: .handle)
        available = try container.decode(Bool.self, forKey: .available)
        // An unknown reason from a newer server must not fail the whole response.
        reason = try container.decodeIfPresent(String.self, forKey: .reason).map { ProseioHandleProblem(rawValue: $0) ?? .taken }
    }
}

public struct ProseioHandleRecord: Decodable, Sendable {
    public let handle: String
    public let userId: String
}

public struct ProseioMyHandle: Decodable, Sendable {
    public let userId: String
    public let handle: String?
    /// `nil` when a change is allowed now.
    public let changeableAt: Date?
}

// MARK: - Errors

/// The contract's `Error.error` enum.
public enum ProseioAPIErrorCode: String, Sendable {
    case badRequest = "bad_request"
    case inviteInvalid = "invite_invalid"
    case inviteQuotaExhausted = "invite_quota_exhausted"
    case emailTaken = "email_taken"
    case handleInvalid = "handle_invalid"
    case handleTaken = "handle_taken"
    case handleCooldown = "handle_cooldown"
    case passwordWeak = "password_weak"
    case unauthorized
    case notFound = "not_found"
    case rateLimited = "rate_limited"
    case `internal`
}

public enum ProseioAPIError: Error, Sendable, Equatable {
    /// The server answered with the contract's error body.
    case server(ProseioAPIErrorCode, reason: String?, statusCode: Int)
    /// The request did not reach the server or got no answer.
    case network
    /// The server answered with something outside the contract.
    case unexpectedResponse(statusCode: Int?)

    /// HTTP 401: the access token was rejected.
    public var isUnauthorized: Bool {
        switch self {
        case .server(_, _, let statusCode): statusCode == 401
        case .unexpectedResponse(let statusCode): statusCode == 401
        case .network: false
        }
    }

    /// User-facing message (pt-BR / en).
    public var localizedMessage: String {
        switch self {
        case .server(let code, let reason, _):
            switch code {
            case .inviteInvalid: ProseioStrings.errorInviteInvalid
            case .inviteQuotaExhausted: ProseioStrings.errorInviteQuota
            case .emailTaken: ProseioStrings.errorEmailTaken
            case .passwordWeak: ProseioStrings.errorPasswordWeak
            case .handleTaken: ProseioHandleProblem.taken.localizedMessage
            case .handleInvalid: (reason.flatMap(ProseioHandleProblem.init(rawValue:)) ?? .invalidCharacters).localizedMessage
            case .handleCooldown: ProseioStrings.errorHandleCooldown
            case .rateLimited: ProseioStrings.errorRateLimited
            case .unauthorized: ProseioStrings.errorUnauthorized
            case .badRequest, .notFound, .internal: ProseioStrings.errorGeneric
            }
        case .network:
            ProseioStrings.errorNetwork
        case .unexpectedResponse:
            ProseioStrings.errorGeneric
        }
    }
}
