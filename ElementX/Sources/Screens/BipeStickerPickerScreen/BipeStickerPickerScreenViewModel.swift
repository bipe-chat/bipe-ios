//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeStickerPickerScreenViewModelType = StateStoreViewModelV2<BipeStickerPickerScreenViewState, BipeStickerPickerScreenViewAction>

/// Bipe: the sticker picker (ADR 0029, packs per ADR 0033).
class BipeStickerPickerScreenViewModel: BipeStickerPickerScreenViewModelType, BipeStickerPickerScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let roomProxy: JoinedRoomProxyProtocol
    private let threadRootEventID: String?
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let actionsSubject: PassthroughSubject<BipeStickerPickerScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeStickerPickerScreenViewModelAction, Never> {
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
        
        super.init(initialViewState: BipeStickerPickerScreenViewState(roomID: roomProxy.id), mediaProvider: mediaProvider)
        
        Task { await loadPacks() }
    }
    
    override func process(viewAction: BipeStickerPickerScreenViewAction) {
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
        case .makeSticker(let photoData):
            guard !state.isImporting else { return }
            Task { await makeSticker(fromPhotoData: photoData) }
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
            let packs = try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }) { token throws(BipeAPIError) in
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
                                                              title: BipeStrings.stickersImportProgress,
                                                              persistent: true))
        defer {
            state.isImporting = false
            userIndicatorController.retractIndicatorWithId(importIndicatorID)
        }
        
        let candidates = await Task.detached { StickerImporter.candidates(from: urls) }.value
        guard !candidates.isEmpty else {
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.stickersImportNone))
            return
        }
        
        switch await BipeStickerSaver(clientProxy: clientProxy).add(candidates) {
        case .success(let added):
            let title = added > 0 ? BipeStrings.stickersImportDone(added.formatted()) : BipeStrings.stickersImportNone
            userIndicatorController.submitIndicator(UserIndicator(title: title))
        case .failure:
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.stickersImportFailed))
        }
        await loadPacks()
    }
    
    /// "Make from a photo": cut out the subject on the device and add the result to "Meus stickers".
    private func makeSticker(fromPhotoData data: Data) async {
        state.isImporting = true
        userIndicatorController.submitIndicator(UserIndicator(id: importIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
        defer {
            state.isImporting = false
            userIndicatorController.retractIndicatorWithId(importIndicatorID)
        }
        
        guard let candidate = await Task.detached(operation: { StickerMaker.sticker(fromImageData: data) }).value,
              case .success = await BipeStickerSaver(clientProxy: clientProxy).add([candidate]) else {
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.stickerSaveFailed))
            return
        }
        userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.stickerSaved, icon: \.checkCircle))
        await loadPacks()
    }
    
    private var importIndicatorID: String {
        "\(BipeStickerPickerScreenViewModel.self)-Import"
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
