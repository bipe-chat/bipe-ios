//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import PhotosUI
import SwiftUI

struct BipePublicProfileScreen: View {
    @Bindable var context: BipePublicProfileScreenViewModel.Context
    @State private var selectedPhoto: PhotosPickerItem?
    
    private enum Focus { case name, bio }
    @FocusState private var focus: Focus?
    
    var body: some View {
        Form {
            if context.viewState.needsHandle {
                needsHandleSection
            }
            toggleSection
            photoSection
            nameSection
            bioSection
            if let url = context.viewState.shareURL {
                shareSection(url: url)
            }
        }
        .compoundList()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(BipeStrings.settingsPublicProfile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(BipeStrings.publicProfileSave, action: save)
                    .disabled(!context.viewState.canSave)
            }
        }
        .alert(item: $context.alertInfo)
        .onChange(of: context.name) { context.send(viewAction: .fieldsChanged) }
        .onChange(of: context.bio) { context.send(viewAction: .fieldsChanged) }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            selectedPhoto = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                context.send(viewAction: .photoPicked(data))
            }
        }
    }
    
    private var needsHandleSection: some View {
        Section {
            ListRow(label: .default(title: BipeStrings.settingsHandle, icon: \.userProfile),
                    kind: .navigationLink {
                        context.send(viewAction: .openHandle)
                    })
        } footer: {
            Text(BipeStrings.publicProfileNeedsHandle)
                .compoundListSectionFooter()
        }
    }
    
    private var toggleSection: some View {
        Section {
            ListRow(label: .default(title: BipeStrings.publicProfileToggle, icon: \.webBrowser),
                    kind: .toggle($context.isEnabled))
                .disabled(context.viewState.isLoading || context.viewState.handle == nil)
        } footer: {
            Text(BipeStrings.publicProfileFooter)
                .compoundListSectionFooter()
        }
    }
    
    private var photoSection: some View {
        Section {
            ListRow(kind: .custom {
                photo
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            })
            ListRow(kind: .custom {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    // The label builder isn't isolated in SwiftUI's signature but is only ever called on the main actor.
                    MainActor.assumeIsolated {
                        ListRowLabel.action(title: BipeStrings.publicProfilePhotoChange, icon: \.takePhoto)
                    }
                }
            })
            if context.viewState.hasPhoto {
                ListRow(label: .action(title: BipeStrings.publicProfilePhotoRemove, icon: \.delete, role: .destructive),
                        kind: .button {
                            context.send(viewAction: .removePhoto)
                        })
            }
        }
        .disabled(context.viewState.isLoading)
    }
    
    private var photo: some View {
        Group {
            if let data = context.viewState.pendingPhoto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = context.viewState.savedPhotoURL {
                // The public photo URL answers 404 while the profile is off: show the placeholder then.
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    photoPlaceholder
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
    
    private var photoPlaceholder: some View {
        CompoundIcon(\.userProfile, size: .custom(48), relativeTo: .compound.headingLG)
            .foregroundStyle(.compound.iconSecondary)
            .frame(width: 96, height: 96)
            .background(Color.compound.bgSubtleSecondary)
    }
    
    private var nameSection: some View {
        Section {
            ListRow(label: .plain(title: BipeStrings.publicProfileName),
                    kind: .textField(text: $context.name, axis: .horizontal))
                .focused($focus, equals: .name)
                .disabled(context.viewState.isLoading)
        } header: {
            Text(BipeStrings.publicProfileName)
                .compoundListSectionHeader()
        } footer: {
            if let footer = context.viewState.nameFooter {
                Text(footer)
                    .compoundListSectionFooter()
                    .foregroundStyle(.compound.textCriticalPrimary)
            }
        }
    }
    
    private var bioSection: some View {
        Section {
            ListRow(label: .plain(title: BipeStrings.publicProfileBioPlaceholder),
                    kind: .textField(text: $context.bio, axis: .vertical))
                .focused($focus, equals: .bio)
                .lineLimit(3...)
                .disabled(context.viewState.isLoading)
        } header: {
            Text(BipeStrings.publicProfileBio)
                .compoundListSectionHeader()
        } footer: {
            if let footer = context.viewState.bioFooter {
                Text(footer)
                    .compoundListSectionFooter()
                    .foregroundStyle(.compound.textCriticalPrimary)
            }
        }
    }
    
    private func shareSection(url: URL) -> some View {
        Section {
            ListRow(kind: .custom {
                ShareLink(item: url) {
                    MainActor.assumeIsolated {
                        ListRowLabel.action(title: BipeStrings.publicProfileShare, icon: \.shareIos)
                    }
                }
            })
        }
    }
    
    private func save() {
        guard context.viewState.canSave else { return }
        focus = nil
        context.send(viewAction: .save)
    }
}

// MARK: - Previews

struct BipePublicProfileScreen_Previews: PreviewProvider {
    static let viewModel = BipePublicProfileScreenViewModel(apiClient: BipeAPIClient(baseURL: "https://api.example.com"),
                                                            userSession: UserSessionMock(.init()),
                                                            userIndicatorController: UserIndicatorControllerMock())
    
    static var previews: some View {
        ElementNavigationStack {
            BipePublicProfileScreen(context: viewModel.context)
        }
    }
}
