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
    
    /// Bipe: the list shows only archived rooms while the archive is open, so the action there is unarchive.
    private var isShowingArchive: Bool {
        context.viewState.isShowingBipeArchive
    }
    
    private var archiveTitle: String {
        isShowingArchive ? BipeStrings.unarchiveAction : BipeStrings.archiveAction
    }
    
    private var archiveSymbol: String {
        isShowingArchive ? "tray.and.arrow.up" : "archivebox"
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
                    .bipeSwipeAction(title: archiveTitle, systemImage: archiveSymbol) {
                        context.send(viewAction: .setRoomArchived(roomIdentifier: room.id, isArchived: !isShowingArchive))
                    }
                    .contextMenu {
                        if room.badges.isDotShown {
                            Button {
                                context.send(viewAction: .markRoomAsRead(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsRead, icon: \.markAsRead)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsUnread(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsUnread, icon: \.markAsUnread)
                            }
                        }
                        
                        if supportsMultipleWindows {
                            Button {
                                context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                            } label: {
                                Label("Open in new window", icon: \.spotlight)
                            }
                        }
                        
                        if room.isFavourite {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: false))
                            } label: {
                                Label(L10n.commonFavourited, icon: \.favouriteSolid)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: true))
                            } label: {
                                Label(L10n.commonFavourite, icon: \.favourite)
                            }
                        }
                        
                        Button {
                            context.send(viewAction: .setRoomArchived(roomIdentifier: room.id, isArchived: !isShowingArchive))
                        } label: {
                            Label(archiveTitle, systemImage: archiveSymbol)
                        }
                        
                        Button {
                            context.send(viewAction: .setRoomMuted(roomIdentifier: room.id, isMuted: !room.badges.isMuteShown))
                        } label: {
                            if room.badges.isMuteShown {
                                Label(L10n.commonUnmute, icon: \.notifications)
                            } else {
                                Label(L10n.commonMute, icon: \.notificationsOff)
                            }
                        }
                        
                        Button {
                            context.send(viewAction: .showRoomDetails(roomIdentifier: room.id))
                        } label: {
                            Label(L10n.commonSettings, icon: \.settings)
                        }
                        
                        if context.viewState.reportRoomEnabled {
                            Button(role: .destructive) {
                                context.send(viewAction: .reportRoom(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.actionReportRoom, icon: \.chatProblem)
                            }
                        }
                        
                        Button(role: .destructive) {
                            context.send(viewAction: .leaveRoom(roomIdentifier: room.id))
                        } label: {
                            Label(room.isDirect ? L10n.actionLeaveConversation : L10n.actionLeaveRoom, icon: \.leave) // Bipe: a DM is a conversation
                        }
                    }
            }
        }
    }
}
