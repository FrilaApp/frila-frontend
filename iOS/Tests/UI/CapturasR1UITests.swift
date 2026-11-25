import XCTest

/// R1 do redesign (entrada e conta): Entrar, Confirmar o código, Cadastro, Atualização necessária, Conta suspensa
/// (com a contestação) e Excluir conta, no tamanho padrão e em AX5. Cada captura confere também o alvo de toque do
/// botão principal da tela (48 pt no desenho; o teste exige ao menos 44).
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR1UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(_ extra: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = extra + ["-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR",
                                       "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, _ ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let arquivo = "\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = arquivo
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(arquivo).png"))
        }
    }

    private func conferirAlvo(_ elemento: XCUIElement, _ nome: String) {
        XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer), "\(nome) deve existir")
        XCTAssertGreaterThanOrEqual(elemento.frame.height, 44, "\(nome): alvo de toque de ao menos 44 pt")
    }

    /// Rola até o elemento ficar tocável, sem passar do limite.
    private func rolarAte(_ elemento: XCUIElement, _ app: XCUIApplication) {
        fecharTecladoPeloOk(app)
        for _ in 0..<8 where !elemento.isHittable { app.swipeUp() }
    }

    // MARK: - Entrada e código

    private func entrar(email: String, _ app: XCUIApplication) {
        abrirCriarContaPelaEntrada(app)
        let campo = app.textFields["entrada-email"]
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer), "a entrada deve abrir")
        // Com texto grande o campo nasce abaixo da dobra: uma rolagem o traz, como no teste de cadastro existente.
        if campo.frame.minY > app.windows.firstMatch.frame.height * 0.6 { app.swipeUp() }
        campo.tap()
        campo.digitarEEsperar(email)
        tocarFechandoTeclado(app.buttons["entrada-receber-codigo"], em: app)
        XCTAssertTrue(app.textFields["Código de acesso"].waitForExistence(timeout: Espera.aparecer), "a tela do código deve abrir")
    }

    private func telaDeEntrada(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)
        abrirCriarContaPelaEntrada(app)
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer))
        conferirAlvo(app.buttons["entrada-receber-codigo"], "Receber código")
        capturar("r1-entrada", ax5)
        // Sem e-mail, o toque mostra o que falta junto do campo.
        app.buttons["entrada-receber-codigo"].tap()
        for _ in 0..<4 where !app.textFields["entrada-email"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Digite seu e-mail para receber o código."].waitForExistence(timeout: Espera.aparecer))
        capturar("r1-entrada-erro", ax5)
    }

    private func telaDoCodigo(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)
        entrar(email: "novo@frila.app", app)
        conferirAlvo(app.buttons["codigo-entrar"], "Entrar")
        conferirAlvo(app.buttons["Colar código"], "Colar código")
        capturar("r1-codigo", ax5)
        app.textFields["Código de acesso"].tap()
        app.textFields["Código de acesso"].typeText("123")
        capturar("r1-codigo-digitando", ax5)
    }

    private func codigoIncorreto(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "codigo-errado"], ax5: ax5)
        entrar(email: "teste@frila.app", app)
        app.textFields["Código de acesso"].tap()
        app.textFields["Código de acesso"].typeText("000000")
        let erro = app.descendants(matching: .any)["codigo-erro"]
        XCTAssertTrue(erro.waitForExistence(timeout: Espera.aparecer), "o erro do código aparece")
        // A captura vem antes das conferências: se uma delas falhar, a imagem mostra o que a pessoa via.
        capturar("r1-codigo-erro", ax5)
        // Existir não basta: com o teclado aberto (e com texto grande), o erro tem de estar inteiro na tela, acima
        // do teclado, sem a pessoa precisar rolar para saber o que houve.
        let teclado = app.keyboards.firstMatch
        let fimDaAreaVisivel = teclado.exists ? teclado.frame.minY : app.windows.firstMatch.frame.maxY
        XCTAssertTrue(erro.isHittable, "o erro do código fica à vista depois do código errado (erro \(erro.frame), fim \(fimDaAreaVisivel))")
        XCTAssertLessThanOrEqual(erro.frame.maxY, fimDaAreaVisivel + 1,
                                 "o erro inteiro fica acima do teclado (erro \(erro.frame), fim \(fimDaAreaVisivel))")
        // O caminho do reenvio continua ao alcance: no máximo com a rolagem da própria tela.
        let reenvio = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ["codigo-reenviar", "codigo-reenviar-aguarde"])).firstMatch
        XCTAssertTrue(reenvio.waitForExistence(timeout: Espera.aparecer), "o reenvio existe na tela do código")
        // As caixas continuam na tela para a pessoa digitar de novo, e o reenvio ao alcance da rolagem.
        let caixas = app.textFields["Código de acesso"]
        XCTAssertLessThanOrEqual(caixas.frame.maxY, fimDaAreaVisivel + 1,
                                 "as caixas do código seguem acima do teclado (caixas \(caixas.frame), fim \(fimDaAreaVisivel))")
        XCTAssertFalse(caixas.frame.intersects(erro.frame),
                       "o erro não cobre as caixas (caixas \(caixas.frame), erro \(erro.frame))")
        // O teclado sai antes de rolar, pelo "OK" dele: com o teclado aberto e texto grande, a faixa livre é menor que o
        // próprio reenvio. (`swipeUp()` nascia no centro da janela, em cima do erro preso no alto, que fica fora da
        // rolagem: não movia nada, e o teste só passava porque o reenvio encostava 1,7 pt na tela.)
        // O "OK" não aparece para o teste como botão (a barra do teclado existe, sem filhos): o toque vai no lugar
        // dele, no canto direito da barra, logo acima do teclado.
        let tecladoAberto = app.keyboards.firstMatch
        if tecladoAberto.exists {
            let quadroDoTeclado = tecladoAberto.frame
            let canto = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            for recuo in [41.0, 30.0, 52.0] where app.keyboards.count > 0 {
                canto.withOffset(CGVector(dx: quadroDoTeclado.maxX - 46, dy: quadroDoTeclado.minY - recuo)).tap()
                _ = tecladoAberto.waitForNonExistence(timeout: 2)
            }
        }
        XCTAssertEqual(app.keyboards.count, 0, "o teclado fecha pelo OK antes da rolagem")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // A janela livre: abaixo do erro preso no alto (texto grande) ou da barra, e acima do pé da tela ou do grupo
        // ancorado, onde o erro fica no tamanho padrão.
        let janela = app.windows.firstMatch.frame
        let erroPresoNoAlto = erro.frame.maxY <= caixas.frame.minY
        let topo = erroPresoNoAlto ? erro.frame.maxY : app.navigationBars.firstMatch.frame.maxY
        let fundo = erroPresoNoAlto ? janela.maxY - 40 : min(janela.maxY - 40, erro.frame.minY)
        func dentroDaJanela() -> Bool { reenvio.frame.minY >= topo - 1 && reenvio.frame.maxY <= fundo + 1 }
        let origem = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<6 where !(dentroDaJanela() && reenvio.isHittable) {
            if dentroDaJanela() { break }
            // Só o que falta, devagar e sem embalo, pela margem da tela (fora de qualquer controle).
            let quadro = reenvio.frame
            let sobe = quadro.maxY > fundo
            let curso = sobe ? quadro.maxY - fundo + 12 : topo - quadro.minY + 12
            let partida = sobe ? fundo - 24 : topo + 24
            let chegada = sobe ? max(partida - curso, janela.minY + 20) : min(partida + curso, janela.maxY - 20)
            origem.withOffset(CGVector(dx: janela.maxX - 6, dy: partida))
                .press(forDuration: 0.05, thenDragTo: origem.withOffset(CGVector(dx: janela.maxX - 6, dy: chegada)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        let quadros = "reenvio \(reenvio.frame), janela livre de \(topo) a \(fundo), erro \(erro.frame), caixas \(caixas.frame)"
        XCTAssertTrue(reenvio.isHittable, "o reenvio fica ao alcance depois do código errado (\(quadros))")
        XCTAssertTrue(dentroDaJanela(), "o reenvio fica inteiro na tela, na janela livre (\(quadros))")
    }

    // MARK: - Cadastro

    private func telaDeCadastro(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)
        entrar(email: "novo@frila.app", app)
        app.textFields["Código de acesso"].tap()
        app.textFields["Código de acesso"].typeText("123456")
        definirSenhaObrigatoria(app)
        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: Espera.aparecer), "o cadastro deve abrir")
        conferirAlvo(app.buttons["cadastro-continuar"], "Continuar")
        capturar("r1-cadastro", ax5)

        let nome = app.textFields["cadastro-nome"]
        rolarAte(nome, app)
        nome.tap()
        nome.typeText("Carlos Silva")
        let telefone = app.textFields["cadastro-telefone"]
        rolarAte(telefone, app)
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        let nascimento = app.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app)
        nascimento.tap()
        nascimento.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoPeloOk(app)
        capturar("r1-cadastro-dados", ax5)

        // Sem aceitar os Termos, o Continuar mostra o que falta junto do botão.
        tocarFechandoTeclado(app.buttons["cadastro-continuar"], em: app)
        XCTAssertTrue(app.descendants(matching: .any)["cadastro-erro"].waitForExistence(timeout: Espera.aparecer))
        capturar("r1-cadastro-erro", ax5)

        let termos = app.buttons["cadastro-termos"]
        rolarAte(termos, app)
        XCTAssertGreaterThanOrEqual(termos.frame.height, 44, "a caixa dos Termos tem alvo de ao menos 44 pt")
        termos.tap()
        XCTAssertTrue(termos.isSelected)
        capturar("r1-cadastro-termos", ax5)
    }

    // MARK: - Atualização necessária

    private func atualizacaoNecessaria(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "atualizacao-obrigatoria"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Atualização necessária"].waitForExistence(timeout: Espera.aparecer))
        conferirAlvo(app.buttons["Atualizar agora"], "Atualizar agora")
        capturar("r1-atualizacao-necessaria", ax5)
    }

    // MARK: - Conta suspensa

    private func contaSuspensa(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "conta-suspensa"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["tela-conta-suspensa"].waitForExistence(timeout: Espera.aparecer))
        let contestar = app.buttons["botao-contestar-suspensao"]
        conferirAlvo(contestar, "Contestar suspensão")
        capturar("r1-conta-suspensa", ax5)

        // O fim da tela: as ações de conta, a de risco como ação discreta.
        rolarAte(app.buttons["conta-suspensa-sair"], app)
        capturar("r1-conta-suspensa-acoes", ax5)
        XCTAssertGreaterThanOrEqual(app.buttons["conta-suspensa-sair"].frame.height, 44, "Sair da conta tem alvo de ao menos 44 pt")

        contestar.tap()
        let relato = app.descendants(matching: .any)["campo-relato-contestacao"].firstMatch
        XCTAssertTrue(relato.waitForExistence(timeout: Espera.aparecer))
        conferirAlvo(app.buttons["botao-enviar-contestacao"], "Enviar contestação")
        capturar("r1-conta-suspensa-contestacao", ax5)

        relato.tap()
        relato.typeText("Contestação com motivos fundamentados pela parte")
        capturar("r1-conta-suspensa-relato", ax5)
        tocarFechandoTeclado(app.buttons["botao-enviar-contestacao"], em: app)
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-contestacao"].waitForExistence(timeout: Espera.aparecer))
        capturar("r1-conta-suspensa-protocolo", ax5)
    }

    // MARK: - Excluir conta

    private func excluirConta(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer))
        conta.tap()
        let caminho = app.buttons["perfil-sair-ou-excluir"]
        XCTAssertTrue(caminho.waitForExistence(timeout: Espera.aparecer))
        rolarAte(caminho, app)
        caminho.tap()
        let irParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(irParaExclusao.waitForExistence(timeout: Espera.aparecer))
        irParaExclusao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].waitForExistence(timeout: Espera.aparecer))
        let excluir = app.buttons["botao-excluir-conta-definitivo"]
        conferirAlvo(excluir, "Excluir minha conta definitivamente")
        XCTAssertFalse(excluir.isEnabled, "o botão fica desligado até a confirmação")
        capturar("r1-excluir-conta", ax5)

        let toggle = app.switches["toggle-confirmar-consequencias"]
        rolarAte(toggle, app)
        capturar("r1-excluir-conta-confirmacao", ax5)
        let interruptor = toggle.switches.firstMatch
        if interruptor.exists { interruptor.tap() } else { toggle.tap() }
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: excluir)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: Espera.aparecer), .completed)
        rolarAte(excluir, app)
        excluir.tap()
        XCTAssertTrue(app.buttons["botao-cancelar-exclusao-dialogo"].waitForExistence(timeout: Espera.aparecer))
        capturar("r1-excluir-conta-dialogo", ax5)
    }

    /// A lista de turnos futuros (cenário do contratante com turnos): o grupo de linhas, e o fim da tela com o rodapé.
    private func excluirContaComTurnos(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "painel-contratante"], ax5: ax5)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer))
        conta.tap()
        let abrir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(abrir.waitForExistence(timeout: Espera.aparecer))
        rolarAte(abrir, app)
        abrir.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].waitForExistence(timeout: Espera.aparecer))
        capturar("r1-excluir-conta-turnos-0", ax5)
        let turno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(turno.waitForExistence(timeout: Espera.aparecer))
        for passo in 1...3 {
            app.swipeUp()
            capturar("r1-excluir-conta-turnos-\(passo)", ax5)
        }
    }

    func testExcluirContaComTurnosNoTamanhoPadrao() { excluirContaComTurnos(ax5: false) }
    func testExcluirContaComTurnosEmAX5() { excluirContaComTurnos(ax5: true) }
    func testEntradaNoTamanhoPadrao() { telaDeEntrada(ax5: false) }
    func testEntradaEmAX5() { telaDeEntrada(ax5: true) }
    func testCodigoNoTamanhoPadrao() { telaDoCodigo(ax5: false) }
    func testCodigoEmAX5() { telaDoCodigo(ax5: true) }
    func testCodigoIncorretoNoTamanhoPadrao() { codigoIncorreto(ax5: false) }
    func testCodigoIncorretoEmAX5() { codigoIncorreto(ax5: true) }
    func testCadastroNoTamanhoPadrao() { telaDeCadastro(ax5: false) }
    func testCadastroEmAX5() { telaDeCadastro(ax5: true) }
    func testAtualizacaoNecessariaNoTamanhoPadrao() { atualizacaoNecessaria(ax5: false) }
    func testAtualizacaoNecessariaEmAX5() { atualizacaoNecessaria(ax5: true) }
    func testContaSuspensaNoTamanhoPadrao() { contaSuspensa(ax5: false) }
    func testContaSuspensaEmAX5() { contaSuspensa(ax5: true) }
    func testExcluirContaNoTamanhoPadrao() { excluirConta(ax5: false) }
    func testExcluirContaEmAX5() { excluirConta(ax5: true) }
}
