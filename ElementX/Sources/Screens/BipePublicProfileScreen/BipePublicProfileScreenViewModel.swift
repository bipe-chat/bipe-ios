//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipePublicProfileScreenViewModelType = StateStoreViewModelV2<BipePublicProfileScreenViewState, BipePublicProfileScreenViewAction>

class BipePublicProfileScreenViewModel: BipePublicProfileScreenViewModelType, BipePublicProfileScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let mediaProvider: MediaProviderProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let actionsSubject: PassthroughSubject<BipePublicProfileScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipePublicProfileScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: BipeAPIClient,
         userSession: UserSessionProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        clientProxy = userSession.clientProxy
        mediaProvider = userSession.mediaProvider
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: BipePublicProfileScreenViewState())
        
        reload()
    }
    
    override func process(viewAction: BipePublicProfileScreenViewAction) {
        switch viewAction {
        case .fieldsChanged:
            state.serverProblem = nil
        case .photoPicked(let data):
            Task { await usePhoto(data) }
        case .removePhoto:
            state.pendingPhoto = nil
            state.removesPhoto = state.savedProfile?.hasPhoto == true
        case .save:
            Task { await save() }
        case .openHandle:
            actionsSubject.send(.openHandle)
        }
    }
    
    func reload() {
        Task { await loadProfile() }
    }
    
    // MARK: - Private
    
    private func loadProfile() async {
        state.isLoading = true
        defer { state.isLoading = false }
        
        do {
            let profile = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                try await apiClient.myProfile(accessToken: token)
            }
            apply(profile)
            if profile.name.isEmpty {
                await prefillFromMatrixProfile(hasPhoto: profile.hasPhoto)
            }
        } catch {
            MXLog.error("Bipe public profile load failed: \(error)")
            show(error)
        }
    }
    
    /// First time: offer the Matrix display name and photo. Nothing is published until Save.
    private func prefillFromMatrixProfile(hasPhoto: Bool) async {
        let matrixProfile = clientProxy.userProfilePublisher.value
        if let displayName = matrixProfile.displayName {
            state.bindings.name = displayName
        }
        
        guard !hasPhoto,
              let avatarURL = matrixProfile.avatarURL,
              let source = try? MediaSourceProxy(url: avatarURL, mimeType: nil),
              case .success(let data) = await mediaProvider.loadImageDataFromSource(source) else {
            return
        }
        state.pendingPhoto = await Self.reencode(data)
    }
    
    private func usePhoto(_ data: Data) async {
        guard let jpeg = await Self.reencode(data) else {
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: BipeStrings.publicProfilePhotoInvalid)
            return
        }
        state.pendingPhoto = jpeg
        state.removesPhoto = false
    }
    
    private func save() async {
        guard state.canSave, let savedProfile = state.savedProfile else { return }
        
        let update = BipeProfileUpdate(enabled: state.bindings.isEnabled,
                                       name: BipePublicProfileRules.trim(state.bindings.name),
                                       bio: BipePublicProfileRules.trim(state.bindings.bio))
        let pendingPhoto = state.pendingPhoto
        let removesPhoto = state.removesPhoto
        
        state.isLoading = true
        startLoading()
        defer {
            stopLoading()
            state.isLoading = false
        }
        
        do {
            var profile = savedProfile
            if update.enabled != profile.enabled || update.name != profile.name || update.bio != profile.bio {
                profile = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                    try await apiClient.setMyProfile(update, accessToken: token)
                }
                apply(profile, keepingPhotoEdits: true)
            }
            if let pendingPhoto {
                profile = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                    try await apiClient.setMyProfilePhoto(jpeg: pendingPhoto, accessToken: token)
                }
            } else if removesPhoto {
                profile = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyProfile in
                    try await apiClient.deleteMyProfilePhoto(accessToken: token)
                }
            }
            apply(profile)
            userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.publicProfileSaved, icon: \.checkCircle))
        } catch {
            MXLog.error("Bipe public profile save failed: \(error)")
            show(error)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
    
    /// `keepingPhotoEdits` keeps a photo change that is not saved yet, e.g. after the text part of a save.
    private func apply(_ profile: BipeMyProfile, keepingPhotoEdits: Bool = false) {
        state.savedProfile = profile
        state.bindings.isEnabled = profile.enabled
        state.bindings.name = profile.name
        state.bindings.bio = profile.bio
        state.serverProblem = nil
        if !keepingPhotoEdits {
            state.pendingPhoto = nil
            state.removesPhoto = false
        }
    }
    
    private func show(_ error: BipeAPIError) {
        if case .server(.profileInvalid, let reason, _) = error,
           let problem = reason.flatMap(BipeProfileProblem.init(rawValue:)),
           problem != .noHandle {
            state.serverProblem = problem
        } else {
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    /// Decoding and drawing a large photo is slow: keep it off the main actor.
    private nonisolated static func reencode(_ data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            BipeProfilePhoto.jpegData(from: data)
        }.value
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(BipePublicProfileScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
}
