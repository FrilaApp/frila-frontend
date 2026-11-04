import XCTest

/// Mede a composição renderizada, sem depender das constantes da implementação.
@MainActor
final class BarraAceitarTurnoUITests: XCTestCase {
    func testRodapeCompactoComValorApoioEBotaoDeLarguraTotal() {
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

        let tela = app.windows.firstMatch.frame
        let margem: CGFloat = 16
        XCTAssertGreaterThanOrEqual(botao.frame.height, 56)
        XCTAssertEqual(botao.frame.width, tela.width - 2 * margem, accuracy: 1)
        XCTAssertEqual(botao.frame.midX, tela.midX, accuracy: 1)
        // Rodapé de duas linhas (LOG-021): valor à esquerda, apoio à direita, botão inteiro embaixo.
        XCTAssertEqual(preco.frame.minX, margem, accuracy: 2, "o valor fica na margem esquerda do corpo")
        XCTAssertEqual(apoio.frame.maxX, tela.width - margem, accuracy: 2, "o apoio fica na margem direita do corpo")
        XCTAssertLessThan(preco.frame.maxX, apoio.frame.minX, "valor e apoio ficam lado a lado")
        XCTAssertLessThanOrEqual(preco.frame.maxY, botao.frame.minY)
        XCTAssertLessThanOrEqual(apoio.frame.maxY, botao.frame.minY)
        // A altura da barra é medida no teste unitário (BarraAceitarTurnoTamanhoTests): o quadro de acessibilidade do
        // valor é maior que a caixa compacta desenhada e não serve de régua.
        let conteudo = botao.frame.maxY - min(preco.frame.minY, apoio.frame.minY)
        print("LOG-021 composição: tela=\(tela), valor=\(preco.frame), apoio=\(apoio.frame), botão=\(botao.frame), conteúdo=\(conteudo)")
    }
}
