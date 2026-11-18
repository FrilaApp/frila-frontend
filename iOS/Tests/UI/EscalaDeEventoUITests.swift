import XCTest

/// A escala de evento da casa (`publicar_escala`, contrato 0.2.96): o caminho feliz contra o dublê em memória e as capturas
/// da tela no tamanho padrão e em AX5. `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no
/// resultado do teste.
@MainActor
final class EscalaDeEventoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Ajudantes

    private func abrir(ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante", "-FRILA_CACHE_VAZIO_UI_TEST", "-FRILA_MODO_CLARO",
                               "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func vagas(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'"))
    }

    /// Abre a escala pela entrada de Minhas vagas e devolve quantas vagas a lista tinha antes.
    @discardableResult
    private func abrirEscala(_ app: XCUIApplication) -> Int {
        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: 15), "Minhas vagas deve abrir")
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: Espera.aparecer))
        let antes = vagas(app).count
        tocar(app.buttons["publicar-escala-entrada"])
        XCTAssertTrue(elemento("escala-nome", em: app).waitForExistence(timeout: Espera.aparecer), "A escala deve abrir")
        return antes
    }

    /// Rola até o elemento ficar inteiro entre a barra e o rodapé (o rodapé ancorado cobre a base da janela).
    private func trazer(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<12 {
            let quadro = elemento.frame
            if elemento.exists, quadro.minY > 130, quadro.maxY < janela.height - 150 { return }
            if elemento.exists, quadro.minY <= 130 { app.swipeDown(velocity: .slow) } else { app.swipeUp(velocity: .slow) }
        }
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let nomeCompleto = "escala-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeCompleto
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeCompleto).png"))
        }
    }

    /// Escolhe a primeira função da folha (`indice` 0) ou a segunda (`indice` 1) para a vaga `vaga`.
    private func escolherFuncao(_ app: XCUIApplication, vaga: Int, opcao indice: Int) {
        let linha = app.buttons["escala-funcao-\(vaga)"]
        trazer(linha, em: app)
        tocar(linha)
        XCTAssertTrue(elemento("escala-folha-de-funcao", em: app).waitForExistence(timeout: Espera.aparecer))
        let opcoes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escala-opcao-funcao-'"))
        XCTAssertTrue(opcoes.element(boundBy: indice).waitForExistence(timeout: Espera.aparecer))
        tocar(opcoes.element(boundBy: indice))
        XCTAssertTrue(linha.waitForExistence(timeout: Espera.aparecer))
    }

    private func digitarValor(_ app: XCUIApplication, vaga: Int, centavos: String) {
        let campo = app.textFields.matching(identifier: "valor-vaga-campo").element(boundBy: vaga)
        trazer(campo, em: app)
        tocar(campo)
        campo.typeText(centavos)
        fecharTeclado(app)
    }

    // MARK: Caminho feliz

    func testCasaPublicaUmaEscalaComDuasVagasEElasApareceNaLista() {
        let app = abrir()
        let antes = abrirEscala(app)

        substituirTexto(app.textFields["escala-nome"], por: "Formatura de Direito")
        fecharTeclado(app)
        let responsavel = app.textFields["escala-responsavel"]
        trazer(responsavel, em: app)
        substituirTexto(responsavel, por: "Marina")
        fecharTeclado(app)

        escolherFuncao(app, vaga: 0, opcao: 0)
        digitarValor(app, vaga: 0, centavos: "16000")

        let adicionar = app.buttons["escala-adicionar-vaga"]
        trazer(adicionar, em: app)
        tocar(adicionar)
        XCTAssertTrue(elemento("escala-vaga-1", em: app).waitForExistence(timeout: Espera.aparecer), "A segunda vaga deve entrar")
        escolherFuncao(app, vaga: 1, opcao: 1)
        digitarValor(app, vaga: 1, centavos: "18000")
        let maisUma = app.buttons["escala-pessoas-mais-1"]
        trazer(maisUma, em: app)
        tocar(maisUma)
        XCTAssertEqual(elemento("escala-total-de-pessoas", em: app).label, "Total: 3 de 100 pessoas")

        tocar(app.buttons["escala-publicar"])

        let confirmacao = elemento("escala-confirmacao", em: app)
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 15), "A escala publicada deve ser confirmada")
        XCTAssertTrue(confirmacao.label.contains("2 vagas"), confirmacao.label)
        tocar(app.buttons["escala-ver-minhas-vagas"])

        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: Espera.aparecer))
        expectation(for: NSPredicate(format: "count == %d", antes + 2), evaluatedWith: vagas(app))
        waitForExpectations(timeout: 15)
    }

    func testPublicarComFormularioVazioMarcaOsCamposENaoPublicaNada() {
        let app = abrir()
        let antes = abrirEscala(app)

        tocar(app.buttons["escala-publicar"])

        let mensagem = elemento("escala-mensagem", em: app)
        XCTAssertTrue(mensagem.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(mensagem.label.contains("Nada foi publicado"), mensagem.label)
        XCTAssertTrue(elemento("escala-erro-nome", em: app).exists)
        XCTAssertFalse(elemento("escala-confirmacao", em: app).exists)

        tocar(app.buttons["escala-cancelar"])
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(vagas(app).count, antes)
    }

    /// Em AX5 o aviso vai para o alto da rolagem: depois de Publicar ele tem de aparecer na tela (rolagem até ele), e não
    /// ficar fora da primeira tela, onde quem só aumenta a letra acharia que o botão não fez nada.
    func testEmAX5OErroAparecaNaTelaDepoisDePublicar() {
        let app = abrir(ax5: true)
        abrirEscala(app)

        // Desce a tela, para o aviso do alto ficar fora dela antes do toque.
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        tocar(app.buttons["escala-publicar"])

        let mensagem = elemento("escala-mensagem", em: app)
        XCTAssertTrue(mensagem.waitForExistence(timeout: Espera.aparecer))
        let janela = app.windows.firstMatch.frame
        let visivel = NSPredicate { _, _ in
            let quadro = mensagem.frame
            return mensagem.exists && quadro.minY >= 100 && quadro.maxY <= janela.height - 100
        }
        expectation(for: visivel, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        capturar("2-erros-de-campo", ax5: true)
    }

    // MARK: Capturas (tamanho padrão e AX5)

    func testCapturasDaEscala() {
        for ax5 in [false, true] {
            let app = abrir(ax5: ax5)
            abrirEscala(app)
            capturar("1-formulario", ax5: ax5)

            tocar(app.buttons["escala-publicar"])
            XCTAssertTrue(elemento("escala-mensagem", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("2-erros-de-campo", ax5: ax5)

            substituirTexto(app.textFields["escala-nome"], por: "Formatura de Direito")
            fecharTeclado(app)
            let responsavel = app.textFields["escala-responsavel"]
            trazer(responsavel, em: app)
            substituirTexto(responsavel, por: "Marina")
            fecharTeclado(app)
            let funcao = app.buttons["escala-funcao-0"]
            trazer(funcao, em: app)
            tocar(funcao)
            XCTAssertTrue(elemento("escala-folha-de-funcao", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("3-escolher-funcao", ax5: ax5)
            tocar(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escala-opcao-funcao-'")).firstMatch)

            let adicionar = app.buttons["escala-adicionar-vaga"]
            trazer(adicionar, em: app)
            tocar(adicionar)
            XCTAssertTrue(elemento("escala-vaga-1", em: app).waitForExistence(timeout: Espera.aparecer))
            trazer(elemento("escala-vaga-1", em: app), em: app)
            capturar("4-duas-vagas", ax5: ax5)

            digitarValor(app, vaga: 0, centavos: "16000")
            escolherFuncao(app, vaga: 1, opcao: 1)
            digitarValor(app, vaga: 1, centavos: "18000")
            tocar(app.buttons["escala-publicar"])
            XCTAssertTrue(elemento("escala-confirmacao", em: app).waitForExistence(timeout: 15))
            capturar("5-publicada", ax5: ax5)
            app.terminate()
        }
    }
}
