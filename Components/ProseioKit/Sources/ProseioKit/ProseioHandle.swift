//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Same ids as `handleProblem()` in proseio-shared/tools/lib/registries.mjs and the API's `HandleProblem`.
public enum ProseioHandleProblem: String, Sendable, Equatable {
    case tooShort = "too_short"
    case tooLong = "too_long"
    case invalidCharacters = "invalid_characters"
    case reserved
    /// Also covers held and lookalike handles (server only).
    case taken

    public var localizedMessage: String {
        switch self {
        case .tooShort: ProseioStrings.handleTooShort(String(ProseioRegistries.handleMinLength))
        case .tooLong: ProseioStrings.handleTooLong(String(ProseioRegistries.handleMaxLength))
        case .invalidCharacters: ProseioStrings.handleInvalidCharacters
        case .reserved: ProseioStrings.handleReserved
        case .taken: ProseioStrings.handleTaken
        }
    }
}

/// Client-side handle checks for early feedback. The server is the authority:
/// reserved names and lookalikes are checked there through the availability endpoint.
public nonisolated enum ProseioHandle {
    /// Trims whitespace and a leading "@" the user may type.
    public static func sanitize(_ input: String) -> String {
        var handle = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if handle.hasPrefix("@") {
            handle.removeFirst()
        }
        return handle
    }

    /// Length and character checks only. `nil` means the server must decide.
    public static func localProblem(for handle: String) -> ProseioHandleProblem? {
        // JS `length` counts UTF-16 code units; the pattern is ASCII-only, so any non-ASCII input fails it anyway.
        let length = handle.utf16.count
        if length < ProseioRegistries.handleMinLength { return .tooShort }
        if length > ProseioRegistries.handleMaxLength { return .tooLong }
        if handle.range(of: ProseioRegistries.handlePattern, options: .regularExpression) == nil { return .invalidCharacters }
        return nil
    }
}

/// Client-side checks for the sign-up form. Limits come from the API contract (`SignupRequest`).
public nonisolated enum ProseioSignupRules {
    public static let passwordMinLength = 8
    public static let passwordMaxLength = 256
    public static let inviteCodeMaxLength = 64
    public static let emailMaxLength = 254
    public static let displayNameMaxLength = 100

    /// A loose shape check. MAS and the API validate the address for real.
    public static func isPlausibleEmail(_ email: String) -> Bool {
        guard email.count <= emailMaxLength else { return false }
        return email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    public static func isValidPassword(_ password: String) -> Bool {
        (passwordMinLength...passwordMaxLength).contains(password.count)
    }
}

/// Result of checking a handle the user typed.
public enum ProseioHandleStatus: Sendable, Equatable {
    case empty
    case checking
    case available
    case problem(ProseioHandleProblem)
    /// The check failed (offline or server error). The server decides on submit.
    case unknown

    public var isBlocking: Bool {
        if case .problem = self { true } else { false }
    }

    /// Footer text for the handle field. `defaultText` shows when there is nothing to report.
    public func footer(defaultText: String) -> String {
        switch self {
        case .empty, .unknown: defaultText
        case .checking: ProseioStrings.handleChecking
        case .available: ProseioStrings.handleAvailable
        case .problem(let problem): problem.localizedMessage
        }
    }
}

/// Debounced availability check: local rules at once, then the API after a pause in typing.
@MainActor
public final class ProseioHandleAvailabilityChecker {
    private let apiClient: ProseioAPIClient
    private let debounce: Duration
    private var task: Task<Void, Never>?

    public init(apiClient: ProseioAPIClient, debounce: Duration = .milliseconds(500)) {
        self.apiClient = apiClient
        self.debounce = debounce
    }

    /// Cancels any check in flight. `update` gets every status change for `input`, on the main actor.
    public func check(_ input: String, update: @escaping @MainActor (ProseioHandleStatus) -> Void) {
        task?.cancel()

        let handle = ProseioHandle.sanitize(input)
        guard !handle.isEmpty else {
            update(.empty)
            return
        }
        if let problem = ProseioHandle.localProblem(for: handle) {
            update(.problem(problem))
            return
        }

        update(.checking)
        task = Task { [apiClient, debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            let status: ProseioHandleStatus
            do {
                let availability = try await apiClient.handleAvailability(handle)
                status = availability.available ? .available : .problem(availability.reason ?? .taken)
            } catch {
                status = .unknown
            }

            guard !Task.isCancelled else { return }
            update(status)
        }
    }

    public func cancel() {
        task?.cancel()
    }
}
