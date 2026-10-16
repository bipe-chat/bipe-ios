//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

/// Groups MVP (bipe#98): what a member missed since the last visit, built from the loaded items after the read marker.
/// Fixed rules over decrypted items on the device. Nothing goes to the server.
struct BipeMissedSummary: Equatable {
    struct Line: Equatable, Identifiable {
        enum Kind: Equatable {
            case mention
            case reply
            case poll
        }
        
        let kind: Kind
        let eventID: String
        let senderName: String
        let text: String
        
        var id: String {
            eventID
        }
    }
    
    /// Below this many unread messages the block stays hidden: a short gap reads fine without it.
    static let minimumUnreadCount = 20
    static let maximumLines = 4
    
    let lines: [Line]
    let otherCount: Int
}

extension BipeMissedSummary {
    init?(itemsAfterReadMarker: some Sequence<RoomTimelineItemViewState>, ownUserID: String) {
        let items = itemsAfterReadMarker.compactMap(\.bipeEventItem)
        guard items.count >= Self.minimumUnreadCount else { return nil }
        
        let matches = items.compactMap { Self.line(for: $0, ownUserID: ownUserID) }
        guard !matches.isEmpty else { return nil }
        
        let lines = Array(matches.prefix(Self.maximumLines))
        self.init(lines: lines, otherCount: items.count - lines.count)
    }
    
    // MARK: - Private
    
    private static func line(for item: EventBasedTimelineItemProtocol, ownUserID: String) -> Line? {
        guard !item.isOutgoing, let eventID = item.id.eventID else { return nil }
        let senderName = item.sender.displayName ?? item.sender.id
        
        if let poll = item as? PollRoomTimelineItem {
            guard !poll.poll.hasEnded, !poll.poll.options.contains(where: \.isSelected) else { return nil }
            return Line(kind: .poll, eventID: eventID, senderName: senderName, text: poll.poll.question)
        }
        if mentions(ownUserID, in: item) {
            return Line(kind: .mention, eventID: eventID, senderName: senderName, text: item.body)
        }
        if case let .loaded(sender, _, _) = item.properties.replyDetails, sender.id == ownUserID {
            return Line(kind: .reply, eventID: eventID, senderName: senderName, text: item.body)
        }
        return nil
    }
    
    private static func mentions(_ userID: String, in item: EventBasedTimelineItemProtocol) -> Bool {
        let formattedBody: AttributedString? = switch item {
        case let item as TextRoomTimelineItem: item.content.formattedBody
        case let item as NoticeRoomTimelineItem: item.content.formattedBody
        case let item as EmoteRoomTimelineItem: item.content.formattedBody
        default: nil
        }
        return formattedBody?.runs.contains { $0.elementX.userID == userID || $0.elementX.allUsersMention != nil } ?? false
    }
}

extension TimelineViewState {
    /// The "O que você perdeu" block for a group, or `nil` when there is nothing to show.
    var bipeMissedSummary: BipeMissedSummary? {
        guard !isDM,
              timelineKind == .live,
              let readMarkerID = timelineState.readMarkerUniqueID,
              let index = timelineState.itemsDictionary.index(forKey: readMarkerID) else {
            return nil
        }
        return BipeMissedSummary(itemsAfterReadMarker: timelineState.itemViewStates[(index + 1)...], ownUserID: ownUserID)
    }
}

private extension RoomTimelineItemViewState {
    var bipeEventItem: EventBasedTimelineItemProtocol? {
        switch type {
        case .text(let item): item
        case .image(let item): item
        case .video(let item): item
        case .audio(let item): item
        case .file(let item): item
        case .gallery(let item): item
        case .emote(let item): item
        case .notice(let item): item
        case .sticker(let item): item
        case .location(let item): item
        case .poll(let item): item
        case .voice(let item): item
        default: nil
        }
    }
}
