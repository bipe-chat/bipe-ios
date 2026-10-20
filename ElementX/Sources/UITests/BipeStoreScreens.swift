//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

#if DEBUG
import BipeKit
import Combine
import Compound
import MatrixRustSDKMocks
import SwiftUI

/// Store screenshot mode (bipe#454): one screen per store panel, built from the existing Bipe views on mock proxies.
/// People come from the sample cast (`BipeCast`, bipe-shared/product/cast.json). Content and text per locale come
/// from `BipeStoreFixtures` (bipe-shared/product/store-fixtures.json, bipe#462). Photos come from the folder in
/// `BIPE_CAST_PHOTOS` (bipe-web src/cast/photos), which `appstore/capture.sh` passes through the test runner.
/// No server, no phone numbers.
@MainActor
final class BipeStoreScreens {
    private let windowManager: SecureWindowManagerProtocol
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let appSettings: AppSettings
    private let analytics: AnalyticsServiceProtocol
    private var retainedState = [Any]()
    
    init(windowManager: SecureWindowManagerProtocol,
         navigationRootCoordinator: NavigationRootCoordinator,
         appSettings: AppSettings,
         analytics: AnalyticsServiceProtocol) {
        self.windowManager = windowManager
        self.navigationRootCoordinator = navigationRootCoordinator
        self.appSettings = appSettings
        self.analytics = analytics
        // A remote banner or a handle prompt from the real API must not reach a capture.
        appSettings.bipeDisableAPIForScreenshots()
    }
    
    func coordinator(for id: UITestsScreenIdentifier) -> CoordinatorProtocol? {
        switch id {
        case .bipeStoreAvisoGolpe:
            return chat(Self.screen("aviso-golpe"))
        case .bipeStorePedidos:
            startSession(rooms: (Self.screen("pedidos").requests ?? []).map(Self.request))
            return nil
        case .bipeStoreSeuArroba:
            let me = BipeCast.entry(Self.me)
            let profile = UserProfile(userID: Self.userID(me.id), displayName: me.name, avatarURL: Self.photoURL(me))
            return BipeStoreViewCoordinator(BipeStoreProfileScreen(profile: profile, handle: me.handle ?? "", mediaProvider: Self.mediaProvider))
        case .bipeStoreConferirPix:
            return pixCheck(Self.screen("conferir-pix"))
        case .bipeStoreConferirPixAlterado:
            return pixCheck(Self.screen("conferir-pix-alterado"))
        case .bipeStoreGrupos:
            startSession(rooms: (Self.screen("grupos").groups ?? []).map(Self.group))
            return nil
        case .bipeStoreSeloCnpj:
            let screen = Self.screen("selo-cnpj")
            if let id = screen.chat {
                companySeals.storeFixture(Self.badge(for: BipeCast.entry(id)))
            }
            return chat(screen)
        case .bipeStoreStickers:
            return chat(Self.screen("stickers"))
        default:
            fatalError("Not a store screen: \(id)")
        }
    }
    
    /// The screen's sample content (bipe-shared/product/store-fixtures.json).
    private static func screen(_ slug: String) -> BipeStoreScreen {
        guard let screen = BipeStoreFixtures.screens[slug] else { fatalError("No store fixture for \(slug)") }
        return screen
    }
    
    /// `capture.sh --locale` passes it; the app language comes from `-AppleLanguages`.
    private static let locale = ProcessInfo.processInfo.environment["BIPE_STORE_LOCALE"] ?? "pt-BR"
    
    private static func text(_ text: BipeStoreText) -> String {
        text[locale] ?? text["pt-BR"] ?? ""
    }
    
    // MARK: - Screens
    
    private func pixCheck(_ screen: BipeStoreScreen) -> CoordinatorProtocol {
        BipeStoreViewCoordinator(BipePixCheckView(check: .check(screen.code ?? ""), close: { }, sendToChat: { }))
    }
    
    /// A room screen with the screen's `chat` cast entry (a person or a company: a DM; a group: a group chat).
    private func chat(_ screen: BipeStoreScreen) -> CoordinatorProtocol {
        guard let id = screen.chat else { fatalError("Store chat without a chat id") }
        let lines = (screen.lines ?? []).map(Line.init)
        let other = BipeCast.entry(id)
        let isDirect = other.kind != .group
        let speakers = Set(lines.map(\.speaker)).subtracting([Self.me]).sorted()
        let members = ([Self.me] + speakers).map(Self.member)
        let roomProxy = JoinedRoomProxyMock(.init(id: "!\(id):bipe.net.br",
                                                  name: other.name,
                                                  avatarURL: isDirect ? nil : Self.photoURL(other),
                                                  isDirect: isDirect,
                                                  hasOngoingCall: false,
                                                  historyVisibility: .joined,
                                                  members: isDirect ? [Self.member(Self.me), Self.member(id)] : members,
                                                  heroes: isDirect ? [Self.member(id)] : [],
                                                  ownUserID: Self.userID(Self.me)))
        let items = lines.enumerated().map { index, line in line.timelineItem(index: index) }
        let timelineController = TimelineControllerMock(.init(roomProxy: roomProxy, timelineItems: items))
        let parameters = RoomScreenCoordinatorParameters(userSession: userSession(rooms: []),
                                                         roomProxy: roomProxy,
                                                         timelineController: timelineController,
                                                         mediaPlayerProvider: MediaPlayerProviderMock(),
                                                         emojiProvider: EmojiProvider(userSettings: .mock()),
                                                         linkMetadataProvider: LinkMetadataProvider(),
                                                         completionSuggestionService: CompletionSuggestionServiceMock(configuration: .init()),
                                                         ongoingCallRoomIDPublisher: .init(.init(nil)),
                                                         appMediator: AppMediatorMock(.init()),
                                                         appHooks: AppHooks(),
                                                         analytics: analytics,
                                                         composerDraftService: ComposerDraftServiceMock(.init()),
                                                         timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                         userIndicatorController: UserIndicatorControllerMock())
        let navigationStackCoordinator = NavigationStackCoordinator()
        navigationStackCoordinator.setRootCoordinator(RoomScreenCoordinator(parameters: parameters))
        return BipeEnvironmentCoordinator(wrapping: navigationStackCoordinator, handleResolver: handleResolver, companySeals: companySeals)
    }
    
    /// The signed-in tabs (Conversas, Grupos, Você), like `.userSessionScreen`. The test taps the tab or row to show.
    private func startSession(rooms: [RoomSummary]) {
        let userSession = userSession(rooms: rooms)
        let userSettings = userSession.userSettings
        userSettings.account.hasRunIdentityConfirmationOnboarding = true
        userSettings.app.hasRunNotificationPermissionsOnboarding = true
        userSettings.app.analyticsConsentState = .optedOut
        
        let appMediator = AppMediatorMock(.init())
        appMediator.windowManager = windowManager
        
        let flowCoordinator = UserSessionFlowCoordinator(isNewLogin: false,
                                                         navigationRootCoordinator: navigationRootCoordinator,
                                                         appLockService: AppLockService(keychainController: KeychainControllerMock(), appSettings: appSettings),
                                                         flowParameters: CommonFlowParameters(userSession: userSession,
                                                                                              availableSessionsPublisher: .init([.init(userSession: userSession)]),
                                                                                              bugReportService: BugReportServiceMock(.init()),
                                                                                              elementCallService: ElementCallServiceMock(.init()),
                                                                                              timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                                                              emojiProvider: EmojiProvider(userSettings: userSettings),
                                                                                              linkMetadataProvider: LinkMetadataProvider(),
                                                                                              appMediator: appMediator,
                                                                                              appHooks: AppHooks(),
                                                                                              analytics: analytics,
                                                                                              userIndicatorController: UserIndicatorControllerMock(),
                                                                                              notificationManager: NotificationManagerMock(),
                                                                                              stateMachineFactory: StateMachineFactory()))
        flowCoordinator.start()
        retainedState.append(flowCoordinator)
    }
    
    // MARK: - Session
    
    private lazy var handleResolver: BipeHandleResolver = {
        let resolver = BipeHandleResolver(apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL), serverName: Self.serverName) { nil }
        for entry in BipeCast.entries {
            resolver.store(handle: entry.handle, for: Self.userID(entry.id))
        }
        return resolver
    }()
    
    private lazy var companySeals = BipeCompanySeals(apiClient: BipeAPIClient(baseURL: appSettings.bipeAPIBaseURL),
                                                     serverName: Self.serverName,
                                                     sessionUserID: Self.userID(Self.me),
                                                     defaults: UserDefaults(suiteName: "bipe.store.screenshots") ?? .standard) { _ in nil }
    
    private func userSession(rooms: [RoomSummary]) -> UserSessionMock {
        let gabi = BipeCast.entry(Self.me)
        let clientProxy = ClientProxyMock(.init(userIDServerName: Self.serverName,
                                                userID: Self.userID(gabi.id),
                                                deviceID: "STORE",
                                                displayName: gabi.name,
                                                roomSummaryProvider: roomSummaryProvider(rooms)))
        clientProxy.userProfilePublisher = .init(UserProfile(userID: Self.userID(gabi.id), displayName: gabi.name, avatarURL: Self.photoURL(gabi)))
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy, userSettings: appSettings.userSettings(for: Self.userID(gabi.id))))
        userSession.mediaProvider = Self.mediaProvider
        userSession.bipeHandleResolver = handleResolver
        userSession.bipeCompanySeals = companySeals
        return userSession
    }
    
    /// The upstream mock reads every one-filter list as people or rooms. Pedidos (the invites filter) lists DM invites.
    private func roomSummaryProvider(_ rooms: [RoomSummary]) -> RoomSummaryProviderMock {
        let provider = RoomSummaryProviderMock(.init(state: .loaded(rooms)))
        let subject = CurrentValueSubject<[RoomSummary], Never>(rooms)
        provider.roomListPublisher = subject.asCurrentValuePublisher()
        provider.setFilterClosure = { filter in
            switch filter {
            case .all(let filters) where filters.contains(.invites), .rooms(_, let filters) where filters.contains(.invites):
                subject.send(rooms.filter { $0.joinRequestType?.isInvite == true })
            default:
                subject.send(rooms)
            }
        }
        return provider
    }
    
    // MARK: - Cast
    
    private static let me = BipeStoreFixtures.me
    private static let serverName = "bipe.net.br"
    
    private static func userID(_ id: String) -> String {
        "@cast.\(id):\(serverName)"
    }
    
    private static func photoURL(_ entry: BipeCastEntry) -> URL? {
        entry.photo.flatMap { URL(string: "mxc://\(BipeStoreCastPhotos.host)/\($0)") }
    }
    
    private static func member(_ id: String) -> RoomMemberProxyMock {
        let entry = BipeCast.entry(id)
        return RoomMemberProxyMock(with: .init(userID: userID(id), displayName: entry.short ?? entry.name, avatarURL: photoURL(entry), membership: .join))
    }
    
    private static let mediaProvider: MediaProviderMock = {
        let provider = MediaProviderMock(.init())
        provider.imageFromSourceSizeClosure = { source, _ in BipeStoreCastPhotos.image(for: source?.url) }
        provider.loadImageRetryingOnReconnectionSizeClosure = { source, _ in
            Task {
                guard let image = BipeStoreCastPhotos.image(for: source.url) else { throw MediaProviderError.failedRetrievingImage }
                return image
            }
        }
        return provider
    }()
    
    /// Today at 10:mm, so the lists show a time and two runs on the same day match.
    private static func time(minute: Int) -> Date {
        Calendar.current.date(bySettingHour: 10, minute: minute, second: 0, of: .now) ?? .now
    }
    
    /// A first message from someone you do not know: a DM invite, listed under Pedidos.
    private static func request(_ request: BipeStoreRequest) -> RoomSummary {
        let entry = BipeCast.entry(request.from)
        return summary(id: entry.id, name: entry.name ?? entry.id, isDirect: true, avatarURL: nil,
                       heroes: [UserProfile(userID: userID(entry.id), displayName: entry.name, avatarURL: photoURL(entry))],
                       preview: nil, minute: request.minute, unread: 0, mentions: 0, mode: nil, inviter: member(entry.id))
    }
    
    /// Groups are quiet by default (bipe/docs/groups.md): mentions and keywords only.
    private static func group(_ group: BipeStoreGroup) -> RoomSummary {
        let entry = BipeCast.entry(group.id)
        let preview = group.poll.map { L10n.commonPollSummary(text($0)) } ?? group.preview.map(text)
        return summary(id: entry.id, name: entry.name ?? entry.id, isDirect: false, avatarURL: photoURL(entry), heroes: [],
                       preview: preview, minute: group.minute, unread: UInt(group.unread ?? 0), mentions: UInt(group.mentions ?? 0),
                       mode: .mentionsAndKeywordsOnly, inviter: nil)
    }
    
    // swiftlint:disable:next function_parameter_count
    private static func summary(id: String, name: String, isDirect: Bool, avatarURL: URL?, heroes: [UserProfile],
                                preview: String?, minute: Int, unread: UInt, mentions: UInt,
                                mode: RoomNotificationModeProxy?, inviter: RoomMemberProxyMock?) -> RoomSummary {
        RoomSummary(room: RoomSDKMock(),
                    id: "!\(id):\(serverName)",
                    joinRequestType: inviter.map { .invite(inviter: $0) },
                    isJoined: inviter == nil,
                    name: name,
                    isDirect: isDirect,
                    isSpace: false,
                    avatarURL: avatarURL,
                    heroes: heroes,
                    activeMembersCount: isDirect ? 2 : UInt(BipeCast.entry(id).members ?? 3),
                    lastMessage: preview.map { AttributedString($0) },
                    lastMessageDate: time(minute: minute),
                    lastMessageState: nil,
                    unreadMessagesCount: unread,
                    unreadMentionsCount: mentions,
                    unreadNotificationsCount: mode == .mentionsAndKeywordsOnly ? mentions : unread,
                    notificationMode: mode,
                    canonicalAlias: nil,
                    alternativeAliases: [],
                    hasOngoingCall: false,
                    activeCallIntent: nil,
                    isMarkedUnread: false,
                    isFavourite: false,
                    isTombstoned: false)
    }
    
    /// A verified company seal without a signature: `storeFixture` skips the verifier.
    private static func badge(for entry: BipeCastEntry) -> BadgePayload {
        let cnpj = (entry.cnpj ?? "").filter(\.isNumber)
        let json: [String: Any] = ["sub": userID(entry.id), "lvl": "cnpj", "name": entry.name ?? "", "cnpj": cnpj,
                                   "msk": "store-screenshots", "legal_name": entry.name ?? "", "method": "staff",
                                   "checked_month": "2026-09", "iat": 1_790_000_000, "exp": 4_102_444_800]
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let payload = try? JSONDecoder().decode(BadgePayload.self, from: data) else {
            fatalError("Invalid store badge for \(entry.id)")
        }
        return payload
    }
    
    // MARK: - Lines
    
    private enum Line {
        case text(from: String, BipeStoreText)
        case sticker(from: String, photo: String)
        
        init(_ line: BipeStoreLine) {
            let from = line.from == "me" ? BipeStoreScreens.me : line.from
            if let sticker = line.sticker {
                self = .sticker(from: from, photo: sticker)
            } else {
                self = .text(from: from, line.text ?? [:])
            }
        }
        
        var speaker: String {
            switch self {
            case .text(let from, _), .sticker(let from, _): from
            }
        }
        
        func timelineItem(index: Int) -> RoomTimelineItemProtocol {
            let entry = BipeCast.entry(speaker)
            let isOutgoing = speaker == BipeStoreScreens.me
            let id = TimelineItemIdentifier.event(uniqueID: .init("store.\(index)"), eventOrTransactionID: .eventID("$store.\(index)"))
            let sender = TimelineItemSender(id: BipeStoreScreens.userID(speaker),
                                            displayName: entry.short ?? entry.name,
                                            avatarURL: BipeStoreScreens.photoURL(entry))
            let timestamp = BipeStoreScreens.time(minute: 20 + index)
            switch self {
            case .text(_, let text):
                var content = TextRoomTimelineItemContent(body: BipeStoreScreens.text(text))
                // The scam registry is pt-BR, so the warning comes from the pt-BR line in every locale.
                if !isOutgoing {
                    content.bipeScamWarning = ScamDetector.warningKind(for: text["pt-BR"] ?? "", eventID: "$store.\(index)")
                }
                return TextRoomTimelineItem(id: id, timestamp: timestamp, isOutgoing: isOutgoing, isEditable: false,
                                            canBeRepliedTo: true, sender: sender, content: content)
            case .sticker(_, let photo):
                guard let url = URL(string: "mxc://\(BipeStoreCastPhotos.host)/\(BipeStoreCastPhotos.stickerPrefix)\(photo)"),
                      let source = try? MediaSourceProxy(url: url, mimeType: "image/png") else {
                    fatalError("Invalid sticker source \(photo)")
                }
                return StickerRoomTimelineItem(id: id, body: "Sticker", timestamp: timestamp, isOutgoing: isOutgoing,
                                               isEditable: false, canBeRepliedTo: true, sender: sender,
                                               imageInfo: .init(source: source, width: 512, height: 512, mimeType: "image/png", fileSize: nil))
            }
        }
    }
}

/// Cast photos for the store screenshots, read from the folder in `BIPE_CAST_PHOTOS`.
/// A sticker URL gets the photo cut out with `StickerMaker`, as "Criar de uma foto" does.
nonisolated enum BipeStoreCastPhotos {
    static let host = "cast.bipe.chat"
    static let stickerPrefix = "sticker-"
    
    static func image(for url: URL?) -> UIImage? {
        guard let url, url.host() == host,
              let folder = ProcessInfo.processInfo.environment["BIPE_CAST_PHOTOS"] else { return nil }
        var stem = url.lastPathComponent
        let isSticker = stem.hasPrefix(stickerPrefix)
        if isSticker {
            stem.removeFirst(stickerPrefix.count)
        }
        guard let data = FileManager.default.contents(atPath: "\(folder)/\(stem).jpg") else { return nil }
        if isSticker, let sticker = StickerMaker.sticker(fromImageData: data) {
            return UIImage(data: sticker.data)
        }
        return UIImage(data: data)
    }
}

/// Shows one view as the root screen.
private final class BipeStoreViewCoordinator: CoordinatorProtocol {
    private let view: AnyView
    
    init(_ view: some View) {
        self.view = AnyView(view)
    }
    
    func toPresentable() -> AnyView {
        view
    }
}

/// The top of the Você tab with the profile QR code sheet open: the same views as `SettingsScreen` and its sheet.
private struct BipeStoreProfileScreen: View {
    let profile: UserProfile
    let handle: String
    let mediaProvider: MediaProviderProtocol
    
    var body: some View {
        ElementNavigationStack {
            Form {
                BipeProfileHeaderSection(userProfile: profile, handle: handle, mediaProvider: mediaProvider) { }
            }
            .compoundList()
            .navigationTitle(BipeStrings.tabYou)
        }
        .sheet(isPresented: .constant(true)) {
            BipeProfileQRCodeSheet(handle: handle)
                .presentationDetents([.medium, .large])
                // No grey dim over the profile behind the sheet (bipe#462).
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
}
#endif
