//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

/// Bipe: the account switcher on the Você tab (ADR 0135, bipe#446). A double tap switches to the next account, a long press
/// opens the account menu. The tab bar and the iPad rail both use this one menu.
@Observable final class BipeAccountSwitcher {
    /// Every account on the phone, the current one first.
    private(set) var accounts: [BipeAccountMenuItem] = []
    
    @ObservationIgnored var onSwitch: ((String) -> Void)?
    @ObservationIgnored var onAddAccount: (() -> Void)?
    
    @ObservationIgnored private let userSession: UserSessionProtocol
    @ObservationIgnored private var photoTask: Task<Void, Never>?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
    /// With one account a double tap is a tap.
    var canSwitch: Bool {
        accounts.count > 1
    }
    
    init(userSession: UserSessionProtocol) {
        self.userSession = userSession
        
        // The session UI is rebuilt when accounts change, so the profile is the only thing to follow.
        userSession.clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateAccounts(profile: $0) }
            .store(in: &cancellables)
    }
    
    func switchToNextAccount() {
        guard let next = accounts.first(where: { !$0.isCurrent }) else { return }
        onSwitch?(next.userID)
    }
    
    /// The accounts with a check on the current one, then "Nova conta" while the cap allows one more.
    func makeMenu() -> UIMenu {
        let accountActions = accounts.map { account in
            UIAction(title: account.label, image: account.avatar, state: account.isCurrent ? .on : .off) { [weak self] _ in
                guard !account.isCurrent else { return }
                self?.onSwitch?(account.userID)
            }
        }
        var children: [UIMenuElement] = [UIMenu(title: BipeStrings.accountOnDevice, options: .displayInline, children: accountActions)]
        
        if BipeAccountCap.canAdd(signedInUserIDs: accounts.map(\.userID)) {
            let addAction = UIAction(title: BipeStrings.accountAdd, image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.onAddAccount?()
            }
            children.append(UIMenu(options: .displayInline, children: [addAction]))
        }
        return UIMenu(children: children)
    }
    
    // MARK: - Private
    
    /// The live sessions publisher lists only accounts whose session is open, so the keychain gives the list.
    private func updateAccounts(profile: UserProfile) {
        let currentUserID = userSession.clientProxy.userID
        BipeAccountLabels.remember(displayName: profile.displayName, for: currentUserID)
        let current = BipeAccountMenuItem(userID: currentUserID, label: profile.displayName ?? currentUserID, isCurrent: true,
                                          isCompany: BipeAccountLabels.isCompany(currentUserID))
        let others = BipeSignedInAccounts.userIDs.filter { $0 != currentUserID }.sorted().map {
            BipeAccountMenuItem(userID: $0, label: BipeAccountLabels.label(for: $0), isCurrent: false, isCompany: BipeAccountLabels.isCompany($0))
        }
        accounts = ([current] + others).map { $0.withAvatar(photo: nil) }
        loadPhoto(url: profile.avatarURL, userID: currentUserID)
    }
    
    /// Only the current account's session is open, so only its photo can load. The other accounts keep their initials.
    private func loadPhoto(url: URL?, userID: String) {
        photoTask?.cancel()
        guard let url, let source = try? MediaSourceProxy(url: url, mimeType: nil) else { return }
        
        let size = BipeAccountMenuItem.avatarSize
        let task = userSession.mediaProvider.loadImageRetryingOnReconnection(source, size: CGSize(width: size * 3, height: size * 3))
        photoTask = Task { [weak self] in
            guard let photo = try? await task.value, !Task.isCancelled, let self else { return }
            accounts = accounts.map { $0.userID == userID ? $0.withAvatar(photo: photo) : $0 }
        }
    }
}

/// Bipe: one row of the account menu (ADR 0086, bipe#267).
struct BipeAccountMenuItem: Identifiable, Equatable {
    static let avatarSize: CGFloat = 24
    
    let userID: String
    let label: String
    let isCurrent: Bool
    let isCompany: Bool
    /// The avatar drawn into an image, a rounded square for a company (ADR 0132). Menus only render images.
    var avatar: UIImage?
    
    var id: String {
        userID
    }
    
    /// Draws the avatar the way `LoadableAvatarImage` does: the photo, else the initials, in the account's shape.
    func withAvatar(photo: UIImage?) -> BipeAccountMenuItem {
        let avatar = Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                PlaceholderAvatarImage(name: label, contentID: userID)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .avatarShape(isCompany ? .roundedRect : .circle, size: Self.avatarSize)
        
        let renderer = ImageRenderer(content: avatar)
        renderer.scale = 3
        
        var item = self
        item.avatar = renderer.uiImage?.withRenderingMode(.alwaysOriginal)
        return item
    }
}

// MARK: - Gestures

/// The double tap and the long press menu on one view. A tap stays with the view: the tab bar or the rail selects Você.
/// The system context menu plays its own haptic (ADR 0134); a switch plays none, as before.
final class BipeAccountGestures: NSObject, UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {
    var switcher: BipeAccountSwitcher?
    /// The Você item's frame in the host view, or `nil` when the point is not on it.
    var itemFrame: (CGPoint, UIView) -> CGRect? = { _, view in view.bounds }
    /// Only the rail needs this: there the gesture view covers the button, so it takes the tap too.
    var onTap: (() -> Void)?
    
    private weak var hostView: UIView?
    
    func install(on view: UIView) {
        guard hostView !== view else { return }
        hostView = view
        
        view.addInteraction(UIContextMenuInteraction(delegate: self))
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        // The first tap must reach the tab bar at once, so Você opens without waiting for a second tap.
        doubleTap.cancelsTouchesInView = false
        doubleTap.delaysTouchesEnded = false
        doubleTap.delegate = self
        view.addGestureRecognizer(doubleTap)
        
        if onTap != nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }
    }
    
    // MARK: UIContextMenuInteractionDelegate
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let switcher, let view = interaction.view, itemFrame(location, view) != nil else { return nil }
        return UIContextMenuConfiguration(identifier: NSValue(cgPoint: location), previewProvider: nil) { _ in
            switcher.makeMenu()
        }
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configuration: UIContextMenuConfiguration,
                                highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
        preview(interaction, identifier: identifier)
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configuration: UIContextMenuConfiguration,
                                dismissalPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
        preview(interaction, identifier: identifier)
    }
    
    // MARK: UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = gestureRecognizer.view, itemFrame(touch.location(in: view), view) != nil else { return false }
        return onTap != nil || switcher?.canSwitch == true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
    
    // MARK: Private
    
    @objc private func handleTap() {
        onTap?()
    }
    
    @objc private func handleDoubleTap() {
        guard let switcher, switcher.canSwitch else { return }
        switcher.switchToNextAccount()
    }
    
    /// An empty view on the Você item: it anchors the menu and draws nothing. A preview of the host view would hide the whole
    /// tab bar while the menu shows. A snapshot catches the iOS 26 glass lens mid-press and floats a lifted copy of the item.
    private func preview(_ interaction: UIContextMenuInteraction, identifier: any NSCopying) -> UITargetedPreview? {
        guard let view = interaction.view,
              let location = (identifier as? NSValue)?.cgPointValue,
              let frame = itemFrame(location, view) else {
            return nil
        }
        let anchor = UIView(frame: CGRect(origin: .zero, size: frame.size))
        anchor.backgroundColor = .clear
        let parameters = UIPreviewParameters()
        parameters.visiblePath = UIBezierPath(rect: anchor.bounds)
        parameters.shadowPath = UIBezierPath()
        parameters.backgroundColor = .clear
        return UITargetedPreview(view: anchor, parameters: parameters, target: UIPreviewTarget(container: view, center: CGPoint(x: frame.midX, y: frame.midY)))
    }
}

extension BipeAccountGestures {
    /// The Você item in a `UITabBar`. UIKit gives no public frame for a tab item, so this walks up from the touched view to
    /// the row of same-class siblings that has one view per tab, then takes the Você index in reading order.
    static func tabBarItemFrame(index: Int, tabCount: ClosedRange<Int>) -> (CGPoint, UIView) -> CGRect? {
        { point, tabBar in
            var view = tabBar.hitTest(point, with: nil)
            while let candidate = view, candidate !== tabBar, let parent = candidate.superview {
                let row = parent.subviews.filter { type(of: $0) == type(of: candidate) && !$0.isHidden }
                if tabCount.contains(row.count) {
                    var sorted = row.sorted { $0.frame.minX < $1.frame.minX }
                    if tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                        sorted.reverse()
                    }
                    guard sorted.indices.contains(index), sorted[index] === candidate else { return nil }
                    return candidate.convert(candidate.bounds, to: tabBar)
                }
                view = parent
            }
            return nil
        }
    }
}

/// Bipe: the rail's Você button (iPad). The view covers the button and takes the tap, the double tap and the long press.
/// VoiceOver still reaches the button underneath.
struct BipeAccountGestureOverlay: UIViewRepresentable {
    let switcher: BipeAccountSwitcher
    let onTap: () -> Void
    
    func makeCoordinator() -> BipeAccountGestures {
        BipeAccountGestures()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.accessibilityElementsHidden = true
        context.coordinator.switcher = switcher
        context.coordinator.onTap = onTap
        context.coordinator.install(on: view)
        return view
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.switcher = switcher
        context.coordinator.onTap = onTap
    }
}
