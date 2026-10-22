//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import Intents
import MatrixRustSDK
import SwiftUI

/// "Apagar conversa" in a DM (bipe#464). The user stays in the room. A marker in the global account data
/// `chat.bipe.cleared_chats` hides the DM from the lists until a newer event arrives, and drops the older
/// events from the timeline and from search. Android uses the same event type and content shape.
///
/// One store per account. The SDK cannot observe custom global account data (`AccountDataEventType` has
/// only Matrix types), so the store reads it again on each room list update, on foreground and after its own write.
final class BipeClearedChatsStore {
    private static var stores: [String: BipeClearedChatsStore] = [:]
    
    private weak var clientProxy: ClientProxyProtocol?
    private let userID: String
    private let subject: CurrentValueSubject<ClearedChats, Never>
    private var cancellables = Set<AnyCancellable>()
    private var isRefreshing = false
    private var writeTask: Task<Bool, Never>?
    
    var clearedChats: ClearedChats {
        subject.value
    }
    
    /// Publishes the current markers first, then each change.
    var publisher: AnyPublisher<ClearedChats, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }
    
    /// The account's store. A new client proxy for the same account (a new sign-in) gets a new store.
    static func store(for clientProxy: ClientProxyProtocol) -> BipeClearedChatsStore {
        if let store = stores[clientProxy.userID], store.clientProxy === clientProxy {
            return store
        }
        let store = BipeClearedChatsStore(clientProxy: clientProxy)
        stores[clientProxy.userID] = store
        return store
    }
    
    /// The store that a screen of this account already made, for code that has only a room.
    static func existingStore(userID: String) -> BipeClearedChatsStore? {
        stores[userID]
    }
    
    private init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
        userID = clientProxy.userID
        subject = CurrentValueSubject(ClearedChats(markers: Self.cachedMarkers(userID: clientProxy.userID)))
        
        clientProxy.staticRoomSummaryProvider.roomListPublisher
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        
        refresh()
    }
    
    // MARK: - Reading
    
    func marker(for roomID: String) -> UInt64? {
        clearedChats.marker(for: roomID)
    }
    
    /// True when the room lists leave the room out: a marker and no event after it.
    func isHidden(_ summary: RoomSummary) -> Bool {
        ClearedChats.isHidden(marker: marker(for: summary.id), latestTs: summary.bipeLatestEventTimestamp)
    }
    
    /// True when search keeps a message of the room sent at `date`.
    func keepsEvent(roomID: String, at date: Date) -> Bool {
        ClearedChats.keepsEvent(marker: marker(for: roomID), eventTs: date.bipeMilliseconds)
    }
    
    /// `BipeClearedTimeline.keptEvents` with the marker of `roomID`, for screens that read a pinned events timeline.
    static func keptEvents(_ itemProxies: [TimelineItemProxy], roomID: String, userID: String) -> [TimelineItemProxy] {
        BipeClearedTimeline.keptEvents(itemProxies, marker: existingStore(userID: userID)?.marker(for: roomID))
    }
    
    func refresh() {
        guard !isRefreshing, clientProxy != nil else { return }
        isRefreshing = true
        Task { [weak self] in
            let json = await self?.clientProxy?.bipeAccountData(eventType: ClearedChats.eventType)
            guard let self else { return }
            isRefreshing = false
            // nil is also a read error. The markers never go away, so keep what is known.
            guard let json else { return }
            apply(ClearedChats(json: json))
        }
    }
    
    // MARK: - Writing
    
    /// Clears the DM at the latest event of its room list summary, or at the current time when the summary has none.
    func clear(roomID: String) async -> Bool {
        let latestTs = clientProxy?.roomSummaryForIdentifier(roomID)?.bipeLatestEventTimestamp ?? Date.now.bipeMilliseconds
        return await clear(roomID: roomID, latestTs: latestTs)
    }
    
    /// Clears the DM up to `latestTs` (ms, the `origin_server_ts` of its latest event). Read, merge, write back:
    /// every other key and entry stays. Writes run one after the other, so two quick clears keep both markers.
    func clear(roomID: String, latestTs: UInt64) async -> Bool {
        let previousWrite = writeTask
        let write = Task { [weak self] () -> Bool in
            _ = await previousWrite?.value
            guard let self else { return false }
            return await writeMarker(roomID: roomID, latestTs: latestTs)
        }
        writeTask = write
        return await write.value
    }
    
    private func writeMarker(roomID: String, latestTs: UInt64) async -> Bool {
        guard let clientProxy else { return false }
        
        // The SDK's copy waits for the next sync, so a marker that another device wrote a moment ago can be missing
        // from it. Read the server's copy. Fail closed: no write without it, so no marker is lost (bipe#479).
        guard case var .success(json) = await serverAccountData(clientProxy: clientProxy) else {
            return false
        }
        // The markers this store knows go in as well. A marker never moves back, so that is safe.
        for (knownRoomID, knownTs) in clearedChats.markers {
            json = ClearedChats.json(clearing: json, roomID: knownRoomID, at: knownTs)
        }
        
        guard let content = ClearedChats.json(clearing: json, roomID: roomID, at: latestTs) else {
            MXLog.error("Bipe: failed encoding the cleared chats for \(roomID)")
            return false
        }
        
        guard case .success = await clientProxy.bipeSetAccountData(eventType: ClearedChats.eventType, content: content) else {
            return false
        }
        
        apply(ClearedChats(json: content))
        // The share sheet stops suggesting the DM. A message sent later donates it again.
        try? await INInteraction.delete(with: roomID)
        return true
    }
    
    /// The event over HTTP. `.success(nil)` when the server has none (404).
    private func serverAccountData(clientProxy: ClientProxyProtocol) async -> Result<String?, BipeAPIError> {
        guard let homeserverURL = URL(string: clientProxy.homeserver) else {
            MXLog.error("Bipe: invalid homeserver URL for the cleared chats")
            return .failure(.unexpectedResponse(statusCode: nil))
        }
        let client = StickerPackClient(homeserverURL: homeserverURL)
        let userID = clientProxy.userID
        do {
            let data = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { token throws(BipeAPIError) in
                try await client.accountData(userID: userID, eventType: ClearedChats.eventType, accessToken: token)
            }
            return .success(data.map { String(decoding: $0, as: UTF8.self) })
        } catch {
            MXLog.error("Bipe: reading the cleared chats from the server failed: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Private
    
    /// Merges `read` into the known markers, the later marker for each room. A stale read never shows a DM again.
    private func apply(_ read: ClearedChats) {
        let merged = ClearedChats(markers: clearedChats.markers.merging(read.markers) { max($0, $1) })
        guard merged != clearedChats else { return }
        UserDefaults.standard.set(merged.markers.mapValues { NSNumber(value: $0) }, forKey: Self.cacheKey(userID: userID))
        subject.send(merged)
    }
    
    /// The last known markers, so the lists hide cleared DMs before the first read returns.
    private static func cachedMarkers(userID: String) -> [String: UInt64] {
        let cached = UserDefaults.standard.dictionary(forKey: cacheKey(userID: userID)) as? [String: NSNumber]
        return cached?.mapValues(\.uint64Value) ?? [:]
    }
    
    private static func cacheKey(userID: String) -> String {
        "bipe.clearedChats.\(userID)"
    }
}

/// The timeline of a cleared DM (bipe#464): only the events after the marker.
nonisolated enum BipeClearedTimeline {
    /// Drops every event at or before the marker, with its reactions and read receipts, and the items before it
    /// (read marker, "start of conversation"). Keeps the date divider of the first event that stays.
    /// `reachedMarker` is true when the loaded items go back to the marker: back pagination stops there.
    static func filter(_ itemProxies: [TimelineItemProxy], marker: UInt64?) -> (items: [TimelineItemProxy], reachedMarker: Bool) {
        guard let marker else { return (itemProxies, false) }
        
        guard let lastDroppedIndex = itemProxies.lastIndex(where: { isDropped($0, marker: marker) }) else {
            return (itemProxies.filter { !isTimelineStart($0) }, false)
        }
        
        var items = itemProxies[(lastDroppedIndex + 1)...].filter { !isDropped($0, marker: marker) && !isTimelineStart($0) }
        if let first = items.first, !isDateDivider(first),
           let divider = itemProxies[...lastDroppedIndex].last(where: isDateDivider) {
            items.insert(divider, at: 0)
        }
        return (items, true)
    }
    
    /// Drops the events at or before the marker and keeps the rest as they are. For the pinned events (banner, room details count).
    static func keptEvents(_ itemProxies: [TimelineItemProxy], marker: UInt64?) -> [TimelineItemProxy] {
        guard let marker else { return itemProxies }
        return itemProxies.filter { !isDropped($0, marker: marker) }
    }
    
    private static func isDropped(_ itemProxy: TimelineItemProxy, marker: UInt64) -> Bool {
        guard case .event(let eventItem) = itemProxy else { return false }
        return !ClearedChats.keepsEvent(marker: marker, eventTs: eventItem.item.timestamp)
    }
    
    private static func isDateDivider(_ itemProxy: TimelineItemProxy) -> Bool {
        if case .virtual(.dateDivider(_), _) = itemProxy {
            return true
        }
        return false
    }
    
    private static func isTimelineStart(_ itemProxy: TimelineItemProxy) -> Bool {
        if case .virtual(.timelineStart, _) = itemProxy {
            return true
        }
        return false
    }
}

extension Date {
    /// Milliseconds since 1970, as in `origin_server_ts`.
    nonisolated var bipeMilliseconds: UInt64 {
        UInt64(max(0, (timeIntervalSince1970 * 1000).rounded()))
    }
}
