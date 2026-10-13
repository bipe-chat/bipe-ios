//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Synchronization

/// The scam pattern a message looks like (security.md rule 9). Friction, not protection.
public nonisolated enum ScamWarningKind: String, Sendable, Hashable {
    case pixCode
    case boleto
    case pixKey
    case deliveryFee
    case lookalikeLink
    case bankAlert
    case receipt
    case newNumber
    case urgency

    /// The pt-BR first explanation. It never says the message IS a scam.
    public var message: String {
        switch self {
        case .pixCode: BipeStrings.scamWarningPixCode
        case .boleto: BipeStrings.scamWarningBoleto
        case .pixKey: BipeStrings.scamWarningPixKey
        case .deliveryFee: BipeStrings.scamWarningDeliveryFee
        case .lookalikeLink: BipeStrings.scamWarningLookalikeLink
        case .bankAlert: BipeStrings.scamWarningBankAlert
        case .receipt: BipeStrings.scamWarningReceipt
        case .newNumber: BipeStrings.scamWarningNewNumber
        case .urgency: BipeStrings.scamWarningUrgency
        }
    }
}

public extension ScamDetector {
    /// The one warning to show for a message, or `nil`. Cached by event ID, so timeline rebuilds stay cheap.
    /// The body is part of the key because an edit keeps the event ID.
    static func warningKind(for message: String, eventID: String) -> ScamWarningKind? {
        let bodyHash = message.hashValue
        if let cached = warningCache.withLock({ $0[eventID] }), cached.bodyHash == bodyHash {
            return cached.kind
        }

        let kind = warningKind(forMatchIDs: matchIDs(in: message), message: message)
        warningCache.withLock { cache in
            if cache.count >= maxCachedEvents {
                cache.removeAll(keepingCapacity: true)
            }
            cache[eventID] = CachedWarning(bodyHash: bodyHash, kind: kind)
        }
        return kind
    }

    /// Picks the most actionable warning from `matchIDs(in:)` output.
    /// Must match proseio-shared/test-vectors/scam-warnings.json.
    static func warningKind(forMatchIDs matchIDs: [String], message: String) -> ScamWarningKind? {
        let groups = Set(matchIDs.compactMap { $0.split(separator: ":", maxSplits: 1).first.map(String.init) })
        let phrases = matchIDs.compactMap { $0.hasPrefix("urgency:") ? String($0.dropFirst("urgency:".count)) : nil }
        let normalized = NameNormalizer.normalize(message, homoglyphs: [:])
        let hosts = linkHosts(in: message)

        return warningKindPriority.first { kind in
            switch kind {
            case .pixCode: groups.contains("pixCopyPastePatterns")
            case .boleto: groups.contains("boletoPatterns")
            // A phone number or e-mail alone is normal chat. Warn only when the message also talks about Pix.
            case .pixKey: groups.contains("pixKeyPatterns") && containsAny(normalized, BipeRegistries.pixKeyContextWords)
            // The fake-delivery fee scam: a link, and the message talks about a held parcel and a fee.
            case .deliveryFee: !hosts.isEmpty && deliveryWordLists.allSatisfy { containsAny(normalized, $0) }
            // A link that copies a bank, government or company address, also when spelled with homoglyphs.
            case .lookalikeLink: hosts.contains(where: isLookalike)
            // The fake bank alert: a link, and the message says the account, card or Pix is blocked or needs an update.
            case .bankAlert: !hosts.isEmpty && bankAlertWordLists.allSatisfy { containsAny(normalized, $0) }
            case .receipt: groups.contains("receipt")
            // The falso parente opener. On Bipe it says new account, which is normal chat without a family term or urgency.
            case .newNumber: phrases.contains { BipeRegistries.newNumberPhrases.contains($0) }
                || (containsAny(normalized, BipeRegistries.newAccountPhrases)
                    && (!phrases.isEmpty || containsWord(normalized, BipeRegistries.familyTerms)))
            case .urgency: !phrases.isEmpty
            }
        }
    }

    /// A link host. `folded` is a link-pattern match on the host-folded message. `plain` is the same UTF-16 range
    /// of the message normalised without folding, so it keeps homoglyphs.
    struct LinkHost: Equatable {
        let folded: String
        let plain: String
    }

    /// Every link host in the message. Must match proseio-shared `linkHosts`.
    static func linkHosts(in message: String) -> [LinkHost] {
        let plain = NameNormalizer.normalize(message, homoglyphs: [:]) as NSString
        let folded = NameNormalizer.normalize(message, homoglyphs: BipeRegistries.hostHomoglyphs) as NSString
        // proseio-shared validates that host folding keeps every UTF-16 index. An empty plain host is never official.
        let aligned = plain.length == folded.length
        return linkExpressions.flatMap { expression in
            expression.matches(in: folded as String, range: NSRange(location: 0, length: folded.length)).map {
                LinkHost(folded: folded.substring(with: $0.range), plain: aligned ? plain.substring(with: $0.range) : "")
            }
        }
    }

    // MARK: - Private

    private struct CachedWarning: Sendable {
        let bodyHash: Int
        let kind: ScamWarningKind?
    }

    private static let maxCachedEvents = 2000
    private static let warningCache = Mutex<[String: CachedWarning]>([:])

    /// proseio-shared validates that the priority lists every kind once, so `compactMap` drops nothing.
    private static let warningKindPriority = BipeRegistries.scamWarningKindPriority.compactMap(ScamWarningKind.init(rawValue:))

    private static let deliveryWordLists = [
        BipeRegistries.deliveryParcelWords,
        BipeRegistries.deliveryHoldWords,
        BipeRegistries.deliveryFeeWords
    ]

    private static let bankAlertWordLists = [
        BipeRegistries.bankAlertSubjectWords,
        BipeRegistries.bankAlertThreatWords
    ]

    // proseio-shared validates every regex at generation time, so a compile failure here is not expected.
    private static let linkExpressions = BipeRegistries.linkPatterns.compactMap { try? NSRegularExpression(pattern: $0.regex) }

    /// True when the host copies a brand: its folded form names a brand and its plain form is not that brand's domain.
    private static func isLookalike(_ host: LinkHost) -> Bool {
        let squashed = host.folded.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "")
        guard BipeRegistries.lookalikeBrandTokens.contains(where: { containsCodeUnits(squashed, $0) }) else { return false }
        return !BipeRegistries.officialDomains.contains { host.plain == $0 || host.plain.hasSuffix(".\($0)") }
    }

    private static func containsAny(_ normalized: String, _ words: [String]) -> Bool {
        words.contains { containsCodeUnits(normalized, $0) }
    }

    /// True when the normalised text has one of `terms` as a whole word: each run of characters outside [0-9a-z]
    /// becomes one space, then the term must have a space on each side.
    private static func containsWord(_ normalized: String, _ terms: Set<String>) -> Bool {
        var words = " "
        for scalar in normalized.unicodeScalars {
            if ("0"..."9").contains(scalar) || ("a"..."z").contains(scalar) {
                words.unicodeScalars.append(scalar)
            } else if words.unicodeScalars.last != " " {
                words.unicodeScalars.append(" ")
            }
        }
        if words.unicodeScalars.last != " " {
            words.unicodeScalars.append(" ")
        }
        return terms.contains { containsCodeUnits(words, " \($0) ") }
    }
}
