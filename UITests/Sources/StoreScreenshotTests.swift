//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest

/// Store screenshots (bipe#454). One test per panel slug in bipe-shared/product/appstore.md. Each test opens a mock
/// screen from `BipeStoreScreens`, waits for text that every layout shows and attaches the screen as `<slug>`.
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
        try await capture("aviso-golpe", app: app, after: "Caiu na água")
    }
    
    func testPedidos() async throws {
        let app = launch(.bipeStorePedidos)
        tap("Pedidos de conversa", in: app)
        try await capture("pedidos", app: app, after: "Atendimento Cartões")
    }
    
    func testSeuArroba() async throws {
        let app = launch(.bipeStoreSeuArroba)
        try await capture("seu-arroba", app: app, after: "@gabi.moreira")
    }
    
    func testConferirPix() async throws {
        let app = launch(.bipeStoreConferirPix)
        try await capture("conferir-pix", app: app, after: "RAFAEL OLIVEIRA")
    }
    
    func testGrupos() async throws {
        let app = launch(.bipeStoreGrupos)
        tap("Grupos", in: app)
        try await capture("grupos", app: app, after: "Família Lima")
    }
    
    func testSeloCnpj() async throws {
        let app = launch(.bipeStoreSeloCnpj)
        try await capture("selo-cnpj", app: app, after: "Consulta confirmada")
    }
    
    func testStickers() async throws {
        let app = launch(.bipeStoreStickers)
        try await capture("stickers", app: app, after: "Sexta tem churrasco")
    }
    
    // MARK: - Helpers
    
    private func launch(_ screen: UITestsScreenIdentifier) -> XCUIApplication {
        let app = XCUIApplication()
        var environment = ["UI_TESTS_SCREEN": screen.rawValue]
        // capture.sh passes TEST_RUNNER_BIPE_CAST_PHOTOS; xcodebuild drops the prefix for the runner.
        environment["BIPE_CAST_PHOTOS"] = ProcessInfo.processInfo.environment["BIPE_CAST_PHOTOS"]
        app.launchEnvironment = environment
        app.launchArguments = ["-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 120), "\(screen.rawValue) did not start")
        return app
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
    private func capture(_ slug: String, app: XCUIApplication, after text: String) async throws {
        let found = element(containing: text, in: app).waitForExistence(timeout: 30)
        // Photos load and sheets settle after the text shows.
        try await Task.sleep(for: .seconds(2))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = slug
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(found, "No \"\(text)\" on the \(slug) screen")
    }
}
