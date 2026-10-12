//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

struct ProseioStickerPickerScreen: View {
    let context: ProseioStickerPickerScreenViewModel.Context
    
    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
    
    var body: some View {
        content
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .navigationTitle(ProseioStrings.stickersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) {
                        context.send(viewAction: .close)
                    }
                }
            }
            .disabled(context.viewState.isSending)
    }
    
    @ViewBuilder
    private var content: some View {
        switch context.viewState.content {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            message(title: ProseioStrings.stickersErrorLoad, body: nil, showsRetry: true)
        case .loaded(let packs) where packs.isEmpty:
            message(title: ProseioStrings.stickersEmptyTitle, body: ProseioStrings.stickersEmptyBody, showsRetry: false)
        case .loaded(let packs):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(packs) { pack in
                        packSection(pack)
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func packSection(_ pack: StickerPack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title(for: pack))
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textSecondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pack.stickers) { sticker in
                    stickerButton(sticker)
                }
            }
        }
    }
    
    private func stickerButton(_ sticker: Sticker) -> some View {
        Button {
            context.send(viewAction: .send(sticker))
        } label: {
            stickerImage(sticker)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ProseioStrings.a11yStickerSend(sticker.body))
    }
    
    @ViewBuilder
    private func stickerImage(_ sticker: Sticker) -> some View {
        if let url = URL(string: sticker.url) {
            LoadableImage(url: url,
                          mediaType: .generic,
                          size: CGSize(width: 240, height: 240),
                          mediaProvider: context.mediaProvider) { imageView in
                imageView.scaledToFit()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.compound.bgSubtleSecondary)
    }
    
    private func message(title: String, body: String?, showsRetry: Bool) -> some View {
        VStack(spacing: 12) {
            CompoundIcon(\.sticker, size: .medium, relativeTo: .compound.headingMD)
                .foregroundStyle(.compound.iconSecondary)
            Text(title)
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
                .multilineTextAlignment(.center)
            if let body {
                Text(body)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if showsRetry {
                Button(L10n.actionRetry) {
                    context.send(viewAction: .retry)
                }
                .buttonStyle(.compound(.secondary, size: .medium))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func title(for pack: StickerPack) -> String {
        switch pack.source {
        case .user:
            ProseioStrings.stickersPackPersonal
        case .room(let roomID, _):
            pack.displayName ?? (roomID == context.viewState.roomID ? ProseioStrings.stickersPackRoom : ProseioStrings.stickersTitle)
        }
    }
}
