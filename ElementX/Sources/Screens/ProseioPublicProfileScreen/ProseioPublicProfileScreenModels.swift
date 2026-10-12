//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import ProseioKit
import SwiftUI

enum ProseioPublicProfileScreenViewModelAction {
    case openHandle
}

struct ProseioPublicProfileScreenViewState: BindableState {
    var isLoading = true
    /// The profile as the server has it. `nil` until loaded.
    var savedProfile: ProseioMyProfile?
    /// A re-encoded JPEG waiting for Save.
    var pendingPhoto: Data?
    var removesPhoto = false
    var serverProblem: ProseioProfileProblem?

    var bindings = ProseioPublicProfileScreenViewStateBindings()

    var handle: String? {
        savedProfile?.handle
    }

    var needsHandle: Bool {
        savedProfile != nil && handle == nil
    }

    var shareURL: URL? {
        guard savedProfile?.enabled == true, let handle else { return nil }
        return ProseioProfileLink.url(handle: handle)
    }

    /// The server photo, unless the user picked another or removed it.
    var savedPhotoURL: URL? {
        removesPhoto ? nil : savedProfile?.photoUrl
    }

    var hasPhoto: Bool {
        pendingPhoto != nil || (!removesPhoto && savedProfile?.hasPhoto == true)
    }

    var problem: ProseioProfileProblem? {
        ProseioPublicProfileRules.profileProblem(name: bindings.name, bio: bindings.bio) ?? serverProblem
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

struct ProseioPublicProfileScreenViewStateBindings {
    var isEnabled = false
    var name = ""
    var bio = ""
    var alertInfo: AlertInfo<ProseioPublicProfileScreenAlertType>?
}

enum ProseioPublicProfileScreenAlertType: Hashable {
    case error
}

enum ProseioPublicProfileScreenViewAction: CustomStringConvertible {
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
