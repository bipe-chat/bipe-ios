//
// Copyright 2026 Proseio.
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
    case receipt
    case newNumber
    case urgency

    /// The pt-BR first explanation. It never says the message IS a scam.
    public var message: String {
        switch self {
        case .pixCode: ProseioStrings.scamWarningPixCode
        case .boleto: ProseioStrings.scamWarningBoleto
        case .pixKey: ProseioStrings.scamWarningPixKey
        case .deliveryFee: ProseioStrings.scamWarningDeliveryFee
        case .receipt: ProseioStrings.scamWarningReceipt
        case .newNumber: ProseioStrings.scamWarningNewNumber
        case .urgency: ProseioStrings.scamWarningUrgency
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

        return warningKindPriority.first { kind in
            switch kind {
            case .pixCode: groups.contains("pixCopyPastePatterns")
            case .boleto: groups.contains("boletoPatterns")
            // A phone number or e-mail alone is normal chat. Warn only when the message also talks about Pix.
            case .pixKey: groups.contains("pixKeyPatterns") && containsAny(normalized, ProseioRegistries.pixKeyContextWords)
            // The fake-delivery fee scam: a link, and the message talks about a held parcel and a fee.
            case .deliveryFee: groups.contains("linkPatterns") && deliveryWordLists.allSatisfy { containsAny(normalized, $0) }
            case .receipt: groups.contains("receipt")
            // The falso parente opener. On Bipe it says new account, which is normal chat without a family term or urgency.
            case .newNumber: phrases.contains { ProseioRegistries.newNumberPhrases.contains($0) }
                || (containsAny(normalized, ProseioRegistries.newAccountPhrases)
                    && (!phrases.isEmpty || containsWord(normalized, ProseioRegistries.familyTerms)))
            case .urgency: !phrases.isEmpty
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
    private static let warningKindPriority = ProseioRegistries.scamWarningKindPriority.compactMap(ScamWarningKind.init(rawValue:))

    private static let deliveryWordLists = [
        ProseioRegistries.deliveryParcelWords,
        ProseioRegistries.deliveryHoldWords,
        ProseioRegistries.deliveryFeeWords
    ]

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
