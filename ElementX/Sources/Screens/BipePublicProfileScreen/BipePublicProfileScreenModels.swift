//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import SwiftUI

enum BipePublicProfileScreenViewModelAction {
    case openHandle
}

struct BipePublicProfileScreenViewState: BindableState {
    var isLoading = true
    /// The profile as the server has it. `nil` until loaded.
    var savedProfile: BipeMyProfile?
    /// A re-encoded JPEG waiting for Save.
    var pendingPhoto: Data?
    var removesPhoto = false
    var serverProblem: BipeProfileProblem?
    
    var bindings = BipePublicProfileScreenViewStateBindings()
    
    var handle: String? {
        savedProfile?.handle
    }
    
    var needsHandle: Bool {
        savedProfile != nil && handle == nil
    }
    
    var shareURL: URL? {
        guard savedProfile?.enabled == true, let handle else { return nil }
        return BipeProfileLink.url(handle: handle)
    }
    
    /// The server photo, unless the user picked another or removed it.
    var savedPhotoURL: URL? {
        removesPhoto ? nil : savedProfile?.photoUrl
    }
    
    var hasPhoto: Bool {
        pendingPhoto != nil || (!removesPhoto && savedProfile?.hasPhoto == true)
    }
    
    var problem: BipeProfileProblem? {
        BipePublicProfileRules.profileProblem(name: bindings.name, bio: bindings.bio) ?? serverProblem
    }
    
    var nameFooter: String? {
        problem.flatMap { $0.isNameProblem ? $0.localizedMessage : nil }
    }
    
    var bioFooter: String? {
        problem.flatMap { $0.isNameProblem ? nil : $0.localizedMessage }
    }
    
    var hasChanges: Bool {
        guard let savedProfile else { return false }
        return bindings.isEnabled != savedProfile.enabled
            || bindings.name != savedProfile.name
            || bindings.bio != savedProfile.bio
            || pendingPhoto != nil
            || removesPhoto
    }
    
    var canSave: Bool {
        !isLoading && hasChanges && problem == nil && !(bindings.isEnabled && handle == nil)
    }
}

struct BipePublicProfileScreenViewStateBindings {
    var isEnabled = false
    var name = ""
    var bio = ""
    var alertInfo: AlertInfo<BipePublicProfileScreenAlertType>?
}

enum BipePublicProfileScreenAlertType: Hashable {
    case error
}

enum BipePublicProfileScreenViewAction: CustomStringConvertible {
    case fieldsChanged
    /// The raw data of the image the user picked.
    case photoPicked(Data)
    case removePhoto
    case save
    case openHandle
    
    /// Never prints the photo.
    var description: String {
        switch self {
        case .fieldsChanged: "fieldsChanged"
        case .photoPicked: "photoPicked"
        case .removePhoto: "removePhoto"
        case .save: "save"
        case .openHandle: "openHandle"
        }
    }
}
