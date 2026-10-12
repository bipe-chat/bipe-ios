//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Invite links: `https://proseio.com.br/convite/XXXX-XXXX-XXXX`. The web page there explains how to install;
/// the app opens it as a universal link and pre-fills the sign-up code.
public nonisolated enum ProseioInviteLink {
    /// Rule: proseio-shared/registries/invite-codes.json (generated). Cases: test-vectors/invite-codes.json.
    private static let pattern = try? NSRegularExpression(pattern: ProseioRegistries.inviteCodePattern)

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

    /// `XXXX-XXXX-XXXX` from anything a user typed or pasted: a code, an invite link or a whole message. `nil` when it holds no code.
    public static func normalizedCode(_ raw: String) -> String? {
        let text = String(raw.prefix(ProseioRegistries.inviteCodeMaxInputLength)).uppercased()
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern?.firstMatch(in: text, range: range) else { return nil }
        let groups = (1...3).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        return groups.count == 3 ? groups.joined(separator: "-") : nil
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
