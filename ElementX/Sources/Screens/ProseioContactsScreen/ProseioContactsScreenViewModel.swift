//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Contacts
import ProseioKit
import SwiftUI

typealias ProseioContactsScreenViewModelType = StateStoreViewModelV2<ProseioContactsScreenViewState, ProseioContactsScreenViewAction>

class ProseioContactsScreenViewModel: ProseioContactsScreenViewModelType, ProseioContactsScreenViewModelProtocol {
    private let apiClient: ProseioAPIClient
    private let clientProxy: ClientProxyProtocol
    private let contactStore = CNContactStore()
    /// The server value, so loading it does not send it back.
    private var savedDiscoverable = true
    
    private let actionsSubject: PassthroughSubject<ProseioContactsScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ProseioContactsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(apiClient: ProseioAPIClient, clientProxy: ClientProxyProtocol) {
        self.apiClient = apiClient
        self.clientProxy = clientProxy
        super.init(initialViewState: ProseioContactsScreenViewState())
        
        state.access = Self.currentAccess()
        Task { await loadPhoneStatus() }
        if state.access == .granted {
            Task { await search() }
        }
    }
    
    override func process(viewAction: ProseioContactsScreenViewAction) {
        switch viewAction {
        case .requestAccess:
            Task { await requestAccess() }
        case .discoverableChanged:
            guard state.bindings.discoverableByPhone != savedDiscoverable else { return }
            Task { await saveDiscoverable(state.bindings.discoverableByPhone) }
        case .openUserProfile(let userID):
            actionsSubject.send(.openUserProfile(userID: userID))
        case .openInvites:
            actionsSubject.send(.openInvites)
        }
    }
    
    // MARK: - Private
    
    private static func currentAccess() -> ProseioContactsAccess {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        case .authorized, .limited: .granted
        @unknown default: .denied
        }
    }
    
    private func requestAccess() async {
        let granted = (try? await contactStore.requestAccess(for: .contacts)) ?? false
        state.access = granted ? .granted : Self.currentAccess()
        if state.access == .granted { await search() }
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
        
        var matches: [String: ProseioContactsScreenMatch] = [:]
        let phones = Array(namesByPhone.keys)
        for start in stride(from: 0, to: phones.count, by: 500) {
            let batch = Array(phones[start..<min(start + 500, phones.count)])
            do {
                let found = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> [ProseioContactMatch] in
                    try await apiClient.lookupContacts(phones: batch, accessToken: token)
                }
                for match in found where match.userId != clientProxy.userID {
                    matches[match.userId] = ProseioContactsScreenMatch(userID: match.userId, contactName: namesByPhone[match.phone] ?? match.phone)
                }
            } catch {
                MXLog.error("Proseio contact lookup failed: \(error)")
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
                if let e164 = ProseioPhoneNumber.normalize(number.value.stringValue), result[e164] == nil {
                    result[e164] = name
                }
            }
        }
        return result
    }
    
    private func loadPhoneStatus() async {
        do {
            let status = try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) -> ProseioMyPhone in
                try await apiClient.myPhone(accessToken: token)
            }
            state.phoneLinked = status.linked
            savedDiscoverable = status.discoverableByPhone
            state.bindings.discoverableByPhone = status.discoverableByPhone
        } catch {
            MXLog.error("Proseio phone status failed: \(error)")
        }
    }
    
    private func saveDiscoverable(_ value: Bool) async {
        do {
            try await withTokenRetry { [apiClient] (token: String) async throws(ProseioAPIError) in
                try await apiClient.setDiscoverableByPhone(value, accessToken: token)
            }
            savedDiscoverable = value
        } catch {
            MXLog.error("Proseio discovery setting failed: \(error)")
            state.bindings.discoverableByPhone = savedDiscoverable
            state.bindings.alertInfo = AlertInfo(id: .error, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    private func withTokenRetry<T>(_ request: (String) async throws(ProseioAPIError) -> T) async throws(ProseioAPIError) -> T {
        try await ProseioAPIClient.withTokenRetry(accessToken: { [clientProxy] in clientProxy.accessToken }, request)
    }
}
