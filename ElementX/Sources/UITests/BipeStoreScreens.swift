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
/// People come from the sample cast (`BipeCast`, bipe-shared/product/cast.json). Text is pt-BR from the site scenes
/// (bipe-web src/sim/scenes.ts). Photos come from the folder in `BIPE_CAST_PHOTOS` (bipe-web src/cast/photos),
/// which `appstore/capture.sh` passes through the test runner. No server, no phone numbers.
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
    
    // swiftlint:disable:next cyclomatic_complexity
    func coordinator(for id: UITestsScreenIdentifier) -> CoordinatorProtocol? {
        switch id {
        case .bipeStoreAvisoGolpe:
            return chat(with: "golpista", lines: [
                .text(from: "golpista", "Oi filha, troquei de número. Essa é minha conta nova aqui"),
                .text(from: Self.me, "Mãe? O que houve com o outro?"),
                .text(from: "golpista", "Caiu na água. Preciso pagar um boleto hoje ainda, me faz um Pix que amanhã te devolvo")
            ])
        case .bipeStorePedidos:
            startSession(rooms: [
                Self.request(from: "golpista", minute: 12),
                Self.request(from: "camila", minute: 3),
                Self.request(from: "suporte", minute: 1),
                Self.dm(with: "joana", preview: "Chego sábado de manhã. Me busca?", minute: 24, unread: 2),
                Self.dm(with: "rafa", preview: "Pix recebido, valeu", minute: 10),
                Self.dm(with: "fernanda", preview: "Ligo sim, 2 min", minute: 5)
            ])
            return nil
        case .bipeStoreSeuArroba:
            let gabi = BipeCast.entry(Self.me)
            let profile = UserProfile(userID: Self.userID(gabi.id), displayName: gabi.name, avatarURL: Self.photoURL(gabi))
            return BipeStoreViewCoordinator(BipeStoreProfileScreen(profile: profile, handle: gabi.handle ?? "", mediaProvider: Self.mediaProvider))
        case .bipeStoreConferirPix:
            // The site scene's code is tampered (rafa.blkes, bad CRC). The store panel shows a valid one: bipe-shared buildBrCode.
            let code = "00020126440014br.gov.bcb.pix0122rafa.bikes@example.com5204000053039865406850.005802BR5915RAFAEL OLIVEIRA6014BELO HORIZONTE62070503***63047466"
            return BipeStoreViewCoordinator(BipePixCheckView(check: .check(code), close: { }, sendToChat: { }))
        case .bipeStoreGrupos:
            startSession(rooms: [
                Self.group("familia", preview: "Vô Antônio: Domingo tem almoço aqui em casa", minute: 58, unread: 5, mentions: 1),
                Self.group("avisos", preview: L10n.commonPollSummary("Cor da fachada"), minute: 41, unread: 1),
                Self.group("faculdade", preview: "Bia: Sexta tem churrasco lá em casa", minute: 30, unread: 12),
                Self.group("igreja", preview: "Pastora Débora: Irmãos, agora o grupo aceita só quem tem selo verificado", minute: 15)
            ])
            return nil
        case .bipeStoreSeloCnpj:
            let clinic = BipeCast.entry("clinica")
            companySeals.storeFixture(Self.badge(for: clinic))
            return chat(with: "clinica", lines: [
                .text(from: "clinica", "Sua consulta é amanhã, às 14h, com a Dra. Ana. Responda 1 para confirmar ou 2 para remarcar."),
                .text(from: Self.me, "1"),
                .text(from: "clinica", "Consulta confirmada. Até amanhã.")
            ])
        case .bipeStoreStickers:
            return chat(with: "faculdade", lines: [
                .text(from: "bia", "Sexta tem churrasco lá em casa"),
                .sticker(from: "leo", photo: "rafa"),
                .sticker(from: Self.me, photo: "caramelo")
            ])
        default:
            fatalError("Not a store screen: \(id)")
        }
    }
    
    // MARK: - Screens
    
    /// A room screen with the cast entry `id` (a person or a company: a DM; a group: a group chat).
    private func chat(with id: String, lines: [Line]) -> CoordinatorProtocol {
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
    
    private static let me = "gabi"
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
    
    private static func dm(with id: String, preview: String, minute: Int, unread: UInt = 0) -> RoomSummary {
        let entry = BipeCast.entry(id)
        return summary(id: id, name: entry.short ?? entry.name ?? id, isDirect: true, avatarURL: nil,
                       heroes: [UserProfile(userID: userID(id), displayName: entry.short, avatarURL: photoURL(entry))],
                       preview: preview, minute: minute, unread: unread, mentions: 0, mode: .allMessages, inviter: nil)
    }
    
    /// A first message from someone you do not know: a DM invite, listed under Pedidos.
    private static func request(from id: String, minute: Int) -> RoomSummary {
        let entry = BipeCast.entry(id)
        return summary(id: id, name: entry.name ?? id, isDirect: true, avatarURL: nil,
                       heroes: [UserProfile(userID: userID(id), displayName: entry.name, avatarURL: photoURL(entry))],
                       preview: nil, minute: minute, unread: 0, mentions: 0, mode: nil, inviter: member(id))
    }
    
    /// Groups are quiet by default (bipe/docs/groups.md): mentions and keywords only.
    private static func group(_ id: String, preview: String, minute: Int, unread: UInt = 0, mentions: UInt = 0) -> RoomSummary {
        let entry = BipeCast.entry(id)
        return summary(id: id, name: entry.name ?? id, isDirect: false, avatarURL: photoURL(entry), heroes: [],
                       preview: preview, minute: minute, unread: unread, mentions: mentions, mode: .mentionsAndKeywordsOnly, inviter: nil)
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
                    isDM: isDirect,
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
        case text(from: String, String)
        case sticker(from: String, photo: String)
        
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
            case .text(_, let body):
                var content = TextRoomTimelineItemContent(body: body)
                if !isOutgoing {
                    content.bipeScamWarning = ScamDetector.warningKind(for: body, eventID: "$store.\(index)")
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
        }
    }
}
#endif
