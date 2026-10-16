//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compression
import Foundation

/// Reads entries from a ZIP archive, such as a WhatsApp chat export.
/// Supports stored and deflated entries. ZIP64 and encrypted entries are skipped.
/// No dependency: Apple's `COMPRESSION_ZLIB` decodes raw DEFLATE (RFC 1951), which is what ZIP uses.
public struct ZipReader: Sendable {
    public struct Entry: Sendable {
        public let path: String
        public let uncompressedSize: Int
        fileprivate let method: UInt16
        fileprivate let compressedSize: Int
        fileprivate let localHeaderOffset: Int
        fileprivate let isEncrypted: Bool
    }
    
    public enum ZipError: Error, Sendable {
        case notAZip
        case unsupportedEntry
        case corrupt
    }
    
    public let entries: [Entry]
    private let data: Data
    
    /// Maps the file instead of reading it, so a large export does not fill memory.
    public init(url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .alwaysMapped))
    }
    
    public init(data: Data) throws {
        self.data = data
        entries = try Self.readCentralDirectory(data)
    }
    
    /// The bytes of `entry`. Fails for entries larger than `maxSize`.
    public func contents(of entry: Entry, maxSize: Int) throws -> Data {
        guard !entry.isEncrypted, entry.uncompressedSize <= maxSize,
              entry.method == 0 || entry.method == 8 else {
            throw ZipError.unsupportedEntry
        }
        let header = entry.localHeaderOffset
        guard data.uint32(at: header) == 0x0403_4B50,
              let nameLength = data.uint16(at: header + 26),
              let extraLength = data.uint16(at: header + 28) else {
            throw ZipError.corrupt
        }
        let start = header + 30 + Int(nameLength) + Int(extraLength)
        guard start >= 0, start + entry.compressedSize <= data.count else { throw ZipError.corrupt }
        let compressed = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + entry.compressedSize))
        
        if entry.method == 0 {
            return compressed
        }
        guard entry.uncompressedSize > 0 else { return Data() }
        var output = Data(count: entry.uncompressedSize)
        let written = output.withUnsafeMutableBytes { outBuffer in
            compressed.withUnsafeBytes { inBuffer in
                compression_decode_buffer(outBuffer.bindMemory(to: UInt8.self).baseAddress!, entry.uncompressedSize,
                                          inBuffer.bindMemory(to: UInt8.self).baseAddress!, compressed.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == entry.uncompressedSize else { throw ZipError.corrupt }
        return output
    }
    
    // MARK: - Private
    
    private static func readCentralDirectory(_ data: Data) throws -> [Entry] {
        // The end-of-central-directory record sits in the last 22 + 65535 bytes (the comment is at most 64 KiB).
        let minimumOffset = max(0, data.count - 22 - 0xFFFF)
        var eocd: Int?
        var offset = data.count - 22
        while offset >= minimumOffset {
            if data.uint32(at: offset) == 0x0605_4B50 {
                eocd = offset
                break
            }
            offset -= 1
        }
        guard let eocd,
              let count = data.uint16(at: eocd + 10),
              let directoryOffset = data.uint32(at: eocd + 16) else {
            throw ZipError.notAZip
        }
        
        var entries: [Entry] = []
        var cursor = Int(directoryOffset)
        for _ in 0..<count {
            guard data.uint32(at: cursor) == 0x0201_4B50,
                  let flags = data.uint16(at: cursor + 8),
                  let method = data.uint16(at: cursor + 10),
                  let compressedSize = data.uint32(at: cursor + 20),
                  let uncompressedSize = data.uint32(at: cursor + 24),
                  let nameLength = data.uint16(at: cursor + 28),
                  let extraLength = data.uint16(at: cursor + 30),
                  let commentLength = data.uint16(at: cursor + 32),
                  let localHeaderOffset = data.uint32(at: cursor + 42),
                  cursor + 46 + Int(nameLength) <= data.count else {
                throw ZipError.corrupt
            }
            let nameStart = data.startIndex + cursor + 46
            let path = String(decoding: data[nameStart..<(nameStart + Int(nameLength))], as: UTF8.self)
            // 0xFFFFFFFF marks ZIP64 values, which this reader does not follow.
            if compressedSize != 0xFFFF_FFFF, uncompressedSize != 0xFFFF_FFFF, localHeaderOffset != 0xFFFF_FFFF {
                entries.append(Entry(path: path,
                                     uncompressedSize: Int(uncompressedSize),
                                     method: method,
                                     compressedSize: Int(compressedSize),
                                     localHeaderOffset: Int(localHeaderOffset),
                                     isEncrypted: flags & 0x1 != 0))
            }
            cursor += 46 + Int(nameLength) + Int(extraLength) + Int(commentLength)
        }
        return entries
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        let i = startIndex + offset
        return UInt16(self[i]) | UInt16(self[i + 1]) << 8
    }
    
    func uint32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        let i = startIndex + offset
        return UInt32(self[i]) | UInt32(self[i + 1]) << 8 | UInt32(self[i + 2]) << 16 | UInt32(self[i + 3]) << 24
    }
}
