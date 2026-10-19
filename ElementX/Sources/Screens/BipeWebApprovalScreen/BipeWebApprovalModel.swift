//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import LocalAuthentication
import SwiftUI
import WebKit

/// What the phone needs to open a MAS page with the hidden password (ADR 0118).
struct BipeWebApprovalDependencies {
    let clientProxy: ClientProxyProtocol
    let apiClient: BipeAPIClient
    let credentialStore: BipeCredentialStore
}

/// The private web view that approves a web sign-in, or ends the session of a linked device, on the MAS pages
/// (ADR 0116, ADR 0118).
///
/// - Approve: the full-access warning and the cooldown, the biometric check, then the MAS page. The user approves
///   on the MAS consent page; the place of the browser IP shows above it.
/// - Sign out: the biometric check, then the MAS account page that ends the session of one device.
///
/// The web view has a non-persistent data store and loads only the MAS host. It fills the MAS login form once with
/// the hidden password and never shows it. When the flow ends, bipe-api ends the MAS browser session it made.
@Observable
final class BipeWebApprovalModel: NSObject {
    enum Purpose {
        case approveSignIn(verificationURL: URL, continuation: ContinuationMessageSenderProxy)
        case signOut(deviceID: String)
    }
    
    enum Step: Equatable {
        /// The full-access warning. The continue button waits until the cooldown ends.
        case warning(secondsLeft: Int)
        /// The biometric check or a MAS page that the user must not see (the login form) is open.
        case loading
        /// A MAS page that the user can see.
        case page
        /// The user left the consent page. The SDK sends the secrets to the browser.
        case finishing
        case failed
    }
    
    private(set) var step: Step
    /// `true` on the MAS consent page of the grant.
    private(set) var isConsentPage = false
    /// The approximate place of the browser IP on the consent page. `nil` until it is known.
    private(set) var placeText: String?
    
    let purpose: Purpose
    @ObservationIgnored let webView: WKWebView
    /// Called when a sign-out page closes or the flow cannot start. The approval flow ends through the SDK.
    @ObservationIgnored var onFinished: (() -> Void)?
    
    @ObservationIgnored private let dependencies: BipeWebApprovalDependencies
    @ObservationIgnored private var masHost: String?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var password: String?
    @ObservationIgnored private var hasSubmittedLogin = false
    @ObservationIgnored private var hasSeenConsentPage = false
    @ObservationIgnored private var hasEnded = false
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var metadataTask: Task<BipeAuthMetadata?, Never>?
    
    init(purpose: Purpose, dependencies: BipeWebApprovalDependencies) {
        self.purpose = purpose
        self.dependencies = dependencies
        
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        
        switch purpose {
        case .approveSignIn:
            step = .warning(secondsLeft: BipeRegistries.webLinkCooldownSeconds)
        case .signOut:
            step = .loading
        }
        
        super.init()
        
        webView.navigationDelegate = self
        let homeserver = URL(string: dependencies.clientProxy.homeserver)
        metadataTask = Task {
            guard let homeserver else { return nil }
            return try? await BipeMatrixAccountAPI(homeserver: homeserver).authMetadata()
        }
        
        switch purpose {
        case .approveSignIn:
            startCountdown()
        case .signOut:
            Task { await verifyOwnerAndOpen() }
        }
    }
    
    // MARK: - Public
    
    /// The continue button of the warning.
    func continueAfterWarning() {
        guard step == .warning(secondsLeft: 0) else { return }
        Task { await verifyOwnerAndOpen() }
    }
    
    /// The close button. Before the consent page the grant is cancelled; after it the SDK continues.
    func close() async {
        switch purpose {
        case .approveSignIn(_, let continuation):
            if hasSeenConsentPage {
                await continuation.confirm()
            } else {
                await continuation.cancel()
            }
        case .signOut:
            break
        }
        end()
        onFinished?()
    }
    
    /// Ends the MAS browser session that this web view made. Safe to call more than once.
    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        countdownTask?.cancel()
        password = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
        
        guard let startedAt else { return }
        let apiClient = dependencies.apiClient
        let clientProxy = dependencies.clientProxy
        Task {
            do {
                let finished = try await BipeAPIClient.withTokenRetry(accessToken: { clientProxy.accessToken }) { (token: String) async throws(BipeAPIError) -> Int in
                    try await apiClient.finishWebLink(since: startedAt, accessToken: token)
                }
                MXLog.info("Bipe web link: ended \(finished) MAS browser sessions")
            } catch {
                MXLog.error("Bipe web link: finish failed: \(error)")
            }
        }
    }
    
    // MARK: - Private
    
    private func startCountdown() {
        countdownTask = Task { [weak self] in
            for secondsLeft in stride(from: BipeRegistries.webLinkCooldownSeconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                step = .warning(secondsLeft: secondsLeft)
            }
        }
    }
    
    private func verifyOwnerAndOpen() async {
        let reason = switch purpose {
        case .approveSignIn: BipeStrings.linkComputerBiometric
        case .signOut: BipeStrings.linkedDevicesSignOutBiometric
        }
        let previousStep = step
        step = .loading
        
        guard await verifyDeviceOwner(reason: reason) else {
            switch purpose {
            case .approveSignIn:
                step = previousStep
            case .signOut:
                end()
                onFinished?()
            }
            return
        }
        
        // The hidden password is read only after the biometric check (ADR 0118).
        let userID = dependencies.clientProxy.userID
        guard let password = dependencies.credentialStore.password(for: userID)?.secret,
              let metadata = await metadataTask?.value,
              let host = metadata.host,
              let url = startURL(metadata: metadata),
              BipeWebLink.isAllowed(url, masHost: host) else {
            MXLog.error("Bipe web link: cannot open the MAS page (no password, no metadata or another host)")
            fail()
            return
        }
        
        self.password = password
        masHost = host
        startedAt = .now
        webView.load(URLRequest(url: url))
    }
    
    private func verifyDeviceOwner(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            MXLog.error("Bipe web link: device owner check unavailable: \(error?.localizedDescription ?? "")")
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            MXLog.info("Bipe web link: device owner check cancelled or failed")
            return false
        }
    }
    
    private func startURL(metadata: BipeAuthMetadata) -> URL? {
        switch purpose {
        case .approveSignIn(let verificationURL, _):
            verificationURL
        case .signOut(let deviceID):
            metadata.accountManagementUri.flatMap { BipeWebLink.sessionEndURL(accountManagementURL: $0, deviceID: deviceID) }
        }
    }
    
    private func fail() {
        step = .failed
        if case .approveSignIn(_, let continuation) = purpose {
            Task { await continuation.cancel() }
        }
        end()
    }
    
    /// Reads the page in the app's own script world, so page scripts do not see these calls.
    private func inspectPage() async {
        guard let url = webView.url, let masHost, BipeWebLink.isAllowed(url, masHost: masHost) else { return }
        
        let script = """
        return {
            hasPasswordForm: document.querySelector('form input[name="password"]') !== null,
            hasForm: document.querySelector('form') !== null,
            text: document.body ? document.body.innerText : ''
        };
        """
        guard let page = try? await webView.callAsyncJavaScript(script, contentWorld: .defaultClient) as? [String: Any] else {
            showPage(url: url, hasForm: false, text: "")
            return
        }
        
        if page["hasPasswordForm"] as? Bool == true {
            await submitLoginForm()
        } else {
            showPage(url: url, hasForm: page["hasForm"] as? Bool == true, text: page["text"] as? String ?? "")
        }
    }
    
    /// Fills and submits the MAS login form once. A second login form means the password did not work.
    private func submitLoginForm() async {
        guard !hasSubmittedLogin, let password, let username = BipeWebLink.localpart(of: dependencies.clientProxy.userID) else {
            MXLog.error("Bipe web link: the MAS login form showed again")
            fail()
            return
        }
        hasSubmittedLogin = true
        self.password = nil
        
        let script = """
        const field = document.querySelector('form input[name="password"]');
        const form = field.form;
        const user = form.querySelector('input[name="username"]');
        if (!user) { return false; }
        user.value = username;
        field.value = password;
        if (form.requestSubmit) { form.requestSubmit(); } else { form.submit(); }
        return true;
        """
        // Arguments go in as values, never as script text.
        let submitted = try? await webView.callAsyncJavaScript(script, arguments: ["username": username, "password": password], contentWorld: .defaultClient)
        if submitted as? Bool != true {
            MXLog.error("Bipe web link: the MAS login form has no username field")
            fail()
        }
    }
    
    private func showPage(url: URL, hasForm: Bool, text: String) {
        guard case .approveSignIn(_, let continuation) = purpose else {
            step = .page
            return
        }
        
        let isConsent = BipeWebLink.isDeviceConsentPath(url) && hasForm
        if isConsent {
            isConsentPage = true
            step = .page
            if !hasSeenConsentPage {
                hasSeenConsentPage = true
                Task { await loadPlace(text: text) }
            }
        } else if hasSeenConsentPage {
            // The user approved or declined on the consent page. The SDK continues (ADR 0118).
            isConsentPage = false
            step = .finishing
            Task { await continuation.confirm() }
            end()
        } else {
            step = .page
        }
    }
    
    private func loadPlace(text: String) async {
        guard let ip = BipeWebLink.firstIPAddress(in: text) else {
            placeText = BipeStrings.linkComputerPlaceUnknown
            return
        }
        let apiClient = dependencies.apiClient
        let clientProxy = dependencies.clientProxy
        let place = try? await BipeAPIClient.withTokenRetry(accessToken: { clientProxy.accessToken }) { (token: String) async throws(BipeAPIError) -> BipeWebLinkPlace in
            try await apiClient.webLinkPlace(ip: ip, accessToken: token)
        }
        placeText = place?.label().map(BipeStrings.linkComputerPlace) ?? BipeStrings.linkComputerPlaceUnknown
    }
}

// MARK: - WKNavigationDelegate

extension BipeWebApprovalModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let masHost, BipeWebLink.isAllowed(url, masHost: masHost) else {
            MXLog.info("Bipe web link: blocked a navigation off the MAS host")
            return .cancel
        }
        return .allow
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        if step == .page {
            step = .loading
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        Task { await inspectPage() }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        handleNavigationError(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        handleNavigationError(error)
    }
    
    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        // A blocked navigation ends as a cancelled load. The page stays as it was.
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        // WebKitErrorFrameLoadInterruptedByPolicyChange: a load that the delegate cancelled.
        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 {
            return
        }
        MXLog.error("Bipe web link: page load failed: \(nsError.domain) \(nsError.code)")
        fail()
    }
}
