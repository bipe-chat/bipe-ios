//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import Contacts
import SwiftUI

typealias BipeContactsScreenViewModelType = StateStoreViewModelV2<BipeContactsScreenViewState, BipeContactsScreenViewAction>

class BipeContactsScreenViewModel: BipeContactsScreenViewModelType, BipeContactsScreenViewModelProtocol {
    private let apiClient: BipeAPIClient
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let inviteCreator: BipeInviteCreator
    private let contactStore = CNContactStore()
    /// The server value, so loading it does not send it back.
    private var savedDiscoverable = true
    
    private let actionsSubject: PassthroughSubject<BipeContactsScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeContactsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: BipeAPIClient,
         clientProxy: ClientProxyProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController
        inviteCreator = BipeInviteCreator(apiClient: apiClient, userID: clientProxy.userID) { [clientProxy] in clientProxy.accessToken }
        super.init(initialViewState: BipeContactsScreenViewState())
        
        state.access = Self.currentAccess()
        Task { await loadPhoneStatus() }
        if state.access == .granted {
            Task { await search() }
        }
    }
    
    override func process(viewAction: BipeContactsScreenViewAction) {
        switch viewAction {
        case .appeared:
            // Also on the way back from the invites screen, which can create or cancel invites.
            Task { await loadInvites() }
        case .requestAccess:
            Task { await requestAccess() }
        case .discoverableChanged:
            guard state.bindings.discoverableByPhone != savedDiscoverable else { return }
            Task { await saveDiscoverable(state.bindings.discoverableByPhone) }
        case .openUserProfile(let userID):
            actionsSubject.send(.openUserProfile(userID: userID))
        case .openInvites:
            actionsSubject.send(.openInvites)
        case .inviteByLink:
            Task {
                guard let link = await createInvite() else { return }
                state.bindings.shareSheetLink = link
            }
        case .inviteInPerson:
            Task {
                guard let link = await createInvite() else { return }
                state.bindings.qrCodeLink = link
            }
        }
    }
    
    // MARK: - Private
    
    private static func currentAccess() -> BipeContactsAccess {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        case .authorized, .limited: .granted
        @unknown default: .denied
        }
    }
    
    private func requestAccess() async {
        let granted = await (try? contactStore.requestAccess(for: .contacts)) ?? false
        state.access = granted ? .granted : Self.currentAccess()
        if state.access == .granted {
            await search()
        }
    }
    
    private func search() async {
        state.isLoading = true
        defer {
            state.isLoading = false
            state.hasSearched = true
        }
        
        // E.164 number to the contact's name. Reading the address book is slow, so it runs off the main actor.
        let namesByPhone = await Task.detached(priority: .userInitiated) { Self.readAddressBook() }.value
        guard !namesByPhone.isEmpty else {
            state.matches = []
            return
        }
        
        var matches: [String: BipeContactsScreenMatch] = [:]
        let phones = Array(namesByPhone.keys)
        for start in stride(from: 0, to: phones.count, by: 500) {
            let batch = Array(phones[start..<min(start + 500, phones.count)])
            do {
                let found = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> [BipeContactMatch] in
                    try await apiClient.lookupContacts(phones: batch, accessToken: token)
                }
                for match in found where match.userId != clientProxy.userID {
                    matches[match.userId] = BipeContactsScreenMatch(userID: match.userId, contactName: namesByPhone[match.phone] ?? match.phone)
                }
            } catch {
                MXLog.error("Bipe contact lookup failed: \(error)")
                state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
                break
            }
        }
        state.matches = matches.values.sorted { $0.contactName.localizedCaseInsensitiveCompare($1.contactName) == .orderedAscending }
    }
    
    private nonisolated static func readAddressBook() -> [String: String] {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        var result: [String: String] = [:]
        try? CNContactStore().enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
            let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let name = fullName.isEmpty ? contact.nickname : fullName
            for number in contact.phoneNumbers {
                if let e164 = BipePhoneNumber.normalize(number.value.stringValue), result[e164] == nil {
                    result[e164] = name
                }
            }
        }
        return result
    }
    
    private func loadInvites() async {
        do {
            let myInvites = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyInvites in
                try await apiClient.myInvites(accessToken: token)
            }
            state.invitesAvailable = myInvites.available
            state.nextInviteAt = myInvites.nextAvailableAt
            state.joinedUserIDs = myInvites.invites
                .filter { $0.status == .used }
                .compactMap(\.joinedUserId)
                .filter { $0 != clientProxy.userID }
            state.pendingInviteCount = myInvites.invites.count { $0.status == .pending }
        } catch {
            MXLog.error("Bipe invites load failed: \(error)")
        }
    }
    
    private func createInvite() async -> BipeInviteShareLink? {
        guard state.canCreateInvite else { return nil }
        
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID, type: .modal, title: L10n.commonLoading, persistent: true))
        defer { userIndicatorController.retractIndicatorWithId(loadingIndicatorID) }
        
        do {
            let created = try await inviteCreator.create()
            MXLog.info("Bipe invite created \(created)")
            await loadInvites()
            return BipeInviteShareLink(id: created.id, url: created.url)
        } catch {
            MXLog.error("Bipe invite creation failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
            return nil
        }
    }
    
    private var loadingIndicatorID: String {
        "\(BipeContactsScreenViewModel.self)-Loading"
    }
    
    private func loadPhoneStatus() async {
        do {
            let status = try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) -> BipeMyPhone in
                try await apiClient.myPhone(accessToken: token)
            }
            state.phoneLinked = status.linked
            savedDiscoverable = status.discoverableByPhone
            state.bindings.discoverableByPhone = status.discoverableByPhone
        } catch {
            MXLog.error("Bipe phone status failed: \(error)")
        }
    }
    
    private func saveDiscoverable(_ value: Bool) async {
        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(BipeAPIError) in
                try await apiClient.setDiscoverableByPhone(value, accessToken: token)
            }
            savedDiscoverable = value
        } catch {
            MXLog.error("Bipe discovery setting failed: \(error)")
            state.bindings.discoverableByPhone = savedDiscoverable
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(BipeAPIError) -> T) async throws(BipeAPIError) -> T {
        try await BipeAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
}
