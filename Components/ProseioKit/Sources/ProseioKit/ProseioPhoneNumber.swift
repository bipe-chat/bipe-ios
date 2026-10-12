//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Brazilian mobile numbers for contact discovery. Rule: proseio-shared/registries/phone-numbers.json (generated);
/// cases: test-vectors/phone-numbers.json. Same result as the API's `normalizePhone`.
public nonisolated enum ProseioPhoneNumber {
    /// E.164 (`+5511987654321`) from an address-book entry, or `nil` for anything that is not a Brazilian mobile number.
    public static func normalize(_ text: String) -> String? {
        let head = String(text.prefix(ProseioRegistries.phoneMaxInputLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        var plus = head.filter { $0.isASCII && ($0.isNumber || $0 == "+") }.hasPrefix("+")
        var digits = head.filter { $0.isASCII && $0.isNumber }
        if !plus, digits.hasPrefix("00") {
            plus = true
            digits.removeFirst(2)
        }
        let countryCode = ProseioRegistries.phoneCountryCode
        let national = ProseioRegistries.phoneMobileLength + 2
        if plus {
            guard digits.hasPrefix(countryCode) else { return nil }
            digits.removeFirst(countryCode.count)
        } else if digits.count == national + 3, digits.hasPrefix("0") {
            digits.removeFirst(3) // trunk 0 + carrier code
        } else if digits.count == national + 1, digits.hasPrefix("0") {
            digits.removeFirst(1) // trunk 0
        } else if digits.count == national + countryCode.count, digits.hasPrefix(countryCode) {
            digits.removeFirst(countryCode.count)
        }
        guard digits.count == national else { return nil }
        let area = String(digits.prefix(2))
        let subscriber = String(digits.dropFirst(2))
        guard ProseioRegistries.phoneAreaCodes.contains(area), subscriber.hasPrefix(ProseioRegistries.phoneMobilePrefix) else { return nil }
        return "+\(countryCode)\(area)\(subscriber)"
    }
}
