//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import SwiftUI

struct HomeScreenRoomList: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    
    @ObservedObject var context: HomeScreenViewModel.Context
    
    /// Bipe: the row's own tag picks the action, so an archived chat found by search also unarchives.
    private func archiveTitle(_ room: HomeScreenRoom) -> String {
        room.isLowPriority ? BipeStrings.unarchiveAction : BipeStrings.archiveAction
    }
    
    private func archiveSymbol(_ room: HomeScreenRoom) -> String {
        room.isLowPriority ? "tray.and.arrow.up" : "archivebox"
    }
    
    var body: some View {
        // Hide the room list when the search bar is focused but the query is empty
        // This works hand in hand with the room list service layer filtering and
        // avoids glitches when focusing the search bar
        if !context.viewState.shouldHideRoomList {
            content
        }
    }
    
    private var content: some View {
        ForEach(context.viewState.visibleRooms) { room in
            switch room.type {
            case .placeholder:
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                    .redacted(reason: .placeholder)
            case .invite:
                HomeScreenInviteCell(room: room, context: context, hideInviteAvatars: context.viewState.hideInviteAvatars)
            case .knock:
                HomeScreenKnockedCell(room: room, context: context)
            case .room:
                let isSelected = context.viewState.selectedRoomID == room.id
                
                HomeScreenRoomCell(room: room,
                                   isSelected: isSelected,
                                   mediaProvider: context.mediaProvider,
                                   action: context.send)
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                    })
                    .bipeSwipeAction(title: archiveTitle(room), systemImage: archiveSymbol(room)) {
                        context.send(viewAction: .setRoomArchived(roomIdentifier: room.id, isArchived: !room.isLowPriority))
                    }
                    .contextMenu {
                        if room.badges.isDotShown {
                            Button {
                                context.send(viewAction: .markRoomAsRead(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsRead, systemImage: "envelope.open")
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsUnread(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsUnread, systemImage: "envelope.badge")
                            }
                        }
                        
                        if supportsMultipleWindows {
                            Button {
                                context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                            } label: {
                                Label("Open in new window", systemImage: "macwindow.badge.plus")
                            }
                        }
                        
                        if room.isFavourite {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: false))
                            } label: {
                                Label(L10n.commonFavourited, systemImage: "star.fill")
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: true))
                            } label: {
                                Label(L10n.commonFavourite, systemImage: "star")
                            }
                        }
                        
                        Button {
                            context.send(viewAction: .setRoomArchived(roomIdentifier: room.id, isArchived: !room.isLowPriority))
                        } label: {
                            Label(archiveTitle(room), systemImage: archiveSymbol(room))
                        }
                        
                        Button {
                            context.send(viewAction: .setRoomMuted(roomIdentifier: room.id, isMuted: !room.badges.isMuteShown))
                        } label: {
                            if room.badges.isMuteShown {
                                Label(L10n.commonUnmute, systemImage: "bell")
                            } else {
                                Label(L10n.commonMute, systemImage: "bell.slash")
                            }
                        }
                        
                        Button {
                            context.send(viewAction: .showRoomDetails(roomIdentifier: room.id))
                        } label: {
                            Label(L10n.commonSettings, systemImage: "gearshape")
                        }
                        
                        if context.viewState.reportRoomEnabled {
                            Button(role: .destructive) {
                                context.send(viewAction: .reportRoom(roomIdentifier: room.id))
                            } label: {
                                // Bipe: a DM says "conversa", never "sala" (bipe#507).
                                // Bipe: grupo, not sala (bipe#508)
                                Label(room.isDM ? BipeStrings.dmReport : BipeStrings.groupActionReportRoom, systemImage: "exclamationmark.bubble")
                            }
                        }
                        
                        // Bipe (bipe#464): a DM has no room leave. "Apagar conversa" hides it and keeps you in it.
                        // Bipe (bipe#524): the SDK isDm decides, as on every other screen.
                        if room.isDM {
                            Button(role: .destructive) {
                                context.send(viewAction: .bipeDeleteChat(roomIdentifier: room.id))
                            } label: {
                                Label(BipeStrings.dmDeleteAction, systemImage: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                context.send(viewAction: .leaveRoom(roomIdentifier: room.id))
                            } label: {
                                // Bipe: grupo, not sala (bipe#508)
                                Label(BipeStrings.groupActionLeaveRoom, systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
            }
        }
    }
}
