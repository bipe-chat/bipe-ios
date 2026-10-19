//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents
import BipeKit
import Combine
import MatrixRustSDK
import SwiftUI

typealias HomeScreenViewModelType = StateStoreViewModel<HomeScreenViewState, HomeScreenViewAction>

class HomeScreenViewModel: HomeScreenViewModelType, HomeScreenViewModelProtocol {
    private let userSession: UserSessionProtocol
    private let availableSessionsPublisher: CurrentValuePublisher<[UserSessionDetails], Never>
    private let spaceFilterSubject: CurrentValueSubject<SpaceServiceFilter?, Never>
    private let analyticsService: AnalyticsServiceProtocol
    private let bugReportService: BugReportServiceProtocol
    private let userSettings: UserSettings
    private let bipeInvitePairs: BipeInvitePairs
    private let bipeSelfChat: BipeSelfChat
    private let notificationManager: NotificationManagerProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let roomSummaryProvider: RoomSummaryProviderProtocol?
    private var bipeEmptyTabFallbackTask: Task<Void, Never>?
    
    private var actionsSubject: PassthroughSubject<HomeScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<HomeScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    // swiftlint:disable:next function_body_length
    init(userSession: UserSessionProtocol,
         availableSessionsPublisher: CurrentValuePublisher<[UserSessionDetails], Never>,
         selectedRoomPublisher: CurrentValuePublisher<String?, Never>,
         analyticsService: AnalyticsServiceProtocol,
         bugReportService: BugReportServiceProtocol,
         notificationManager: NotificationManagerProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         bipeScope: BipeRoomListScope = .chats) {
        self.userSession = userSession
        self.availableSessionsPublisher = availableSessionsPublisher
        self.analyticsService = analyticsService
        self.bugReportService = bugReportService
        userSettings = userSession.userSettings
        self.notificationManager = notificationManager
        self.userIndicatorController = userIndicatorController
        
        spaceFilterSubject = CurrentValueSubject<SpaceServiceFilter?, Never>(nil)
        
        roomSummaryProvider = switch bipeScope {
        case .chats: userSession.clientProxy.roomSummaryProvider
        case .groups: userSession.clientProxy.bipeGroupsRoomSummaryProvider
        }
        
        bipeInvitePairs = BipeInvitePairs(clientProxy: userSession.clientProxy, apiBaseURL: userSettings.app.bipeAPIBaseURL)
        bipeSelfChat = BipeSelfChat(clientProxy: userSession.clientProxy)
        
        super.init(initialViewState: .init(userProfile: userSession.clientProxy.userProfilePublisher.value,
                                           bipeScope: bipeScope,
                                           bindings: .init(filtersState: .init(userSettings: userSession.userSettings,
                                                                               bipeHiddenFilters: bipeScope.hiddenFilters))),
                   mediaProvider: userSession.mediaProvider)
        
        Task { [weak self] in
            await self?.bipeSelfChat.refresh()
        }
        NotificationCenter.default.publisher(for: BipeSelfChat.cachedRoomIDDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateRooms() }
            .store(in: &cancellables)
        
        if userSettings.app.globalSearchEnabled, #available(iOS 26.0, *) {
            state.isRoomListSearchEnabled = false
        }
        
        Task { [weak self] in
            guard let self, await bipeInvitePairs.refresh() else { return }
            updateRooms()
        }
        
        observeBipeArchivedCount()
        updateBipeInviterGreeting()
        if bipeScope == .chats {
            Task { await loadBipeHandlePrompt() }
            Task { await loadBipeRemoteBanner() }
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in Task { await self?.loadBipeRemoteBanner() } }
                .store(in: &cancellables)
        }
        NotificationCenter.default.publisher(for: .bipeInviterGreetingDidChange)
            .filter { [userID = userSession.clientProxy.userID] in $0.object as? String == userID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateBipeInviterGreeting() }
            .store(in: &cancellables)
        
        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userProfile, on: self)
            .store(in: &cancellables)
        
        // Bipe: the account menu on the avatar (ADR 0086, bipe#267). The session UI is rebuilt when accounts change.
        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.updateBipeAccounts(profile: profile)
            }
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] securityState in
                guard let self else { return }
                
                switch securityState.recoveryState {
                case .disabled:
                    // Bipe: no "set up recovery" banner for Bipe accounts. They recover with the PIN and the
                    // recovery token (ADR 0057, ADR 0073); the Bipe fallback prompt is bipe#202.
                    if userSession.bipeHandleResolver != nil {
                        state.securityBannerMode = .none
                    } else if !state.securityBannerMode.isDismissed {
                        state.securityBannerMode = .show(.setUpRecovery)
                    }
                case .incomplete:
                    state.securityBannerMode = .show(.recoveryOutOfSync)
                default:
                    state.securityBannerMode = .none
                }
            }
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { state in
                state.verificationState != .unknown
                    && state.recoveryState != .settingUp
                    && state.recoveryState != .unknown
            }
            .sink { [weak self] state in
                guard let self else { return }
                
                self.analyticsService.updateUserProperties(AnalyticsEvent.newVerificationStateUserProperty(verificationState: state.verificationState, recoveryState: state.recoveryState))
                self.analyticsService.trackSessionSecurityState(state)
            }
            .store(in: &cancellables)
        
        userSession.clientProxy.spaceService.spaceFilterPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filters in
                guard let self else { return }
                
                state.shouldShowSpaceFilters = !filters.isEmpty
                
                if let selectedSpaceFilter = spaceFilterSubject.value,
                   !filters.contains(selectedSpaceFilter) {
                    // Clear the spaces filter if the space has been left.
                    spaceFilterSubject.send(nil)
                }
            }
            .store(in: &cancellables)
        
        selectedRoomPublisher
            .weakAssign(to: \.state.selectedRoomID, on: self)
            .store(in: &cancellables)
        
        userSettings.app.showAllRoomListActivityPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateRooms()
            }
            .store(in: &cancellables)
        
        userSettings.app.seenInvitesPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateRooms()
            }
            .store(in: &cancellables)
        
        // Bipe (ADR 0117, bipe#385): upstream's new sound banner never shows; news goes to the Novidades room.
        
        userSession.clientProxy.hideInviteAvatarsPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.hideInviteAvatars, on: self)
            .store(in: &cancellables)
        
        spaceFilterSubject
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.selectedSpaceFilter, on: self)
            .store(in: &cancellables)
        
        bugReportService.lastCrashEventIDSubject
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.presentCrashedLastRunAlert()
            }
            .store(in: &cancellables)
        
        Task {
            state.reportRoomEnabled = await userSession.clientProxy.isReportRoomSupported
        }
        
        let isSearchFieldFocused = context.$viewState.map(\.bindings.isSearchFieldFocused)
        let searchQuery = context.$viewState.map(\.bindings.searchQuery)
        let activeFilters = context.$viewState.map(\.bindings.filtersState.activeFilters)
        isSearchFieldFocused
            .combineLatest(searchQuery, activeFilters, spaceFilterSubject)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] isSearchFieldFocused, _, _, _ in
                guard let self else { return }
                // isSearchFieldFocused` is sometimes turning to true after cancelling the search. So to be extra sure we are updating the values correctly we read them directly in the next run loop, and we add a small delay if the value has changed
                let delay = isSearchFieldFocused == self.context.viewState.bindings.isSearchFieldFocused ? 0.0 : 0.05
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.updateFilter()
                }
            }
            .store(in: &cancellables)
        
        setupRoomListSubscriptions()
        
        updateRooms()
        
        if let roomSummaryProvider {
            updateRoomListMode(with: roomSummaryProvider.statePublisher.value,
                               hasRooms: !roomSummaryProvider.roomListPublisher.value.isEmpty)
        }
        
        // Fall back to the skeletons if the cached rooms take too long to publish.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, state.roomListMode == .awaitingCachedRooms else { return }
            state.roomListMode = .skeletons
        }
    }
    
    // MARK: - Public
    
    // swiftlint:disable:next function_body_length
    override func process(viewAction: HomeScreenViewAction) {
        switch viewAction {
        case .selectRoom(let roomIdentifier):
            actionsSubject.send(.presentRoom(roomIdentifier: roomIdentifier))
        case .detachRoom(let roomIdentifier):
            actionsSubject.send(.detachRoom(roomIdentifier: roomIdentifier))
        case .showRoomDetails(let roomIdentifier):
            actionsSubject.send(.presentRoomDetails(roomIdentifier: roomIdentifier))
        case .leaveRoom(let roomIdentifier):
            startLeaveRoomProcess(roomID: roomIdentifier)
        case .confirmLeaveRoom(let roomIdentifier):
            Task { await leaveRoom(roomID: roomIdentifier) }
        case .reportRoom(let roomIdentifier):
            actionsSubject.send(.presentReportRoom(roomIdentifier: roomIdentifier))
        case .showSettings:
            actionsSubject.send(.presentSettingsScreen)
        case .setupRecovery:
            actionsSubject.send(.presentSecureBackupSettings)
        case .confirmRecoveryKey:
            actionsSubject.send(.presentRecoveryKeyScreen)
        case .resetEncryption:
            actionsSubject.send(.presentEncryptionResetScreen)
        case .skipRecoveryKeyConfirmation:
            state.securityBannerMode = .dismissed
        case .dismissNewSoundBanner:
            userSettings.app.hasSeenNewSoundBanner = true
        case .bipeAddAccount:
            actionsSubject.send(.bipeAddAccount)
        case .bipeSwitchToNextAccount:
            guard let next = state.bipeAccounts.first(where: { !$0.isCurrent }) else {
                actionsSubject.send(.presentSettingsScreen)
                return
            }
            actionsSubject.send(.bipeSwitchAccount(userID: next.userID))
        case .bipeSwitchAccount(let userID):
            guard userID != userSession.clientProxy.userID else { return }
            actionsSubject.send(.bipeSwitchAccount(userID: userID))
        case .updateVisibleItemRange(let range):
            roomSummaryProvider?.updateVisibleRange(range)
        case .startChat:
            actionsSubject.send(.presentStartChatScreen)
        case .createGroup:
            actionsSubject.send(.presentCreateGroupScreen)
        case .openBipeInviterChat:
            Task { await openBipeInviterChat() }
        case .openBipeHandlePrompt:
            dismissBipeHandlePrompt()
            actionsSubject.send(.presentBipeHandleScreen)
        case .dismissBipeHandlePrompt:
            dismissBipeHandlePrompt()
        case .openBipeRemoteBanner:
            openBipeRemoteBanner()
        case .dismissBipeRemoteBanner:
            dismissBipeRemoteBanner()
        case .spaceFilters:
            if spaceFilterSubject.value != nil {
                spaceFilterSubject.send(nil)
            } else {
                state.bindings.spaceFiltersViewModel = ChatsSpaceFiltersScreenViewModel(spaceService: userSession.clientProxy.spaceService,
                                                                                        mediaProvider: userSession.mediaProvider)
                
                state.bindings.spaceFiltersViewModel?.actionsPublisher.sink { [weak self] action in
                    guard let self else { return }
                    
                    switch action {
                    case .confirm(let spaceServiceFilter):
                        spaceFilterSubject.send(spaceServiceFilter)
                        state.bindings.spaceFiltersViewModel = nil
                    case .cancel:
                        state.bindings.spaceFiltersViewModel = nil
                    }
                }
                .store(in: &cancellables)
            }
        case .markRoomAsUnread(let roomIdentifier):
            Task {
                guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomIdentifier) else {
                    MXLog.error("Failed retrieving room for identifier: \(roomIdentifier)")
                    return
                }
                
                switch await roomProxy.flagAsUnread(true) {
                case .success:
                    analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuUnreadToggle)
                case .failure(let error):
                    MXLog.error("Failed marking room \(roomIdentifier) as unread with error: \(error)")
                }
            }
        case .markRoomAsRead(let roomIdentifier):
            Task {
                guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomIdentifier) else {
                    MXLog.error("Failed retrieving room for identifier: \(roomIdentifier)")
                    return
                }
                
                switch await roomProxy.flagAsUnread(false) {
                case .success:
                    analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuUnreadToggle)
                    
                    // Bipe: receipts are always public (ADR 0050)
                    if case .failure(let error) = await roomProxy.markAsRead(receiptType: .read) {
                        MXLog.error("Failed marking room \(roomIdentifier) as read with error: \(error)")
                    }
                case .failure(let error):
                    MXLog.error("Failed flagging room \(roomIdentifier) as read with error: \(error)")
                }
            }
        case .markRoomAsFavourite(let roomIdentifier, let isFavourite):
            Task {
                await markRoomAsFavourite(roomIdentifier, isFavourite: isFavourite)
            }
        case .setRoomArchived(let roomIdentifier, let isArchived):
            Task {
                await setRoomArchived(roomIdentifier, isArchived: isArchived)
            }
        case .setRoomMuted(let roomIdentifier, let isMuted):
            Task {
                await setRoomMuted(roomIdentifier, isMuted: isMuted)
            }
        case .acceptInvite(let roomIdentifier):
            Task {
                await acceptInvite(roomID: roomIdentifier)
            }
        case .declineInvite(let roomIdentifier):
            Task { await showDeclineInviteConfirmationAlert(roomID: roomIdentifier) }
        }
    }
    
    // perphery: ignore - used in release mode
    func presentCrashedLastRunAlert() {
        // Delay setting the alert otherwise it automatically gets dismissed. Same as the force logout one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            state.bindings.alertInfo = AlertInfo(id: UUID(),
                                                 title: L10n.crashDetectionDialogContent(InfoPlistReader.main.bundleDisplayName),
                                                 primaryButton: .init(title: L10n.actionNo, action: nil),
                                                 secondaryButton: .init(title: L10n.actionYes) { [weak self] in
                                                     self?.actionsSubject.send(.presentFeedbackScreen)
                                                 })
        }
    }
    
    // MARK: - Private
    
    private func updateFilter() {
        if state.shouldHideRoomList {
            roomSummaryProvider?.setFilter(.excludeAll)
        } else {
            if state.bindings.isSearchFieldFocused {
                roomSummaryProvider?.setFilter(.search(query: state.bindings.searchQuery))
            } else {
                if let spaceFilter = spaceFilterSubject.value {
                    roomSummaryProvider?.setFilter(.rooms(roomsIDs: spaceFilter.descendants,
                                                          filters: state.bindings.filtersState.activeFilters.set))
                } else {
                    roomSummaryProvider?.setFilter(.all(filters: state.bindings.filtersState.activeFilters.set))
                }
            }
        }
    }
    
    private func setupRoomListSubscriptions() {
        guard let roomSummaryProvider else {
            MXLog.error("Room summary provider unavailable")
            return
        }
        
        // Combined so that the mode and the rooms are always updated from the same pair of
        // values: the state can report loaded before the first summaries have published and
        // flipping to .rooms then would flash an empty list.
        roomSummaryProvider.statePublisher
            .combineLatest(roomSummaryProvider.roomListPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, rooms in
                guard let self else { return }
                
                updateRooms()
                updateRoomListMode(with: state, hasRooms: !rooms.isEmpty)
            }
            .store(in: &cancellables)
    }
    
    private func updateRoomListMode(with roomSummaryProviderState: RoomSummaryProviderState, hasRooms: Bool) {
        let isFiltering = state.bindings.filtersState.isFiltering || state.selectedSpaceFilter != nil || state.bindings.isSearchFieldFocused
        
        let roomListMode: HomeScreenRoomListMode = if !roomSummaryProviderState.isLoaded {
            .skeletons // Still loading.
        } else if roomSummaryProviderState.totalNumberOfRooms == 0 {
            .empty // Loaded, there are no rooms at all.
        } else if hasRooms || isFiltering {
            .rooms // Loaded and the summaries have published (or filtered down to nothing).
        } else if state.roomListMode == .skeletons || state.roomListMode == .awaitingCachedRooms {
            state.roomListMode // Loaded but nothing published yet, flipping to .rooms would flash an empty list.
        } else {
            .empty // Bipe ADR 0053: the total counts every room, the tab's filter can leave none.
        }
        
        if roomListMode == .skeletons || roomListMode == .awaitingCachedRooms, roomSummaryProviderState.isLoaded, !hasRooms {
            scheduleBipeEmptyTabFallback()
        }
        
        guard roomListMode != state.roomListMode else {
            return
        }
        
        if roomListMode == .rooms, state.roomListMode == .skeletons || state.roomListMode == .awaitingCachedRooms {
            analyticsService.signpost.finishTransaction(.cachedRoomList)
        }
        
        state.roomListMode = roomListMode
        
        MXLog.info("Received room summary provider update, setting view room list mode to \"\(state.roomListMode)\"")
        // Delay user profile detail loading until after the initial room list loads
        if roomListMode == .rooms {
            Task {
                await self.userSession.clientProxy.loadUserProfileIfNeeded()
            }
        }
    }
    
    /// A loaded tab whose filter matches no room never publishes a room, so it would show skeletons forever.
    private func scheduleBipeEmptyTabFallback() {
        guard bipeEmptyTabFallbackTask == nil else { return }
        
        bipeEmptyTabFallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, let roomSummaryProvider else { return }
            bipeEmptyTabFallbackTask = nil
            
            guard state.roomListMode == .skeletons || state.roomListMode == .awaitingCachedRooms,
                  roomSummaryProvider.statePublisher.value.isLoaded,
                  roomSummaryProvider.roomListPublisher.value.isEmpty else { return }
            
            MXLog.info("Loaded with no rooms in this tab, setting view room list mode to \"empty\"")
            state.roomListMode = .empty
        }
    }
    
    private func updateRooms() {
        guard let roomSummaryProvider else {
            MXLog.error("Room summary provider unavailable")
            return
        }
        
        var rooms = [HomeScreenRoom]()
        let seenInvites = userSettings.app.seenInvites
        // Bipe: DM invites are requests (usernames.md "First contact"). They only show under the Pedidos filter.
        // The SDK has no cheap "shares a joined room" check, so every DM invite counts as a request.
        let showsRequests = state.bindings.filtersState.isFilterActive(.invites)
        var requestCount = 0
        // Bipe ADR 0053: the self-chat lives in the Você tab only.
        let selfChatRoomID = bipeSelfChat.cachedRoomID
        
        for summary in roomSummaryProvider.roomListPublisher.value {
            if summary.id == selfChatRoomID {
                continue
            }
            
            if summary.isDirect, case .invite(let inviter) = summary.joinRequestType {
                // Bipe ADR 0034: a chat from an invite pair skips Pedidos and is accepted without a tap.
                if bipeInvitePairs.contains(inviter?.userID) {
                    bipeInvitePairs.autoAccept(roomID: summary.id)
                } else {
                    bipeInvitePairs.recheck(roomID: summary.id) { [weak self] in self?.updateRooms() }
                    if !showsRequests {
                        requestCount += 1
                        continue
                    }
                }
            }
            
            let room = HomeScreenRoom(summary: summary,
                                      showAllActivity: userSettings.app.showAllRoomListActivity,
                                      seenInvites: seenInvites)
            rooms.append(room)
        }
        
        state.rooms = rooms
        state.bipeRequestCount = requestCount
    }
    
    // MARK: Bipe inviter greeting (ADR 0034)
    
    private func updateBipeInviterGreeting() {
        guard let greeting = userSession.clientProxy.bipeInviterGreeting else {
            state.bipeInviterHandle = nil
            return
        }
        state.bipeInviterHandle = greeting.handle ?? String(greeting.userID.trimmingPrefix("@"))
        Task { [weak self] in
            guard let self, let handle = await greeting.displayHandle(resolver: userSession.bipeHandleResolver),
                  userSession.clientProxy.bipeInviterGreeting != nil else { return }
            state.bipeInviterHandle = handle
        }
    }
    
    /// The card shows once the server says the account has no @. A failed read shows nothing.
    private func loadBipeHandlePrompt() async {
        let appSettings = userSettings.app
        guard appSettings.usesBipeSignup, !appSettings.bipeHasDismissedHandlePrompt,
              let accessToken = userSession.clientProxy.accessToken else { return }
        let apiClient = BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL)
        guard let myHandle = try? await apiClient.myHandle(accessToken: accessToken) else { return }
        state.bipeNeedsHandle = myHandle.handle == nil
    }
    
    private func dismissBipeHandlePrompt() {
        userSettings.app.bipeHasDismissedHandlePrompt = true
        state.bipeNeedsHandle = false
    }
    
    /// ADR 0117: on launch and on foreground. A failed read keeps the banner that is on screen.
    private func loadBipeRemoteBanner() async {
        guard let banner = try? await BipeAPIClient(baseURL: userSettings.app.bipeAPIBaseURL).remoteBanner() else {
            if state.bipeRemoteBanner != nil {
                updateBipeRemoteBannerState()
            }
            return
        }
        state.bipeRemoteBanner = banner
        updateBipeRemoteBannerState()
    }
    
    private func updateBipeRemoteBannerState() {
        guard let banner = state.bipeRemoteBanner else {
            state.bipeRemoteBannerState = .hidden
            return
        }
        let bannerState = banner.state(appVersion: InfoPlistReader.main.bundleShortVersionString)
        // An update banner cannot be dismissed. A notice stays closed until a banner with a new id.
        state.bipeRemoteBannerState = bannerState == .notice && userSettings.app.bipeDismissedRemoteBannerID == banner.id ? .hidden : bannerState
    }
    
    private func openBipeRemoteBanner() {
        guard let banner = state.bipeRemoteBanner else { return }
        switch state.bipeRemoteBannerState {
        case .update(let url): UIApplication.shared.open(url)
        case .notice: UIApplication.shared.open(banner.link)
        case .hidden: break
        }
    }
    
    private func dismissBipeRemoteBanner() {
        guard let banner = state.bipeRemoteBanner, state.bipeRemoteBannerState == .notice else { return }
        userSettings.app.bipeDismissedRemoteBannerID = banner.id
        state.bipeRemoteBannerState = .hidden
    }
    
    private static let bipeInviterChatLoadingID = "BipeInviterChatLoading"
    
    private func openBipeInviterChat() async {
        guard let greeting = userSession.clientProxy.bipeInviterGreeting else { return }
        userIndicatorController.submitIndicator(UserIndicator(id: Self.bipeInviterChatLoadingID, type: .modal, title: L10n.commonLoading, persistent: true))
        let roomID = await userSession.clientProxy.bipeDirectRoom(with: greeting.userID)
        userIndicatorController.retractIndicatorWithId(Self.bipeInviterChatLoadingID)
        guard let roomID else {
            state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
            return
        }
        actionsSubject.send(.presentRoom(roomIdentifier: roomID))
    }
    
    private func markRoomAsFavourite(_ roomID: String, isFavourite: Bool) async {
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            MXLog.error("Failed retrieving room for identifier: \(roomID)")
            return
        }
        
        switch await roomProxy.flagAsFavourite(isFavourite) {
        case .success:
            analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuFavouriteToggle)
        case .failure(let error):
            MXLog.error("Failed marking room \(roomID) as favourite: \(isFavourite) with error: \(error)")
        }
    }
    
    private func setRoomArchived(_ roomID: String, isArchived: Bool) async {
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            MXLog.error("Failed retrieving room for identifier: \(roomID)")
            return
        }
        
        if case .failure(let error) = await roomProxy.flagAsLowPriority(isArchived) {
            MXLog.error("Failed setting room \(roomID) archived: \(isArchived) with error: \(error)")
            userIndicatorController.submitIndicator(.init(title: L10n.errorUnknown))
        }
    }
    
    /// Bipe: the static provider lists every room, archived ones too. The tab's own provider hides them.
    private func observeBipeArchivedCount() {
        userSession.clientProxy.staticRoomSummaryProvider.roomListPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summaries in
                guard let self else { return }
                let selfChatRoomID = bipeSelfChat.cachedRoomID
                state.bipeArchivedCount = summaries.count(where: { summary in
                    summary.isJoined && summary.isLowPriority && summary.id != selfChatRoomID && BipeRoomListScope(summary: summary) == state.bipeScope
                })
            }
            .store(in: &cancellables)
    }
    
    // Bipe: one-tap mute from the room list. No duration, the room stays muted until unmuted.
    private func setRoomMuted(_ roomID: String, isMuted: Bool) async {
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            MXLog.error("Failed retrieving room for identifier: \(roomID)")
            return
        }
        
        let notificationSettings = userSession.clientProxy.notificationSettings
        do {
            if isMuted {
                try await notificationSettings.setNotificationMode(roomId: roomID, mode: .mute)
            } else {
                try await notificationSettings.unmuteRoom(roomId: roomID,
                                                          isEncrypted: roomProxy.infoPublisher.value.isEncrypted,
                                                          isOneToOne: roomProxy.infoPublisher.value.activeMembersCount == 2)
            }
        } catch {
            MXLog.error("Failed setting room \(roomID) muted: \(isMuted) with error: \(error)")
            state.bindings.alertInfo = .init(id: UUID(),
                                             title: L10n.commonError,
                                             message: roomProxy.infoPublisher.value.isDM // Bipe: a DM is a conversation
                                                 ? (isMuted ? BipeStrings.dmErrorMuting : BipeStrings.dmErrorUnmuting)
                                                 : (isMuted ? L10n.screenRoomDetailsErrorMuting : L10n.screenRoomDetailsErrorUnmuting))
        }
    }
    
    private static let leaveRoomLoadingID = "LeaveRoomLoading"
    
    private func startLeaveRoomProcess(roomID: String) {
        Task { [self] in
            defer {
                userIndicatorController.retractIndicatorWithId(Self.leaveRoomLoadingID)
            }
            userIndicatorController.submitIndicator(UserIndicator(id: Self.leaveRoomLoadingID, type: .modal, title: L10n.commonLoading, persistent: true))
            
            guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
                state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
                return
            }
            
            guard roomProxy.infoPublisher.value.joinedMembersCount > 1 else {
                state.bindings.leaveRoomAlertItem = LeaveRoomAlertItem(roomID: roomID,
                                                                       isDM: roomProxy.infoPublisher.value.isDM,
                                                                       state: roomProxy.infoPublisher.value.isPrivate ?? true ? .empty : .public)
                return
            }
            
            if !roomProxy.infoPublisher.value.isDM {
                if case let .success(ownMember) = await roomProxy.getMember(userID: roomProxy.ownUserID),
                   ownMember.role.isOwner {
                    await roomProxy.updateMembers()
                    var isLastOwner = true
                    for member in roomProxy.membersPublisher.value where member.userID != roomProxy.ownUserID && member.membership == .join {
                        if member.role.isOwner {
                            isLastOwner = false
                            break
                        }
                    }
                    
                    if isLastOwner {
                        state.bindings.alertInfo = .init(id: UUID(),
                                                         title: L10n.leaveRoomAlertSelectNewOwnerTitle,
                                                         message: L10n.leaveRoomAlertSelectNewOwnerSubtitle,
                                                         primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                                         secondaryButton: .init(title: L10n.leaveRoomAlertSelectNewOwnerAction, role: .destructive) { [weak self] in
                                                             self?.actionsSubject.send(.transferOwnership(roomIdentifier: roomID))
                                                         })
                        return
                    }
                }
            }
            
            state.bindings.leaveRoomAlertItem = LeaveRoomAlertItem(roomID: roomID, isDM: roomProxy.infoPublisher.value.isDM, state: roomProxy.infoPublisher.value.isPrivate ?? true ? .private : .public)
        }
    }
    
    private func leaveRoom(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(Self.leaveRoomLoadingID)
        }
        let isDirect = state.rooms.first { $0.roomID == roomID }?.isDirect == true // Bipe: a DM is a conversation
        userIndicatorController.submitIndicator(UserIndicator(id: Self.leaveRoomLoadingID, type: .modal, title: isDirect ? BipeStrings.dmLeaving : L10n.commonLeavingRoom, persistent: true))
        
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID),
              case .success = await roomProxy.leaveRoom() else {
            state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
            return
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: UUID().uuidString,
                                                              type: .toast,
                                                              title: isDirect ? BipeStrings.dmLeftByYou : L10n.commonCurrentUserLeftRoom,
                                                              icon: \.check))
        actionsSubject.send(.roomLeft(roomIdentifier: roomID))
    }
    
    // MARK: Bipe accounts
    
    /// Bipe: the current account first, then the other accounts signed in on the phone. The live sessions publisher lists
    /// only accounts whose session is open, so the keychain gives the list.
    private func updateBipeAccounts(profile: UserProfile) {
        let currentUserID = userSession.clientProxy.userID
        BipeAccountLabels.remember(displayName: profile.displayName, for: currentUserID)
        let current = BipeAccountMenuItem(userID: currentUserID, label: profile.displayName ?? currentUserID, isCurrent: true,
                                          isCompany: BipeAccountLabels.isCompany(currentUserID))
        let others = BipeSignedInAccounts.userIDs.filter { $0 != currentUserID }.sorted().map {
            BipeAccountMenuItem(userID: $0, label: BipeAccountLabels.label(for: $0), isCurrent: false, isCompany: BipeAccountLabels.isCompany($0))
        }
        state.bipeAccounts = [current] + others
    }
    
    // MARK: Invites
    
    private func acceptInvite(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(roomID)
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: roomID, type: .modal, title: L10n.commonLoading, persistent: true))
        
        guard case let .invited(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            displayError()
            return
        }
        
        switch await userSession.clientProxy.joinRoom(roomID, via: []) {
        case .success:
            await finishAcceptInvite(roomProxy: roomProxy)
        case .failure(let error):
            switch error {
            case .invalidInvite:
                displayError(title: L10n.dialogTitleError, message: L10n.errorInvalidInvite)
            default:
                displayError()
            }
        }
    }
    
    private func finishAcceptInvite(roomProxy: InvitedRoomProxyProtocol) async {
        if roomProxy.info.isSpace {
            let spaceService = userSession.clientProxy.spaceService
            
            switch await spaceService.spaceRoomList(spaceID: roomProxy.id) {
            case .success(let spaceRoomListProxy):
                actionsSubject.send(.presentSpace(spaceRoomListProxy))
            case .failure(let error):
                MXLog.error("Failed to get the space room list after accepting invite: \(error)")
                displayError()
                return
            }
        } else {
            actionsSubject.send(.presentRoom(roomIdentifier: roomProxy.id))
        }
        
        analyticsService.trackJoinedRoom(isDM: roomProxy.info.isDirect,
                                         isSpace: roomProxy.info.isSpace,
                                         activeMemberCount: UInt(roomProxy.info.activeMembersCount))
        userSettings.app.seenInvites.remove(roomProxy.id)
    }
    
    private func showDeclineInviteConfirmationAlert(roomID: String) async {
        guard let room = state.rooms.first(where: { $0.id == roomID }) else {
            displayError()
            return
        }
        
        let roomPlaceholder = room.isDirect ? (room.inviter?.displayName ?? room.name) : room.name
        let title = room.isDirect ? L10n.screenInvitesDeclineDirectChatTitle : L10n.screenInvitesDeclineChatTitle
        let message = room.isDirect ? L10n.screenInvitesDeclineDirectChatMessage(roomPlaceholder) : L10n.screenInvitesDeclineChatMessage(roomPlaceholder)
        
        if await userSession.clientProxy.isReportRoomSupported, let userID = room.inviter?.id {
            state.bindings.alertInfo = .init(id: UUID(),
                                             title: title,
                                             message: message,
                                             primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                             secondaryButton: .init(title: L10n.actionDeclineAndBlock, role: .destructive) { [weak self] in self?.declineAndBlockInvite(userID: userID, roomID: roomID) },
                                             verticalButtons: [.init(title: L10n.actionDecline) { [weak self] in Task { await self?.declineInvite(roomID: room.id) } }])
        } else {
            state.bindings.alertInfo = .init(id: UUID(),
                                             title: title,
                                             message: message,
                                             primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                             secondaryButton: .init(title: L10n.actionDecline, role: .destructive) { [weak self] in Task { await self?.declineInvite(roomID: room.id) } })
        }
    }
    
    private func declineAndBlockInvite(userID: String, roomID: String) {
        actionsSubject.send(.presentDeclineAndBlock(userID: userID, roomID: roomID))
    }
    
    private func declineInvite(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(roomID)
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: roomID, type: .modal, title: L10n.commonLoading, persistent: true))
        
        guard case let .invited(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            displayError()
            return
        }
        
        let result = await roomProxy.rejectInvitation()
        
        switch result {
        case .success:
            await notificationManager.removeDeliveredMessageNotifications(for: roomID) // Normally handled by the room flow, but that's never presented in this case.
            userSettings.app.seenInvites.remove(roomID)
        case .failure:
            displayError()
        }
    }
    
    private func displayError(title: String? = nil, message: String? = nil) {
        state.bindings.alertInfo = .init(id: UUID(),
                                         title: title ?? L10n.commonError,
                                         message: message ?? L10n.errorUnknown)
    }
}
