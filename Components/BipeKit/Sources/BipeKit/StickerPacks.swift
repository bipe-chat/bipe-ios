//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

// Sticker packs per MSC2545 (bipe/docs/adr/0033-sticker-packs-msc2545.md).

public enum StickerPackEventType {
    /// Global account data: the user's own pack.
    public static let userPack = "im.ponies.user_emotes"
    /// Room state: packs shared in a room. The state key names the pack.
    public static let roomPack = "im.ponies.room_emotes"
    /// Global account data: room packs the user enabled everywhere.
    public static let enabledRooms = "im.ponies.emote_rooms"
}

public struct Sticker: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(packID)/\(shortcode)"
    }
    
    public let packID: String
    public let shortcode: String
    /// The `mxc://` URI of the image.
    public let url: String
    public let body: String
    public let width: Int?
    public let height: Int?
    public let mimeType: String?
    public let size: Int?
}

public struct StickerPack: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case user
        case room(roomID: String, stateKey: String)
    }
    
    public var id: String {
        switch source {
        case .user: "user"
        case .room(let roomID, let stateKey): "\(roomID)/\(stateKey)"
        }
    }
    
    public let source: Source
    public let displayName: String?
    public let stickers: [Sticker]
    
    /// Parses an MSC2545 pack. Keeps images whose usage includes `sticker`, or that state no usage.
    /// Returns nil when the content is not a pack or holds no stickers.
    public init?(contentJSON: Data, source: Source) {
        guard let content = try? JSONSerialization.jsonObject(with: contentJSON) as? [String: Any],
              let images = content["images"] as? [String: Any] else {
            return nil
        }
        let pack = content["pack"] as? [String: Any]
        let packUsage = pack?["usage"] as? [String]
        let packID = Self.packID(for: source)
        
        let stickers = images.keys.sorted().compactMap { shortcode -> Sticker? in
            guard let image = images[shortcode] as? [String: Any],
                  let url = image["url"] as? String, url.hasPrefix("mxc://") else {
                return nil
            }
            let usage = image["usage"] as? [String] ?? packUsage
            if let usage, !usage.isEmpty, !usage.contains("sticker") {
                return nil
            }
            let info = image["info"] as? [String: Any]
            return Sticker(packID: packID,
                           shortcode: shortcode,
                           url: url,
                           body: image["body"] as? String ?? shortcode,
                           width: info?["w"] as? Int,
                           height: info?["h"] as? Int,
                           mimeType: info?["mimetype"] as? String,
                           size: info?["size"] as? Int)
        }
        guard !stickers.isEmpty else { return nil }
        
        self.source = source
        displayName = pack?["display_name"] as? String
        self.stickers = stickers
    }
    
    private static func packID(for source: Source) -> String {
        switch source {
        case .user: "user"
        case .room(let roomID, let stateKey): "\(roomID)/\(stateKey)"
        }
    }
}

public extension Sticker {
    /// The JSON content of an `m.sticker` event. `threadRootID` puts the sticker in a thread.
    func eventContentJSON(threadRootID: String? = nil) -> String {
        var info: [String: Any] = [:]
        if let width {
            info["w"] = width
        }
        if let height {
            info["h"] = height
        }
        if let mimeType {
            info["mimetype"] = mimeType
        }
        if let size {
            info["size"] = size
        }
        
        var content: [String: Any] = ["body": body, "url": url, "info": info]
        if let threadRootID {
            content["m.relates_to"] = ["rel_type": "m.thread", "event_id": threadRootID, "is_falling_back": true]
        }
        // Only strings, numbers and dictionaries go in, so serialisation cannot fail.
        let data = (try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// Reads sticker packs from the homeserver's client-server API.
/// The SDK cannot read custom room state under sliding sync, so this goes over HTTP.
public struct StickerPackClient: Sendable {
    private let homeserverURL: URL
    private let session: URLSession
    
    public init(homeserverURL: URL, session: URLSession = .shared) {
        self.homeserverURL = homeserverURL
        self.session = session
    }
    
    /// The user's own pack, the packs of `roomID`, and the room packs the user enabled.
    public func packs(userID: String, roomID: String, accessToken: String) async throws(BipeAPIError) -> [StickerPack] {
        var packs: [StickerPack] = []
        
        if let data = try await get(["user", userID, "account_data", StickerPackEventType.userPack], accessToken: accessToken),
           let pack = StickerPack(contentJSON: data, source: .user) {
            packs.append(pack)
        }
        
        packs += try await roomPacks(roomID: roomID, accessToken: accessToken)
        
        if let data = try await get(["user", userID, "account_data", StickerPackEventType.enabledRooms], accessToken: accessToken) {
            for (enabledRoomID, stateKey) in Self.enabledRoomPacks(contentJSON: data) where enabledRoomID != roomID {
                // A pack in a room the user left is unreadable. Skip it, keep the others.
                guard let data = try? await get(["rooms", enabledRoomID, "state", StickerPackEventType.roomPack, stateKey], accessToken: accessToken),
                      let pack = StickerPack(contentJSON: data, source: .room(roomID: enabledRoomID, stateKey: stateKey)) else {
                    continue
                }
                packs.append(pack)
            }
        }
        return packs
    }
    
    /// A global account data event as the server has it now: the content JSON, nil when the event does not exist.
    /// The SDK's copy waits for the next sync, so a read-merge-write uses this one (cleared chats, bipe#479).
    public func accountData(userID: String, eventType: String, accessToken: String) async throws(BipeAPIError) -> Data? {
        try await get(["user", userID, "account_data", eventType], accessToken: accessToken)
    }
    
    // MARK: - Private
    
    private func roomPacks(roomID: String, accessToken: String) async throws(BipeAPIError) -> [StickerPack] {
        guard let data = try await get(["rooms", roomID, "state"], accessToken: accessToken),
              let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return events.compactMap { event in
            guard event["type"] as? String == StickerPackEventType.roomPack,
                  let stateKey = event["state_key"] as? String,
                  let content = event["content"],
                  let contentData = try? JSONSerialization.data(withJSONObject: content) else {
                return nil
            }
            return StickerPack(contentJSON: contentData, source: .room(roomID: roomID, stateKey: stateKey))
        }
        .sorted { $0.id < $1.id }
    }
    
    static func enabledRoomPacks(contentJSON: Data) -> [(roomID: String, stateKey: String)] {
        guard let content = try? JSONSerialization.jsonObject(with: contentJSON) as? [String: Any],
              let rooms = content["rooms"] as? [String: Any] else {
            return []
        }
        return rooms.keys.sorted().flatMap { roomID -> [(roomID: String, stateKey: String)] in
            let keys = (rooms[roomID] as? [String: Any])?.keys.sorted() ?? []
            return keys.map { (roomID: roomID, stateKey: $0) }
        }
    }
    
    /// GET under `/_matrix/client/v3`. Returns nil on 404 (no such account data or state).
    func get(_ path: [String], accessToken: String) async throws(BipeAPIError) -> Data? {
        var request = URLRequest(url: clientURL(path))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }
    
    /// PUT a JSON body under `/_matrix/client/v3`.
    func put(_ path: [String], json: Data, accessToken: String) async throws(BipeAPIError) {
        var request = URLRequest(url: clientURL(path))
        request.httpMethod = "PUT"
        request.httpBody = json
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await perform(request)
    }
    
    /// `POST /_matrix/media/v3/upload`. Returns the `mxc://` URI.
    func upload(_ data: Data, mimeType: String, fileName: String, accessToken: String) async throws(BipeAPIError) -> String {
        var url = homeserverURL.appending(path: "_matrix/media/v3/upload")
        url.append(queryItems: [URLQueryItem(name: "filename", value: fileName)])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        guard let body = try await perform(request),
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let contentURI = json["content_uri"] as? String, contentURI.hasPrefix("mxc://") else {
            throw .unexpectedResponse(statusCode: 200)
        }
        return contentURI
    }
    
    private func clientURL(_ path: [String]) -> URL {
        var url = homeserverURL.appending(path: "_matrix/client/v3")
        for component in path {
            url = url.appending(component: component)
        }
        return url
    }
    
    private func perform(_ request: URLRequest) async throws(BipeAPIError) -> Data? {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network
        }
        guard let http = response as? HTTPURLResponse else { throw .unexpectedResponse(statusCode: nil) }
        switch http.statusCode {
        case 200: return data
        case 404: return nil
        case 401: throw .server(.unauthorized, reason: nil, statusCode: 401)
        default: throw .unexpectedResponse(statusCode: http.statusCode)
        }
    }
}
