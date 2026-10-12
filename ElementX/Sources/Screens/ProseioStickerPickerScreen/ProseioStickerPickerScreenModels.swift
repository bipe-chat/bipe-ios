//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

enum ProseioStickerPickerScreenViewModelAction {
    case dismiss
}

struct ProseioStickerPickerScreenViewState: BindableState {
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
    
    var bindings = ProseioStickerPickerScreenViewStateBindings()
}

struct ProseioStickerPickerScreenViewStateBindings {
    var isShowingImportHelp = false
    var isShowingFileImporter = false
}

enum ProseioStickerPickerScreenViewAction {
    case retry
    case send(Sticker)
    case close
    /// Import from a WhatsApp chat export (a ZIP) or from WebP and PNG files.
    case showImportHelp
    case chooseImportFiles
    case importFiles([URL])
}
