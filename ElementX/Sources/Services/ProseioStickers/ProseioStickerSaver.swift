//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

/// Proseio: adds stickers to the user's MSC2545 pack, "Meus stickers" (ADR 0029, 0033).
/// One place for the picker's import, "make from a photo" and "save to my stickers" in the timeline.
struct ProseioStickerSaver {
    let clientProxy: ClientProxyProtocol
    
    /// Returns how many stickers were new. 0 means they were already in the pack.
    func add(_ candidates: [StickerImportCandidate]) async -> Result<Int, ProseioAPIError> {
        guard let homeserverURL = URL(string: clientProxy.homeserver) else {
            return .failure(.unexpectedResponse(statusCode: nil))
        }
        let client = StickerPackClient(homeserverURL: homeserverURL)
        let userID = clientProxy.userID
        do {
            let added = try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { token throws(ProseioAPIError) in
                try await client.importStickers(candidates, userID: userID, accessToken: token)
            }
            return .success(added)
        } catch {
            MXLog.error("Adding stickers failed: \(error)")
            return .failure(error)
        }
    }
}
