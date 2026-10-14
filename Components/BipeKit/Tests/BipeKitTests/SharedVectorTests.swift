//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
@testable import BipeKit
import Testing

/// Every case in bipe-shared/test-vectors must pass (ADR 0031, rule 4). Android runs the same files.
struct SharedVectorTests {
    @Test
    func trustFacts() throws {
        let vectors = try SharedVectors.array("trust-facts.json", key: "vectors")
        #expect(!vectors.isEmpty)
        for vector in vectors {
            let inputData = try JSONSerialization.data(withJSONObject: #require(vector["input"]))
            let expectedData = try JSONSerialization.data(withJSONObject: #require(vector["expected"]))
            let input = try JSONDecoder().decode(BipeTrustInput.self, from: inputData)
            let expected = try JSONDecoder().decode(BipeTrustFacts.self, from: expectedData)
            #expect(BipeTrustFacts.evaluate(input) == expected, "trust facts \(vector["name"] ?? "")")
        }
    }

    @Test
    func normalization() throws {
        for vector in try SharedVectors.array("normalization.json", key: "vectors") {
            let input = try #require(vector["input"] as? String)
            #expect(NameNormalizer.normalize(input) == vector["normalized"] as? String, "normalize(\(input))")
            #expect(NameNormalizer.reservedCategory(for: input)?.rawValue == vector["reserved"] as? String, "reserved(\(input))")
        }
    }

    @Test
    func scamDetection() throws {
        for vector in try SharedVectors.array("scam-detection.json", key: "vectors") {
            let message = try #require(vector["message"] as? String)
            #expect(ScamDetector.matchIDs(in: message) == vector["matches"] as? [String], "matches(\(message))")
        }
    }

    @Test
    func scamWarnings() throws {
        for vector in try SharedVectors.array("scam-warnings.json", key: "vectors") {
            let message = try #require(vector["message"] as? String)
            let kind = ScamDetector.warningKind(forMatchIDs: ScamDetector.matchIDs(in: message), message: message)
            #expect(kind?.rawValue == vector["kind"] as? String, "kind(\(message))")
        }
    }

    @Test
    func pixCheck() throws {
        let vectors = try SharedVectors.array("pix-check.json", key: "vectors")
        #expect(!vectors.isEmpty)
        for vector in vectors {
            let text = try #require(vector["text"] as? String)
            let result = PixCheck.check(text)
            let label = "pixCheck(\(text.prefix(40)))"

            if let expected = vector["code"] as? [String: Any] {
                let code = try #require(result.code, "\(label) code")
                #expect(code.status.rawValue == expected["status"] as? String, "\(label) status")
                if code.status != .malformed {
                    #expect(code.dynamic == expected["dynamic"] as? Bool, "\(label) dynamic")
                    #expect(code.singleUse == expected["singleUse"] as? Bool, "\(label) singleUse")
                    #expect(code.key == expected["key"] as? String, "\(label) key")
                    #expect(code.keyType?.rawValue == expected["keyType"] as? String, "\(label) keyType")
                    #expect(code.url == expected["url"] as? String, "\(label) url")
                    #expect(code.name == expected["name"] as? String, "\(label) name")
                    #expect(code.city == expected["city"] as? String, "\(label) city")
                    #expect(code.amount == expected["amount"] as? String, "\(label) amount")
                    #expect(code.txid == expected["txid"] as? String, "\(label) txid")
                    #expect(code.info == expected["info"] as? String, "\(label) info")
                }
            } else {
                #expect(result.code == nil, "\(label) code")
            }

            let keys = try #require(vector["keys"] as? [[String: Any]])
            #expect(result.keys.map(\.value) == keys.map { $0["value"] as? String ?? "" }, "\(label) keys")
            #expect(result.keys.map { $0.types.map(\.rawValue) } == keys.map { $0["types"] as? [String] ?? [] }, "\(label) key types")
            #expect(result.warning?.rawValue == vector["warning"] as? String, "\(label) warning")
        }
    }

    /// The client checks length and characters only. Reserved names and lookalikes are the server's call.
    @Test
    func handles() throws {
        let localProblems: Set = ["too_short", "too_long", "invalid_characters"]
        for vector in try SharedVectors.array("handles.json", key: "cases") {
            let input = try #require(vector["input"] as? String)
            let expected = (vector["problem"] as? String).flatMap { localProblems.contains($0) ? $0 : nil }
            #expect(BipeHandle.localProblem(for: input)?.rawValue == expected, "localProblem(\(input))")
        }
    }

    @Test
    func inviteCodes() throws {
        for vector in try SharedVectors.array("invite-codes.json", key: "vectors") {
            let input = try #require(vector["input"] as? String)
            #expect(BipeInviteLink.normalizedCode(input) == vector["code"] as? String, "normalizedCode(\(input))")
        }
    }

    @Test
    func pins() throws {
        let cases = try SharedVectors.array("pins.json", key: "cases")
        #expect(!cases.isEmpty)
        for vector in cases {
            let input = try #require(vector["input"] as? String)
            #expect(BipePIN.problem(for: input)?.rawValue == vector["problem"] as? String, "pinProblem(\(input))")
        }
    }

    @Test
    func badges() throws {
        let file = try SharedVectors.object("badges.json")
        let now = Date(timeIntervalSince1970: try #require(file["now"] as? Double))
        let keys = try #require(file["publicKeys"] as? [String: String])
        let verifier = try BadgeVerifier(trustedKeys: keys.mapValues { try #require(Data(base64URL: $0)) })
        for vector in try #require(file["vectors"] as? [[String: Any]]) {
            let name = try #require(vector["name"] as? String)
            let envelope = try JSONSerialization.data(withJSONObject: try #require(vector["envelope"]))
            let result = verifier.verify(envelopeJSON: envelope,
                                         sender: try #require(vector["sender"] as? String),
                                         senderDevice: try #require(vector["senderDevice"] as? String),
                                         now: now)
            let outcome = switch result {
            case .valid: "valid"
            case .invalid(let failure): failure.rawValue
            }
            #expect(outcome == vector["expect"] as? String, "badge \(name)")
        }
    }
}

/// Loads bipe-shared/test-vectors next to this repo. BIPE_SHARED overrides the bipe-shared path.
enum SharedVectors {
    static var directory: URL {
        if let path = ProcessInfo.processInfo.environment["BIPE_SHARED"] {
            return URL(filePath: path).appending(path: "test-vectors")
        }
        // Tests/BipeKitTests/<file> -> BipeKit -> Components -> bipe-ios -> Bipe
        return URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "bipe-shared/test-vectors")
    }

    static func object(_ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: directory.appending(path: name))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func array(_ name: String, key: String) throws -> [[String: Any]] {
        try #require(try object(name)[key] as? [[String: Any]])
    }
}

private extension Data {
    init?(base64URL string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))
        self.init(base64Encoded: base64)
    }
}
