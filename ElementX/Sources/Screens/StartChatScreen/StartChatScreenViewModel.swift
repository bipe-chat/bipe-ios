//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK
import BipeKit
import SwiftUI

typealias StartChatScreenViewModelType = StateStoreViewModel<StartChatScreenViewState, StartChatScreenViewAction>

class StartChatScreenViewModel: StartChatScreenViewModelType, StartChatScreenViewModelProtocol {
    private let userSession: UserSessionProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let userDiscoveryService: UserDiscoveryServiceProtocol
    
    private var suggestedUsers = [UserProfile]()
    
    private let actionsSubject: PassthroughSubject<StartChatScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<StartChatScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         analytics: AnalyticsServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         userDiscoveryService: UserDiscoveryServiceProtocol) {
        self.userSession = userSession
        self.analytics = analytics
        self.userIndicatorController = userIndicatorController
        self.userDiscoveryService = userDiscoveryService
        
        super.init(initialViewState: StartChatScreenViewState(userID: userSession.clientProxy.userID), mediaProvider: userSession.mediaProvider)
        
        setupBindings()
        loadBipeInviter()
        
        Task {
            suggestedUsers = await userSession.clientProxy.recentConversationCounterparts()
            
            if state.usersSection.type == .suggestions {
                state.usersSection = .init(type: .suggestions, users: suggestedUsers)
            }
        }
    }
    
    // MARK: - Public
    
    override func process(viewAction: StartChatScreenViewAction) {
        switch viewAction {
        case .close:
            actionsSubject.send(.close)
        case .createRoom:
            actionsSubject.send(.createRoom)
        case .selectUser(let user):
            showLoadingIndicator(delay: .milliseconds(200))
            
            let currentDirectRoom = userSession.clientProxy.directRoomForUserID(user.id)
            switch currentDirectRoom {
            case .success(.some(let roomId)):
                hideLoadingIndicator()
                actionsSubject.send(.showRoom(roomID: roomId))
            case .success:
                Task {
                    // If an error occured while fetching the identity, assume they are unknown.
                    let isUnknown = if case .success(let identity) = await self.userSession.clientProxy.userIdentity(for: user.id, fallBackToServer: false) {
                        identity == nil
                    } else {
                        true
                    }
                    self.state.bindings.selectedUserToInvite = UserToInvite(user: user, isUnknown: isUnknown)
                    hideLoadingIndicator()
                }
            case .failure:
                hideLoadingIndicator()
                displayError()
            }
        case .createDM(let user):
            Task { await createDirectRoom(user: user) }
        case .joinRoomByAddress:
            joinRoomByAddress()
        case .openRoomDirectorySearch:
            actionsSubject.send(.openRoomDirectorySearch)
        case .bipeInviteToApp:
            Task { await bipeInviteToApp() }
        }
    }
    
    /// Bipe: sign-up needs a personal invite, so "invite people" shares one instead of a profile link.
    private func bipeInviteToApp() async {
        let clientProxy = userSession.clientProxy
        let creator = BipeInviteCreator(apiClient: BipeAPIClient(baseURL: userSession.userSettings.app.bipeAPIBaseURL),
                                        userID: clientProxy.userID) { clientProxy.accessToken }
        showLoadingIndicator()
        defer { hideLoadingIndicator() }
        
        do {
            switch try await creator.createIfAvailable() {
            case .created(let created):
                MXLog.info("Bipe invite created \(created)")
                state.bindings.bipeInviteShareLink = BipeInviteShareLink(id: created.id, url: created.url)
            case .noneLeft(let nextAvailableAt):
                state.bindings.alertInfo = AlertInfo(id: .bipeInvite, title: BipeStrings.invitesTitle, message: BipeInviteQuota.noneLeft(nextAvailableAt: nextAvailableAt))
            }
        } catch {
            MXLog.error("Bipe invite creation failed: \(error)")
            state.bindings.alertInfo = AlertInfo(id: .bipeInvite, title: L10n.commonError, message: error.localizedMessage)
        }
    }
    
    // MARK: - Private
    
    @CancellableTask private var resolveAliasTask: Task<Void, Never>?
    private var internalRoomAddressState: JoinByAddressState = .example
    
    private func setupBindings() {
        context.$viewState
            .map(\.bindings.searchQuery)
            .debounceTextQueriesAndRemoveDuplicates()
            .sink { [weak self] _ in
                self?.fetchUsers()
            }
            .store(in: &cancellables)
        
        context.$viewState
            .map(\.bindings.roomAddress)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                state.joinByAddressState = .example
                internalRoomAddressState = .example
            }
            .store(in: &cancellables)
        
        context.$viewState
            .map(\.bindings.roomAddress)
            .debounceTextQueriesAndRemoveDuplicates()
            .sink { [weak self] roomAddress in
                guard let self else {
                    return
                }
                resolveRoomAddress(roomAddress)
            }
            .store(in: &cancellables)
    }
    
    private func resolveRoomAddress(_ roomAddress: String) {
        guard !roomAddress.isEmpty,
              isRoomAliasFormatValid(alias: roomAddress) else {
            internalRoomAddressState = .invalidAddress
            resolveAliasTask = nil
            return
        }
        
        resolveAliasTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer { resolveAliasTask = nil }
            
            guard case let .success(resolved) = await userSession.clientProxy.resolveRoomAlias(roomAddress) else {
                if Task.isCancelled {
                    return
                }
                internalRoomAddressState = .addressNotFound
                return
            }
            
            guard !Task.isCancelled else {
                return
            }
            
            let result = JoinByAddressState.addressFound(address: roomAddress, roomID: resolved.roomId)
            internalRoomAddressState = result
            state.joinByAddressState = result
        }
    }
    
    @CancellableTask
    private var fetchUsersTask: Task<Void, Never>?
    
    private func fetchUsers() {
        // Bipe: owned handles can be 2 characters (ADR 0065), below the directory minimum. The handle lookup has no minimum.
        let searchesDirectory = context.searchQuery.count >= 3
        let isHandle = BipeHandle.localProblem(for: BipeHandle.sanitize(context.searchQuery).lowercased()) == nil
        guard searchesDirectory || isHandle else {
            state.usersSection = .init(type: .suggestions, users: suggestedUsers)
            state.bipeHandleNotFound = nil
            return
        }
        
        fetchUsersTask = Task {
            let query = context.searchQuery
            async let bipeResult = bipeLookUp(query: query)
            let result: Result<[UserProfile], UserDiscoveryErrorType> = searchesDirectory ? await userDiscoveryService.searchProfiles(with: query) : .success([])
            let bipeLookUp = await bipeResult
            
            guard !Task.isCancelled else { return }
            
            let bipeUsers = bipeLookUp?.profile.map { [$0] } ?? []
            state.bipeHandleNotFound = bipeLookUp?.profile == nil ? bipeLookUp?.handle : nil
            
            switch result {
            case .success(let users):
                state.usersSection = .init(type: .searchResult, users: bipeUsers + users.filter { user in !bipeUsers.contains { $0.id == user.id } })
            case .failure:
                if !bipeUsers.isEmpty {
                    state.usersSection = .init(type: .searchResult, users: bipeUsers)
                }
            }
        }
    }
    
    /// Bipe ADR 0111: empty search results offer the chat with the inviter until the user messages them.
    private func loadBipeInviter() {
        guard let greeting = userSession.clientProxy.bipeInviterGreeting else { return }
        state.bipeInviter = (greeting.userID, greeting.handle ?? String(greeting.userID.trimmingPrefix("@")))
        Task {
            guard let handle = await greeting.displayHandle(resolver: userSession.bipeHandleResolver) else { return }
            state.bipeInviter = (greeting.userID, handle)
        }
    }
    
    /// Bipe: exact handle lookup (no directory). `nil` when the query is not a handle,
    /// is the user's own handle, or the lookup failed.
    private func bipeLookUp(query: String) async -> (handle: String, profile: UserProfile?)? {
        guard let resolver = userSession.bipeHandleResolver else { return nil }
        let handle = BipeHandle.sanitize(query).lowercased()
        guard BipeHandle.localProblem(for: handle) == nil else { return nil }
        
        let userID: String?
        do {
            userID = try await resolver.userID(forHandle: handle)
        } catch {
            MXLog.error("Bipe handle lookup failed: \(error)")
            return nil
        }
        guard let userID else { return (handle, nil) }
        guard userID != userSession.clientProxy.userID else { return nil }
        
        let profile = (try? await userSession.clientProxy.profile(for: userID).get()) ?? UserProfile(userID: userID)
        return (handle, profile)
    }
    
    private func createDirectRoom(user: UserProfile) async {
        defer {
            hideLoadingIndicator()
        }
        showLoadingIndicator()
        switch await userSession.clientProxy.createDirectRoom(with: user.id, expectedRoomName: user.displayName) {
        case .success(let roomId):
            analytics.trackCreatedRoom(isDM: true)
            actionsSubject.send(.showRoom(roomID: roomId))
        case .failure:
            displayError()
        }
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .failedCreatingRoom,
                                             title: L10n.commonError,
                                             message: L10n.screenStartChatErrorStartingChat)
    }
    
    private func joinRoomByAddress() {
        if case let .addressFound(lastTestedAddress, roomID) = internalRoomAddressState,
           lastTestedAddress == state.bindings.roomAddress {
            actionsSubject.send(.showRoom(roomID: roomID))
        } else if let resolveAliasTask {
            // If the task is still running we wait for it to complete and we check the state again
            showLoadingIndicator(delay: .milliseconds(250))
            Task {
                await resolveAliasTask.value
                hideLoadingIndicator()
                joinRoomByAddress()
            }
        } else if internalRoomAddressState == .example {
            // If we are in the example state internally, this means that the task has not started yet so we start it, and the check the state again
            resolveRoomAddress(state.bindings.roomAddress)
            joinRoomByAddress()
        } else {
            // In any other case we just use the internal state
            state.joinByAddressState = internalRoomAddressState
        }
    }
    
    // MARK: Loading indicator
    
    private static let loadingIndicatorIdentifier = "\(StartChatScreenViewModel.self)-Loading"
    
    private func showLoadingIndicator(delay: Duration? = nil) {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.commonLoading,
                                                              persistent: true),
                                                delay: delay)
    }
    
    private func hideLoadingIndicator() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
}
