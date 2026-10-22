//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

/// Tells the inviter, once per join, that someone joined with their invite: a toast when the app opens.
/// The first check on a device only records existing joins, so old joins are not announced.
/// Then sends the notes of joined invites (ADR 0136).
@MainActor
struct BipeInviteJoinNotifier {
    let apiBaseURL: URL
    let clientProxy: ClientProxyProtocol
    let handleResolver: BipeHandleResolver?
    let userIndicatorController: UserIndicatorControllerProtocol
    
    func run() async {
        let store = BipeInviteStore(userID: clientProxy.userID)
        let apiClient = BipeAPIClient(baseURL: apiBaseURL)
        let myInvites: BipeMyInvites
        do {
            myInvites = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
        } catch {
            MXLog.error("Bipe invite join check failed: \(error)")
            return
        }
        
        await announceJoins(in: myInvites, store: store)
        await BipeInviteNoteSender(apiClient: apiClient, clientProxy: clientProxy).send(for: myInvites.invites)
    }
    
    private func announceJoins(in myInvites: BipeMyInvites, store: BipeInviteStore) async {
        let joined = myInvites.invites.filter { $0.status == .used && $0.joinedUserId != nil }
        let joinedIDs = Set(joined.map(\.id))
        guard let seen = store.seenJoinedInviteIDs() else {
            store.setSeenJoinedInviteIDs(joinedIDs)
            return
        }
        store.setSeenJoinedInviteIDs(seen.union(joinedIDs))
        
        for invite in joined where !seen.contains(invite.id) {
            guard let userID = invite.joinedUserId else { continue }
            _ = await handleResolver?.resolve(userID)
            let name = handleResolver?.displayText(for: userID) ?? userID
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.invitesJoined(name), icon: \.userAdd))
        }
    }
}

/// Bipe ADR 0136: sends the inviter's note as the first message in the chat with the person who joined.
/// Only into an existing, joined DM: the invitee's app makes the chat, so a second one is never created here.
/// Without that chat the note stays for the next run. At most once per invite: the note is removed before the send
/// and put back only when the send fails.
@MainActor
struct BipeInviteNoteSender {
    let apiClient: BipeAPIClient
    let clientProxy: ClientProxyProtocol
    
    /// Reads the invites only when this device holds a note. For the retry after an invite-pair chat is accepted:
    /// `joinedRoomID` is that chat, because the SDK can list it as a DM only after the next sync.
    func run(joinedRoomID: String? = nil) async {
        guard !BipeInviteStore(userID: clientProxy.userID).notes().isEmpty else { return }
        do {
            let myInvites = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
            await send(for: myInvites.invites, joinedRoomID: joinedRoomID)
        } catch {
            MXLog.error("Bipe invite notes: invites read failed: \(error)")
        }
    }
    
    func send(for invites: [BipeInvite], joinedRoomID: String? = nil) async {
        let store = BipeInviteStore(userID: clientProxy.userID)
        for invite in invites where invite.status == .used {
            guard let userID = invite.joinedUserId, userID != clientProxy.userID, store.notes()[invite.id] != nil else { continue }
            guard let room = await directRoom(with: userID, joinedRoomID: joinedRoomID) else {
                MXLog.info("Bipe invite note for \(invite.id) waits for the chat with \(userID)")
                continue
            }
            // Read again after the awaits: another run can have sent it meanwhile.
            guard let note = store.notes()[invite.id] else { continue }
            store.removeNote(forInviteID: invite.id)
            switch await room.timeline.sendMessage(note, html: nil, inReplyToEventID: nil, intentionalMentions: .empty) {
            case .success:
                MXLog.info("Bipe invite note for \(invite.id) sent")
            case .failure(let error):
                MXLog.error("Bipe invite note for \(invite.id) not sent: \(error)")
                store.saveNote(note, forInviteID: invite.id)
            }
        }
    }
    
    private func directRoom(with userID: String, joinedRoomID: String?) async -> JoinedRoomProxyProtocol? {
        if let roomID = try? clientProxy.directRoomForUserID(userID).get(),
           case .joined(let room) = await clientProxy.roomForIdentifier(roomID) {
            return room
        }
        guard let joinedRoomID, case .joined(let room) = await clientProxy.roomForIdentifier(joinedRoomID) else { return nil }
        let info = room.infoPublisher.value
        // Bipe: one DM test, the SDK isDm (bipe#524).
        return info.isDM && info.heroes.contains { $0.userId == userID } ? room : nil
    }
}
