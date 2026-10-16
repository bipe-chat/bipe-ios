//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import CryptoKit
import Foundation
import ImageIO

/// A sticker file ready to go into the user's pack.
public struct StickerImportCandidate: Sendable {
    public let data: Data
    public let mimeType: String
    public let width: Int
    public let height: Int
    /// Derived from the file's SHA-256, so the same file imported twice gets the same shortcode.
    public let shortcode: String
}

/// Imports stickers from a WhatsApp chat export or from loose image files (ADR 0029, 0033).
public enum StickerImporter {
    /// WhatsApp stickers are 512 × 512, static up to 100 KB, animated up to 500 KB. These limits leave room.
    public static let maxFileSize = 1_000_000
    public static let maxSide = 1024
    
    /// Sticker files from `urls`. A ZIP gives its `.webp` entries; a WebP or PNG file gives itself.
    /// Files that fail a check are skipped. Duplicates are removed.
    public static func candidates(from urls: [URL]) -> [StickerImportCandidate] {
        var seen = Set<String>()
        var result: [StickerImportCandidate] = []
        for url in urls {
            for data in fileContents(url) {
                guard let candidate = candidate(from: data), seen.insert(candidate.shortcode).inserted else { continue }
                result.append(candidate)
            }
        }
        return result
    }
    
    /// Checks the format by its magic bytes and the size with ImageIO. Returns nil when the file is not a usable sticker.
    public static func candidate(from data: Data) -> StickerImportCandidate? {
        guard data.count <= maxFileSize, let mimeType = mimeType(of: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= maxSide, height <= maxSide else {
            return nil
        }
        let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return StickerImportCandidate(data: data, mimeType: mimeType, width: width, height: height, shortcode: "st_\(digest)")
    }
    
    // MARK: - Private
    
    private static func fileContents(_ url: URL) -> [Data] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if url.pathExtension.lowercased() == "zip" {
            guard let zip = try? ZipReader(url: url) else { return [] }
            return zip.entries
                .filter { $0.path.lowercased().hasSuffix(".webp") && $0.uncompressedSize <= maxFileSize }
                .compactMap { try? zip.contents(of: $0, maxSize: maxFileSize) }
        }
        guard let data = try? Data(contentsOf: url), data.count <= maxFileSize else { return [] }
        return [data]
    }
    
    private static func mimeType(of data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        guard bytes.count == 12 else { return nil }
        if bytes[0...3] == [0x52, 0x49, 0x46, 0x46], bytes[8...11] == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }
        if bytes[0...7] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
            return "image/png"
        }
        return nil
    }
}

public extension StickerPackClient {
    /// Uploads `candidates` that are not yet in the user's pack and adds them to it.
    /// Keeps every other field of the pack. Returns how many stickers it added.
    func importStickers(_ candidates: [StickerImportCandidate],
                        userID: String,
                        accessToken: String) async throws(BipeAPIError) -> Int {
        let path = ["user", userID, "account_data", StickerPackEventType.userPack]
        var content: [String: Any] = [:]
        if let data = try await get(path, accessToken: accessToken),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            content = existing
        }
        var images = content["images"] as? [String: Any] ?? [:]
        
        var added = 0
        var uploadError: BipeAPIError?
        for candidate in candidates where images[candidate.shortcode] == nil {
            let fileExtension = candidate.mimeType == "image/png" ? "png" : "webp"
            do {
                let url = try await upload(candidate.data,
                                           mimeType: candidate.mimeType,
                                           fileName: "\(candidate.shortcode).\(fileExtension)",
                                           accessToken: accessToken)
                images[candidate.shortcode] = [
                    "url": url,
                    "body": "Sticker",
                    "usage": ["sticker"],
                    "info": ["w": candidate.width, "h": candidate.height, "mimetype": candidate.mimeType, "size": candidate.data.count]
                ]
                added += 1
            } catch {
                // Keep what is already uploaded: save the pack, then report the error.
                uploadError = error
                break
            }
        }
        
        if added > 0 {
            content["images"] = images
            guard let json = try? JSONSerialization.data(withJSONObject: content) else {
                throw .unexpectedResponse(statusCode: nil)
            }
            try await put(path, json: json, accessToken: accessToken)
        }
        if let uploadError {
            throw uploadError
        }
        return added
    }
}
