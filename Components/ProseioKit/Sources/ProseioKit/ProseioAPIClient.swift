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

    // MARK: - Private

    private struct Empty: Encodable { }

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

    /// User-facing message (pt-BR / en).
    public var localizedMessage: String {
        switch self {
        case .server(let code, let reason, _):
            switch code {
            case .inviteInvalid: ProseioStrings.errorInviteInvalid
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
