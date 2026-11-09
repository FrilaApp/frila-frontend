import XCTest

/// B-L1 (cara nova · lote 1: T1, T1b, T2, T3 e estados):
/// Capturas automatizadas no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens na pasta de provas.
@MainActor
final class CapturasLote1UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(extra: [String] = [], ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ] + extra
        if ax5 {
            args += ["-UIPreferredContentSizeCategoryName", Self.ax5]
        }
        app.launchArguments = args
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

        let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"]
            ?? "/Users/cauecarneiro/Documents/Projetos/Frila/orquestracao/retornos/B-L1-provas"
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
    }

    // MARK: - T2: Feed de Vagas

    func testT2FeedPadrao() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success"])
        let busca = app.descendants(matching: .any)["campo-busca-vagas"]
        XCTAssertTrue(busca.waitForExistence(timeout: 10), "O feed de vagas deve abrir")
        capturar("lote1-t2-feed-padrao")
    }

    func testT2FeedAX5() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success"], ax5: true)
        let busca = app.descendants(matching: .any)["campo-busca-vagas"]
        XCTAssertTrue(busca.waitForExistence(timeout: 10))
        capturar("lote1-t2-feed-ax5")
    }

    func testT2SemVagas() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "painel-vazio"])
        let vazio = app.descendants(matching: .any)["vagas-vazio"]
        XCTAssertTrue(vazio.waitForExistence(timeout: 10), "O estado sem vagas deve aparecer")
        capturar("lote1-t2-sem-vagas")
    }

    func testT2BuscaSemResultado() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success"])
        let busca = app.textFields["campo-busca-vagas"]
        XCTAssertTrue(busca.waitForExistence(timeout: 10))
        busca.tap()
        busca.typeText("xyz999naoexiste")
        let semResultado = app.descendants(matching: .any)["vagas-busca-sem-resultado"]
        XCTAssertTrue(semResultado.waitForExistence(timeout: 5), "O estado busca sem resultado deve aparecer")
        capturar("lote1-t2-busca-sem-resultado")
    }

    // MARK: - T2b: Folha de Filtros

    func testT2bFiltros() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success"])
        let botaoFiltro = app.buttons["filtro-abrir"]
        XCTAssertTrue(botaoFiltro.waitForExistence(timeout: 10))
        botaoFiltro.tap()
        let folha = app.descendants(matching: .any)["folha-filtros-t2b"]
        XCTAssertTrue(folha.waitForExistence(timeout: 5), "A folha de filtros T2b deve abrir")
        capturar("lote1-t2b-filtros")
    }

    // MARK: - T3: Detalhe da Vaga

    func testT3DetalhePadrao() {
        let app = iniciar(extra: [
            "-FRILA_SCENARIO", "success",
            "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001",
            "-FRILA_HORARIO_VAGA", "amanha-23h30"
        ])
        let detalhe = app.descendants(matching: .any)["tela-detalhe-vaga"]
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10), "A tela de detalhe deve abrir")
        capturar("lote1-t3-detalhe-padrao")
    }

    func testT3DetalheAX5() {
        let app = iniciar(extra: [
            "-FRILA_SCENARIO", "success",
            "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001",
            "-FRILA_HORARIO_VAGA", "amanha-23h30"
        ], ax5: true)
        let detalhe = app.descendants(matching: .any)["tela-detalhe-vaga"]
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10))
        capturar("lote1-t3-detalhe-ax5")
    }

    // MARK: - T1: Perfil Profissional

    func testT1PerfilPadrao() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"])
        let perfil = app.descendants(matching: .any)["tela-perfil-profissional"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10), "O perfil profissional deve abrir")
        capturar("lote1-t1-perfil-padrao")
    }

    func testT1PerfilAX5() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"], ax5: true)
        let perfil = app.descendants(matching: .any)["tela-perfil-profissional"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        capturar("lote1-t1-perfil-ax5")
    }

    // MARK: - T1b: Escolher Funções

    func testT1bEscolherFuncoes() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"])
        let expandir = app.buttons["botao-expandir-funcoes"]
        XCTAssertTrue(expandir.waitForExistence(timeout: 10))
        expandir.tap()
        let sheet = app.descendants(matching: .any)["tela-escolher-funcoes"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "A folha T1b de funções deve abrir")
        capturar("lote1-t1b-escolher-funcoes")
    }

    func testT1bSemResultado() {
        let app = iniciar(extra: ["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"])
        let expandir = app.buttons["botao-expandir-funcoes"]
        XCTAssertTrue(expandir.waitForExistence(timeout: 10))
        expandir.tap()
        let busca = app.textFields["campo-busca-funcao"]
        XCTAssertTrue(busca.waitForExistence(timeout: 5))
        busca.tap()
        busca.typeText("xyz999naoexiste")
        let semResultado = app.descendants(matching: .any)["estado-sem-resultado-funcoes"]
        XCTAssertTrue(semResultado.waitForExistence(timeout: 5), "O estado sem resultado da busca de função deve aparecer")
        capturar("lote1-t1b-sem-resultado")
    }
}
