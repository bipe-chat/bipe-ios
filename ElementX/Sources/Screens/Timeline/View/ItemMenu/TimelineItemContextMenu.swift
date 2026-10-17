//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The contents of the native context menu shown when long pressing (or right clicking on a Mac) an item in the timeline.
struct TimelineItemContextMenu: View {
    let item: RoomTimelineItemProtocol
    let actionProvider: TimelineItemMenuActionProvider
    let send: (TimelineItemMenuAction) -> Void
    
    /// The palette row has room for this many reactions next to the add reaction button on a phone.
    private let maxPaletteReactions = 6
    
    var body: some View {
        if let menuActions = actionProvider.makeActions() {
            Section {
                if !menuActions.reactions.isEmpty {
                    let reactions = (item as? EventBasedTimelineItemProtocol)?.properties.reactions ?? []
                    ControlGroup {
                        ForEach(menuActions.reactions.prefix(maxPaletteReactions), id: \.key) {
                            ReactionToggle(reaction: $0, reactions: reactions) {
                                send(.toggleReaction(key: $0))
                            }
                        }
                        
                        Button { send(.react) } label: {
                            CompoundIcon(\.reactionAdd)
                        }
                        .accessibilityLabel(L10n.actionReact)
                    }
                    .controlGroupStyle(.palette)
                }
                
                ForEach(menuActions.actions) { action in
                    Button(role: action.isDestructive ? .destructive : nil) {
                        send(action)
                    } label: {
                        action.label
                    }
                }
            }
            
            Section {
                ForEach(menuActions.secondaryActions) { action in
                    Button(role: action.isDestructive ? .destructive : nil) {
                        send(action)
                    } label: {
                        action.label
                    }
                }
            }
        }
    }
}

/// The lifted preview of the context menu: the item's header above its bubble.
///
/// A custom preview also avoids the system snapshot of the cell, which lives in a flipped table view.
struct TimelineItemContextMenuPreview<Bubble: View>: View {
    let item: EventBasedTimelineItemProtocol
    @ViewBuilder let bubble: () -> Bubble
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The preview is not interactive, the send info stays reachable from the timeline.
            TimelineItemMenuHeader(item: item) { }
            
            bubble()
                .frame(maxWidth: .infinity, alignment: item.isOutgoing ? .trailing : .leading)
        }
        .padding(16)
        .frame(width: 340)
        .background(Color.compound.bgCanvasDefault)
    }
}

/// A button that acts as a toggle for reacting to a message.
private struct ReactionToggle: View {
    let reaction: TimelineItemMenuReaction
    let reactions: [AggregatedReaction]
    let action: (String) -> Void
    
    var isOn: Bool {
        reactions.contains { $0.key == reaction.key && $0.isHighlighted }
    }
    
    var body: some View {
        Button { action(reaction.key) } label: {
            // Menu palettes only render images, so the emoji is drawn into one.
            Image(uiImage: reaction.key.reactionPaletteImage(isOn: isOn))
        }
        .accessibilityLabel(isOn ? L10n.a11yRemoveReaction(reaction.key) : L10n.a11yAddReaction(reaction.key))
    }
}

private extension String {
    func reactionPaletteImage(isOn: Bool) -> UIImage {
        let size = CGSize(width: 34, height: 34)
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24)]
        let textSize = (self as NSString).size(withAttributes: attributes)
        
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            if isOn {
                UIColor.systemGray.withAlphaComponent(0.35).setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            }
            
            (self as NSString).draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                                y: (size.height - textSize.height) / 2),
                                    withAttributes: attributes)
        }
        
        return image.withRenderingMode(.alwaysOriginal)
    }
}
