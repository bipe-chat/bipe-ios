//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipeStickerPickerScreenViewModelAction {
    case dismiss
}

struct BipeStickerPickerScreenViewState: BindableState {
    enum Content: Equatable {
        case loading
        case loaded([StickerPack])
        case failed
    }
    
    /// The room the picker sends to. Its own packs show as "From this chat".
    let roomID: String
    var content = Content.loading
    /// Blocks a second tap while a sticker is on its way.
    var isSending = false
    var isImporting = false
    
    var bindings = BipeStickerPickerScreenViewStateBindings()
}

struct BipeStickerPickerScreenViewStateBindings {
    var isShowingImportHelp = false
    var isShowingFileImporter = false
    var isShowingPhotoPicker = false
}

enum BipeStickerPickerScreenViewAction {
    case retry
    case send(Sticker)
    case close
    /// Import from a WhatsApp chat export (a ZIP) or from WebP and PNG files.
    case showImportHelp
    case chooseImportFiles
    case importFiles([URL])
    /// The photo picked for "Make from a photo".
    case makeSticker(Data)
}
