import XCTest

/// Mede a composição renderizada, sem depender das constantes da implementação.
@MainActor
final class BarraAceitarTurnoUITests: XCTestCase {
    func testValorDominanteEBotaoDeLarguraTotal() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success",
            "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001",
            "-FRILA_HORARIO_VAGA", "amanha-23h30", "-FRILA_MODO_CLARO"
        ]
        app.launch()

        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: botao)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: 10), .completed)
        let preco = app.descendants(matching: .any)["candidatura-valor"].firstMatch
        XCTAssertTrue(preco.waitForExistence(timeout: 5))
        let apoio = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "por pessoa", "23h30"
        )).firstMatch
        XCTAssertTrue(apoio.exists)
        let titulos = app.staticTexts.matching(NSPredicate(format: "label == %@", "Garçom")).allElementsBoundByIndex
        guard let titulo = titulos.max(by: { $0.frame.height < $1.frame.height }) else {
            return XCTFail("O título da vaga deve aparecer")
        }

        let tela = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(botao.frame.height, 56)
        XCTAssertEqual(botao.frame.width, tela.width - 32, accuracy: 1)
        XCTAssertEqual(botao.frame.midX, tela.midX, accuracy: 1)
        XCTAssertLessThan(preco.frame.minY, apoio.frame.minY)
        XCTAssertLessThanOrEqual(preco.frame.maxY, botao.frame.minY)
        XCTAssertLessThanOrEqual(apoio.frame.maxY, botao.frame.minY)
        XCTAssertEqual(preco.frame.midX, tela.midX, accuracy: 1)
        XCTAssertEqual(apoio.frame.midX, tela.midX, accuracy: 1)
        // O grupo combina valor e apoio. Desconta a linha de apoio para
        // medir o espaço reservado ao valor; Jost de 26 pt fica abaixo do piso.
        let alturaDoValor = preco.frame.height - apoio.frame.height
        XCTAssertGreaterThan(alturaDoValor, 45)
        XCTAssertGreaterThan(alturaDoValor, titulo.frame.height + 8)
        print("LOG-018 composição: tela=\(tela), preço=\(preco.frame), valor sem apoio=\(alturaDoValor), título=\(titulo.frame), botão=\(botao.frame)")
        print("LOG-018 área útil: navegação=\(app.navigationBars.firstMatch.frame), rolagem=\(app.scrollViews.firstMatch.frame)")
    }
}
