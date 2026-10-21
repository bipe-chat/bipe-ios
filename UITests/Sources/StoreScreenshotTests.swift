//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest

/// Store screenshots (bipe#454). One test per panel slug in bipe-shared/product/appstore.md. Each test opens a mock
/// screen from `BipeStoreScreens`, waits for an element that every layout and locale shows and attaches the screen as `<slug>`.
/// Run with `appstore/capture.sh`, which sets the simulator and exports the attachments. Not a snapshot test:
/// it compares nothing and runs on any simulator.
@MainActor
final class StoreScreenshotTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
        // The test plan allows 120 s per test. The first test also pays the cold app launch, and a test
        // killed on that limit leaves no capture (aviso-golpe, 20 Oct 2026).
        executionTimeAllowance = 600
    }
    
    func testAvisoGolpe() async throws {
        let app = launch(.bipeStoreAvisoGolpe)
        try await capture("aviso-golpe", app: app, after: roomName(in: app))
    }
    
    func testPedidos() async throws {
        let app = launch(.bipeStorePedidos)
        tap(locale == "pt-BR" ? "Pedidos de conversa" : "Chat requests", in: app)
        try await capture("pedidos", app: app, after: element(containing: "Atendimento Cartões", in: app))
    }
    
    func testSeuArroba() async throws {
        let app = launch(.bipeStoreSeuArroba)
        try await capture("seu-arroba", app: app, after: element(containing: "@gabi.moreira", in: app))
    }
    
    func testConferirPix() async throws {
        let app = launch(.bipeStoreConferirPix)
        try await capture("conferir-pix", app: app, after: element(containing: "RAFAEL OLIVEIRA", in: app))
    }
    
    func testConferirPixAlterado() async throws {
        let app = launch(.bipeStoreConferirPixAlterado)
        try await capture("conferir-pix-alterado", app: app, after: element(containing: "RAFAEL OLIVEIRA", in: app))
    }
    
    func testGrupos() async throws {
        let app = launch(.bipeStoreGrupos)
        tap(locale == "pt-BR" ? "Grupos" : "Groups", in: app)
        try await capture("grupos", app: app, after: element(containing: "Família Lima", in: app))
    }
    
    func testSeloCnpj() async throws {
        let app = launch(.bipeStoreSeloCnpj)
        try await capture("selo-cnpj", app: app, after: roomName(in: app))
    }
    
    func testStickers() async throws {
        let app = launch(.bipeStoreStickers)
        try await capture("stickers", app: app, after: roomName(in: app))
    }
    
    // MARK: - Helpers
    
    /// `capture.sh --locale` passes TEST_RUNNER_BIPE_STORE_LOCALE; xcodebuild drops the prefix for the runner.
    private var locale: String {
        ProcessInfo.processInfo.environment["BIPE_STORE_LOCALE"] ?? "pt-BR"
    }
    
    private func launch(_ screen: UITestsScreenIdentifier) -> XCUIApplication {
        let app = XCUIApplication()
        var environment = ["UI_TESTS_SCREEN": screen.rawValue, "BIPE_STORE_LOCALE": locale]
        environment["BIPE_CAST_PHOTOS"] = ProcessInfo.processInfo.environment["BIPE_CAST_PHOTOS"]
        app.launchEnvironment = environment
        // One Dynamic Type step above the default (Large), so the text reads at App Store thumbnail size (bipe#462).
        app.launchArguments = ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale.replacingOccurrences(of: "-", with: "_"),
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 120), "\(screen.rawValue) did not start")
        return app
    }
    
    private func roomName(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[A11yIdentifiers.roomScreen.name].firstMatch
    }
    
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
    
    private func tap(_ text: String, in app: XCUIApplication) {
        let target = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 30), "No \"\(text)\" to tap")
        target.tap()
    }
    
    /// Attaches the screen even when the text is missing, so a failed run still shows what was on screen.
    private func capture(_ slug: String, app: XCUIApplication, after marker: XCUIElement) async throws {
        let found = marker.waitForExistence(timeout: 30)
        // Photos load and sheets settle after the text shows.
        try await Task.sleep(for: .seconds(2))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = slug
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(found, "The \(slug) screen did not load")
    }
}
