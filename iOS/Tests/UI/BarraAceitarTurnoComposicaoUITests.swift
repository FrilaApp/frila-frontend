import XCTest

@MainActor
final class BarraAceitarTurnoComposicaoUITests: XCTestCase {
    func testValorDominanteEBotaoEmTodaALargura() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success",
            "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001",
            "-FRILA_HORARIO_VAGA", "amanha-23h30", "-FRILA_MODO_CLARO"
        ]
        app.launch()
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(botao.frame.height, 56)
        XCTAssertEqual(botao.frame.width, app.frame.width - 32, accuracy: 2)
        XCTAssertEqual(botao.frame.midX, app.frame.midX, accuracy: 1)

        let valor = app.descendants(matching: .any)["valor-da-candidatura"].firstMatch
        XCTAssertTrue(valor.exists)
        // O inteiro em 40 pt ocupa mais altura que uma linha do título em 26 pt.
        XCTAssertGreaterThan(valor.frame.height, 40)
        XCTAssertLessThanOrEqual(valor.frame.maxY, botao.frame.minY)
    }
}
