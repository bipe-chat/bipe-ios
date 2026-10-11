//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Invite links: `https://proseio.com.br/convite/XXXX-XXXX-XXXX`. The web page there explains how to install;
/// the app opens it as a universal link and pre-fills the sign-up code.
public nonisolated enum ProseioInviteLink {
    /// Same alphabet as proseio-api `newInviteCode()`: no 0/O, 1/I/L.
    private static let alphabet = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    /// The invite code in a link, normalised, or `nil` when the URL is not an invite link.
    public static func code(from url: URL) -> String? {
        guard url.scheme == "https",
              url.host()?.lowercased() == ProseioProfileLink.host || url.host()?.lowercased() == "www.\(ProseioProfileLink.host)" else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2, components[0] == "convite" else { return nil }
        return normalizedCode(components[1])
    }

    /// `XXXX-XXXX-XXXX` from what a user typed or pasted: ignores case, spaces and dashes. `nil` when it cannot be a code.
    public static func normalizedCode(_ raw: String) -> String? {
        let characters = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard characters.count == 12, characters.allSatisfy(alphabet.contains) else { return nil }
        let chars = Array(characters)
        return "\(String(chars[0..<4]))-\(String(chars[4..<8]))-\(String(chars[8..<12]))"
    }
}

/// A normalised invite code. Prints redacted, because routes and actions get logged.
public nonisolated struct ProseioInviteCode: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let value: String

    /// `nil` when `raw` cannot be a code.
    public init?(_ raw: String) {
        guard let value = ProseioInviteLink.normalizedCode(raw) else { return nil }
        self.value = value
    }

    public var description: String { "ProseioInviteCode(redacted)" }
    public var debugDescription: String { description }
}
