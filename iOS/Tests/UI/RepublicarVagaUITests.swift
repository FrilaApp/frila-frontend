import XCTest

@MainActor
final class RepublicarVagaUITests: XCTestCase {
    func testRepublicarVagaEncerradaCaminhoFeliz() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))

        // Na seção de encerradas, o botão de publicar de novo existe
        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()

        // Abre a tela de republicação com os dados copiados
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Republicar vaga"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cartao-dados-copiados-republicacao"].exists)

        let pasta = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/thor/capturas"
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        let caminhoCaptura = "\(pasta)/republicar-vaga.png"
        let captura = app.screenshot()
        try? captura.pngRepresentation.write(to: URL(fileURLWithPath: caminhoCaptura))

        // Toca em confirmar republicação
        let botaoConfirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: 5))
        botaoConfirmar.tap()

        // A folha fecha e a lista de Minhas vagas permanece visível com a atualização
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
    }
}
