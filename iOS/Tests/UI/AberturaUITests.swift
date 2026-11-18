import UIKit
import XCTest

/// Abertura animada: fica desligada nos testes de interface, cobre o app sem segurar o que carrega por baixo e um
/// toque leva direto à entrada. As capturas usam a abertura parada num instante do roteiro.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class AberturaUITests: XCTestCase {
    /// Uma abertura de 20 s: a saída natural só viria aos 17 s, então o que o teste vê antes disso aconteceu por
    /// baixo dela, ou por causa do toque.
    private static let lenta = ["-FRILA_ABERTURA_DURACAO", "20"]
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = extra + ["-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        return app
    }

    private func abertura(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["abertura-animada"]
    }

    private func capturar(_ nome: String) {
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

    // MARK: - Desligada nos testes

    func testOAjudanteDesligaAAberturaEmTodoTesteDeInterface() {
        let app = iniciar(["-FRILA_ENTRADA"])
        XCTAssertTrue(app.launchArguments.contains("-FRILA_SEM_ABERTURA"), "o ajudante de lançamento deve desligar a abertura")
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer), "a entrada deve abrir")
        XCTAssertFalse(abertura(app).exists, "sem abertura por cima da entrada")
    }

    func testComOArgumentoAAberturaNaoAparece() {
        // Mesmo com a abertura lenta pedida, o argumento de desligar vence: se ela tocasse, ainda estaria na tela.
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SEM_ABERTURA"] + Self.lenta)
        let campo = app.textFields["entrada-email"]
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer), "a entrada deve abrir")
        XCTAssertFalse(abertura(app).exists, "sem abertura por cima da entrada")
        XCTAssertTrue(campo.isHittable, "o campo de e-mail deve estar tocável de imediato")
    }

    // MARK: - O app carrega por baixo

    func testAEntradaCarregaPorBaixoDaAbertura() {
        let app = iniciar(["-FRILA_ENTRADA"] + Self.lenta)
        XCTAssertTrue(abertura(app).waitForExistence(timeout: Espera.aparecer), "a abertura deve cobrir o app")
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer),
                      "a entrada deve montar por baixo da abertura")
        XCTAssertTrue(abertura(app).exists, "a abertura ainda cobre: a entrada montou durante ela, não depois")
    }

    func testComSessaoAsAbasCarregamPorBaixoDaAbertura() {
        let app = iniciar(["-FRILA_SCENARIO", "success", "-FRILA_CACHE_VAZIO_UI_TEST"] + Self.lenta)
        XCTAssertTrue(abertura(app).waitForExistence(timeout: Espera.aparecer), "a abertura deve cobrir o app")
        // As abas só existem depois de o app ler a sessão e pedir o destino da conta: as chamadas saíram com a abertura na tela.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Espera.aparecer),
                      "as abas devem montar por baixo da abertura")
        XCTAssertTrue(abertura(app).exists, "a abertura ainda cobre: as abas montaram durante ela, não depois")
    }

    // MARK: - O toque pula

    func testUmToqueLevaDiretoAEntrada() {
        let app = iniciar(["-FRILA_ENTRADA"] + Self.lenta)
        let cena = abertura(app)
        XCTAssertTrue(cena.waitForExistence(timeout: Espera.aparecer), "a abertura deve cobrir o app")
        let campo = app.textFields["entrada-email"]
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer), "a entrada deve montar por baixo da abertura")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Sem o toque, a abertura lenta ficaria 20 s na tela.
        XCTAssertTrue(cena.waitForNonExistence(timeout: 8), "o toque deve tirar a abertura")
        XCTAssertTrue(campo.isHittable, "depois do toque, o campo de e-mail deve estar tocável")
        capturar("abertura-depois-do-toque")

        // Voltar do segundo plano não toca a abertura de novo: ela é só da abertura a frio.
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer), "a entrada continua na tela ao voltar")
        XCTAssertFalse(cena.exists, "voltar do segundo plano não toca a abertura")
    }

    // MARK: - Capturas

    func testCapturasDaAbertura() {
        for (nome, instante) in [("inicio", "0.30"), ("meio", "1.25"), ("fim", "2.60")] {
            let app = iniciar(["-FRILA_ENTRADA", "-FRILA_ABERTURA_CONGELADA", instante])
            XCTAssertTrue(abertura(app).waitForExistence(timeout: Espera.aparecer), "a abertura deve cobrir o app")
            XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer))
            capturar("abertura-\(nome)")
            app.terminate()
        }
    }

    /// O roteiro reduzido vem do ajuste do sistema, que argumento de lançamento não liga: o teste só roda com o
    /// Reduzir Movimento ligado no simulador (`xcrun simctl spawn <id> defaults write com.apple.Accessibility
    /// ReduceMotionEnabled -bool true`, como faz `Scripts/auditoria-de-acessibilidade.sh`).
    func testCapturasDaAberturaComReduzirMovimento() throws {
        try XCTSkipUnless(UIAccessibility.isReduceMotionEnabled, "pede o Reduzir Movimento ligado no simulador")
        for (nome, instante) in [("parada", "0.30"), ("saindo", "0.75")] {
            let app = iniciar(["-FRILA_ENTRADA", "-FRILA_ABERTURA_CONGELADA", instante])
            XCTAssertTrue(abertura(app).waitForExistence(timeout: Espera.aparecer), "a abertura deve cobrir o app")
            XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer))
            capturar("abertura-reduzir-movimento-\(nome)")
            app.terminate()
        }
    }

    func testCapturasDaEntradaComAArte() {
        for (nome, argumentos) in [("padrao", [String]()), ("ax5", ["-UIPreferredContentSizeCategoryName", Self.ax5])] {
            let app = iniciar(["-FRILA_ENTRADA"] + argumentos)
            XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer), "a entrada deve abrir")
            // A arte entra em 0,82 s: a captura espera ela assentar.
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            capturar("entrada-com-a-arte-\(nome)")
            app.terminate()
        }
    }

    // MARK: - Medida

    /// Tempo do lançamento até a entrada existir, sem a abertura e com ela por cima. Só mede e escreve no log
    /// (`FRILA_MEDIR_ABERTURA=1`): não reprova por tempo, que varia com a máquina.
    func testMedeOTempoAteAEntradaComESemAAbertura() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRILA_MEDIR_ABERTURA"] == "1", "medida sob pedido")
        func medir(_ extra: [String]) -> TimeInterval {
            let app = XCUIApplication()
            app.launchArguments = ["-FRILA_ENTRADA"] + extra
            let inicio = Date()
            app.launch()
            XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer))
            let decorrido = Date().timeIntervalSince(inicio)
            app.terminate()
            return decorrido
        }
        var sem: [TimeInterval] = [], com: [TimeInterval] = []
        for _ in 0..<5 {
            sem.append(medir(["-FRILA_SEM_ABERTURA"]))
            com.append(medir(Self.lenta))
        }
        func texto(_ valores: [TimeInterval]) -> String {
            valores.sorted().map { String(format: "%.2f", $0) }.joined(separator: " ")
        }
        print("MEDIDA_ABERTURA sem=[\(texto(sem))] com=[\(texto(com))] (segundos do lançamento até a entrada existir)")
    }
}
