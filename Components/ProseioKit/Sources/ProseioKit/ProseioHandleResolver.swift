//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Observation
import SwiftUI

/// Maps Matrix IDs to handles and back, through the Proseio API. One instance per user session.
///
/// Reads are synchronous and observable: a view that calls `handle(for:)` gets `nil` at first,
/// the resolver batches the lookup through `POST /v1/handles/resolve`, and the view updates when the handle arrives.
@MainActor @Observable
public final class ProseioHandleResolver {
    private struct Entry {
        let handle: String?
        let expiry: Date
    }

    /// Only Matrix IDs on this server have handles.
    public let serverName: String

    private var entries: [String: Entry] = [:]

    @ObservationIgnored private let apiClient: ProseioAPIClient
    @ObservationIgnored private let accessToken: @MainActor () -> String?
    @ObservationIgnored private var queued: Set<String> = []
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var waiters: [String: [CheckedContinuation<String?, Never>]] = [:]
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    private static let foundTTL: TimeInterval = 10 * 60
    private static let missingTTL: TimeInterval = 2 * 60
    private static let batchSize = 100
    private static let coalesceDelay: Duration = .milliseconds(80)

    /// `accessToken` is read before every request, because Matrix access tokens are short-lived.
    public init(apiClient: ProseioAPIClient, serverName: String, accessToken: @escaping @MainActor () -> String?) {
        self.apiClient = apiClient
        self.serverName = serverName
        self.accessToken = accessToken
    }

    // MARK: - Matrix ID to handle

    /// `true` for a user ID on the Proseio server, e.g. `@k7q2m9x4tp:proseio.com.br`.
    public func isProseioUserID(_ userID: String) -> Bool {
        userID.hasPrefix("@") && userID.hasSuffix(":\(serverName)")
    }

    /// The cached handle (without "@"). Queues a lookup when the cache has no fresh value.
    public func handle(for userID: String) -> String? {
        guard isProseioUserID(userID) else { return nil }
        let entry = entries[userID]
        if (entry?.expiry ?? .distantPast) < .now {
            enqueue(userID)
        }
        return entry?.handle
    }

    /// "@handle" for a Proseio user ID with a known handle, otherwise `text` unchanged.
    /// Safe to call with any text, e.g. a title that falls back to the Matrix ID.
    public func displayText(for text: String) -> String {
        handle(for: text).map { "@\($0)" } ?? text
    }

    /// Waits for the handle. `nil` when the user has none or the lookup failed.
    public func resolve(_ userID: String) async -> String? {
        guard isProseioUserID(userID) else { return nil }
        if let entry = entries[userID], entry.expiry >= .now {
            return entry.handle
        }
        return await withCheckedContinuation { continuation in
            waiters[userID, default: []].append(continuation)
            enqueue(userID)
        }
    }

    /// Stores a handle the app already knows, e.g. after the user changes their own.
    public func store(handle: String?, for userID: String) {
        entries[userID] = Entry(handle: handle, expiry: .now.addingTimeInterval(handle == nil ? Self.missingTTL : Self.foundTTL))
    }

    // MARK: - Handle to Matrix ID

    /// Exact lookup through `GET /v1/handles/{handle}`. Returns `nil` when nobody holds the handle.
    public func userID(forHandle input: String) async throws(ProseioAPIError) -> String? {
        let handle = ProseioHandle.sanitize(input).lowercased()
        guard ProseioHandle.localProblem(for: handle) == nil else { return nil }

        do {
            let record = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioHandleRecord in
                try await apiClient.handle(handle, accessToken: token)
            }
            store(handle: record.handle, for: record.userId)
            return record.userId
        } catch {
            if case .server(_, _, let statusCode) = error, statusCode == 404 {
                return nil
            }
            throw error
        }
    }

    // MARK: - Private

    private func enqueue(_ userID: String) {
        guard !inFlight.contains(userID) else { return }
        queued.insert(userID)
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: Self.coalesceDelay)
            await self?.flush()
        }
    }

    private func flush() async {
        flushTask = nil
        let batch = Array(queued.prefix(Self.batchSize))
        queued.subtract(batch)
        inFlight.formUnion(batch)
        if !queued.isEmpty {
            scheduleFlush()
        }
        guard !batch.isEmpty else { return }

        do {
            let handles = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> [String: String] in
                try await apiClient.resolveHandles(userIDs: batch, accessToken: token)
            }
            for userID in batch {
                store(handle: handles[userID], for: userID)
            }
        } catch {
            // Keep the old values, with a short expiry so views do not retry on every render while offline.
            for userID in batch {
                entries[userID] = Entry(handle: entries[userID]?.handle, expiry: .now.addingTimeInterval(Self.missingTTL))
            }
        }

        inFlight.subtract(batch)
        for userID in batch {
            let handle = entries[userID]?.handle
            waiters.removeValue(forKey: userID)?.forEach { $0.resume(returning: handle) }
        }
    }

    /// Runs `request` with the current token. On HTTP 401 it reads the token again and retries once.
    private func withTokenRetry<T>(_ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
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
}

private extension ProseioAPIError {
    var isUnauthorized: Bool {
        switch self {
        case .server(_, _, let statusCode): statusCode == 401
        case .unexpectedResponse(let statusCode): statusCode == 401
        case .network: false
        }
    }
}

public extension EnvironmentValues {
    /// The session's handle resolver. `nil` outside a Proseio session: views keep upstream behaviour.
    @Entry var proseioHandleResolver: ProseioHandleResolver?
}
