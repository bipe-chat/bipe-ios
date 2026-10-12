//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import ProseioKit
import SwiftUI

typealias ProseioStickerPickerScreenViewModelType = StateStoreViewModelV2<ProseioStickerPickerScreenViewState, ProseioStickerPickerScreenViewAction>

/// Proseio: the sticker picker (ADR 0029, packs per ADR 0033).
class ProseioStickerPickerScreenViewModel: ProseioStickerPickerScreenViewModelType, ProseioStickerPickerScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let roomProxy: JoinedRoomProxyProtocol
    private let threadRootEventID: String?
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let actionsSubject: PassthroughSubject<ProseioStickerPickerScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioStickerPickerScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(clientProxy: ClientProxyProtocol,
         roomProxy: JoinedRoomProxyProtocol,
         threadRootEventID: String?,
         mediaProvider: MediaProviderProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.clientProxy = clientProxy
        self.roomProxy = roomProxy
        self.threadRootEventID = threadRootEventID
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: ProseioStickerPickerScreenViewState(roomID: roomProxy.id), mediaProvider: mediaProvider)
        
        Task { await loadPacks() }
    }
    
    override func process(viewAction: ProseioStickerPickerScreenViewAction) {
        switch viewAction {
        case .retry:
            Task { await loadPacks() }
        case .send(let sticker):
            guard !state.isSending else { return }
            Task { await send(sticker) }
        case .close:
            actionsSubject.send(.dismiss)
        case .showImportHelp:
            state.bindings.isShowingImportHelp = true
        case .chooseImportFiles:
            state.bindings.isShowingFileImporter = true
        case .importFiles(let urls):
            guard !state.isImporting else { return }
            Task { await importFiles(urls) }
        }
    }
    
    // MARK: - Private
    
    private func loadPacks() async {
        state.content = .loading
        guard let homeserverURL = URL(string: clientProxy.homeserver) else {
            MXLog.error("Sticker packs: invalid homeserver URL")
            state.content = .failed
            return
        }
        let client = StickerPackClient(homeserverURL: homeserverURL)
        let userID = clientProxy.userID
        let roomID = roomProxy.id
        do {
            let packs = try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { token throws(ProseioAPIError) in
                try await client.packs(userID: userID, roomID: roomID, accessToken: token)
            }
            state.content = .loaded(packs)
        } catch {
            MXLog.error("Sticker packs failed to load: \(error)")
            state.content = .failed
        }
    }
    
    private func importFiles(_ urls: [URL]) async {
        state.isImporting = true
        userIndicatorController.submitIndicator(UserIndicator(id: importIndicatorID,
                                                              type: .modal,
                                                              title: ProseioStrings.stickersImportProgress,
                                                              persistent: true))
        defer {
            state.isImporting = false
            userIndicatorController.retractIndicatorWithId(importIndicatorID)
        }
        
        let candidates = await Task.detached { StickerImporter.candidates(from: urls) }.value
        guard !candidates.isEmpty else {
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.stickersImportNone))
            return
        }
        guard let homeserverURL = URL(string: clientProxy.homeserver) else {
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.stickersImportFailed))
            return
        }
        
        let client = StickerPackClient(homeserverURL: homeserverURL)
        let userID = clientProxy.userID
        do {
            let added = try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { token throws(ProseioAPIError) in
                try await client.importStickers(candidates, userID: userID, accessToken: token)
            }
            let title = added > 0 ? ProseioStrings.stickersImportDone(added.formatted()) : ProseioStrings.stickersImportNone
            userIndicatorController.submitIndicator(UserIndicator(title: title))
        } catch {
            MXLog.error("Sticker import failed: \(error)")
            userIndicatorController.submitIndicator(UserIndicator(title: ProseioStrings.stickersImportFailed))
        }
        await loadPacks()
    }
    
    private var importIndicatorID: String {
        "\(ProseioStickerPickerScreenViewModel.self)-Import"
    }
    
    private func send(_ sticker: Sticker) async {
        state.isSending = true
        defer { state.isSending = false }
        
        switch await roomProxy.sendRaw(eventType: "m.sticker", content: sticker.eventContentJSON(threadRootID: threadRootEventID)) {
        case .success:
            actionsSubject.send(.dismiss)
        case .failure:
            userIndicatorController.submitIndicator(UserIndicator(title: L10n.errorUnknown))
        }
    }
}
