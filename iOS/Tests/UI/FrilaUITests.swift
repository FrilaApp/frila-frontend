import XCTest

@MainActor
final class FrilaUITests: XCTestCase {
    func testCatalogoAbreEmPortugues() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continuar"].exists)
    }

    func testCatalogoComTamanhoDeAcessibilidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
    }
}
