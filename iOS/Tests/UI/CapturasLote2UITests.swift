import XCTest

/// B-L2 (cara nova · lote 2: T4, T7 e T8):
/// T7 (Meus Turnos), T4 (Meu Turno antes de sair) e T8 (Meu Turno a caminho / presença) no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam no resultado do teste.
@MainActor
final class CapturasLote2UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(extra: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ] + extra
        if ax5 {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launch()
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    // MARK: - T7: Meus Turnos

    private func fluxoMeusTurnos(ax5: Bool) {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "turno-confirmado-perto", "-FRILA_ABRIR_MEUS_TURNOS"], ax5: ax5)
        let tela = app.descendants(matching: .any)["tela-meus-turnos"]
        XCTAssertTrue(tela.waitForExistence(timeout: 10), "A tela Meus turnos deve abrir")
        capturar("lote2-t7-meus-turnos-\(ax5 ? "ax5" : "padrao")")
    }

    func testMeusTurnosPadrao() { fluxoMeusTurnos(ax5: false) }
    func testMeusTurnosAX5() { fluxoMeusTurnos(ax5: true) }

    // MARK: - T7: Vazio (sem turnos)

    private func fluxoMeusTurnosVazio(ax5: Bool) {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "exportar-turnos-sem-turnos", "-FRILA_ABRIR_MEUS_TURNOS"], ax5: ax5)
        let tela = app.descendants(matching: .any)["tela-meus-turnos"]
        XCTAssertTrue(tela.waitForExistence(timeout: 10), "A tela Meus turnos deve abrir")
        let vazio = app.descendants(matching: .any)["meus-turnos-vazio"]
        XCTAssertTrue(vazio.waitForExistence(timeout: 5), "O estado vazio deve aparecer")
        capturar("lote2-t7-sem-turnos-\(ax5 ? "ax5" : "padrao")")
    }

    func testMeusTurnosVazioPadrao() { fluxoMeusTurnosVazio(ax5: false) }
    func testMeusTurnosVazioAX5() { fluxoMeusTurnosVazio(ax5: true) }

    // MARK: - T4: Meu Turno (antes de sair)

    private func fluxoMeuTurnoT4(ax5: Bool) {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "a-caminho", "-FRILA_ABRIR_MEUS_TURNOS"], ax5: ax5)
        let telaTurnos = app.descendants(matching: .any)["tela-meus-turnos"]
        XCTAssertTrue(telaTurnos.waitForExistence(timeout: 10), "A tela Meus turnos deve abrir")

        let turnoCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turnoCard.waitForExistence(timeout: 5), "O card de turno de hoje deve aparecer")
        turnoCard.tap()

        let telaMeuTurno = app.descendants(matching: .any)["tela-meu-turno"]
        XCTAssertTrue(telaMeuTurno.waitForExistence(timeout: 10), "A tela Meu turno deve abrir")

        capturar("lote2-t4-meu-turno-\(ax5 ? "ax5" : "padrao")")
    }

    func testMeuTurnoT4Padrao() { fluxoMeuTurnoT4(ax5: false) }
    func testMeuTurnoT4AX5() { fluxoMeuTurnoT4(ax5: true) }

    // MARK: - T8: Meu Turno (a caminho / presença)

    private func fluxoMeuTurnoT8(ax5: Bool) {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "a-caminho", "-FRILA_ABRIR_MEUS_TURNOS"], ax5: ax5)
        let telaTurnos = app.descendants(matching: .any)["tela-meus-turnos"]
        XCTAssertTrue(telaTurnos.waitForExistence(timeout: 10), "A tela Meus turnos deve abrir")

        let turnoCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turnoCard.waitForExistence(timeout: 5), "O card de turno deve aparecer")
        turnoCard.tap()

        let telaMeuTurno = app.descendants(matching: .any)["tela-meu-turno"]
        XCTAssertTrue(telaMeuTurno.waitForExistence(timeout: 10), "A tela Meu turno deve abrir")

        let botaoACaminho = app.buttons["botao-a-caminho"]
        if botaoACaminho.waitForExistence(timeout: 5) {
            botaoACaminho.tap()
        }

        let botaoCheckin = app.buttons["fazer-checkin"]
        XCTAssertTrue(botaoCheckin.waitForExistence(timeout: 8), "O botão de marcar presença deve aparecer")

        capturar("lote2-t8-meu-turno-a-caminho-\(ax5 ? "ax5" : "padrao")")
    }

    func testMeuTurnoT8Padrao() { fluxoMeuTurnoT8(ax5: false) }
    func testMeuTurnoT8AX5() { fluxoMeuTurnoT8(ax5: true) }
}
