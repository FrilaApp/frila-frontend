import XCTest

/// A equipe da casa, o convite por link e a troca de casa (contratos 0.2.73 e 0.2.103), contra o dublê em memória: o caminho feliz
/// do administrador, a Conta de quem é só operador e as capturas no tamanho padrão e em AX5. `FRILA_CAPTURAS_DIR` (opcional)
/// grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class EquipeDaCasaUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    // Os ids do dublê (`ApiClienteEmMemoria`): a casa e as pessoas da equipe.
    private static let voce = "93000000-0000-0000-0000-000000000001"
    private static let renata = "93000000-0000-0000-0000-000000000002"
    private static let marina = "93000000-0000-0000-0000-000000000003"
    private static let paulo = "93000000-0000-0000-0000-000000000004"
    private static let cantina = "30000000-0000-0000-0000-000000000002"
    /// O convite de exemplo do cenário, montado na hora: nenhum código de convite no repositório.
    private static let conviteDeExemplo = String(repeating: "ef", count: 32)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Ajudantes

    private func abrir(cenario: String = "equipe-da-casa", ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST", "-FRILA_MODO_CLARO",
                               "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Abre a Conta e espera as linhas da casa carregarem.
    private func abrirConta(_ app: XCUIApplication) {
        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: 15), "Minhas vagas deve abrir")
        tocar(app.tabBars.buttons["Conta"])
        XCTAssertTrue(elemento("conta-tenho-um-convite", em: app).waitForExistence(timeout: Espera.aparecer), "As linhas da casa devem aparecer na Conta")
    }

    /// Rola até o elemento ficar inteiro na tela, entre a barra e a base.
    private func trazer(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<14 {
            let quadro = elemento.frame
            if elemento.exists, quadro.minY > 130, quadro.maxY < janela.height - 150 { return }
            if elemento.exists, quadro.minY <= 130 { app.swipeDown(velocity: .slow) } else { app.swipeUp(velocity: .slow) }
        }
    }

    /// Rola até o topo do elemento aparecer na metade de cima da tela (um cartão alto em AX5 nunca cabe inteiro).
    private func rolarAteOTopo(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<10 where !(elemento.exists && elemento.frame.minY < janela.height * 0.45 && elemento.frame.minY > 100) {
            app.swipeUp(velocity: .slow)
        }
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let nomeCompleto = "equipe-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeCompleto
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeCompleto).png"))
        }
    }

    private func voltar(_ app: XCUIApplication) {
        tocar(app.navigationBars.buttons.element(boundBy: 0))
    }

    private func abrirEquipe(_ app: XCUIApplication) {
        tocar(elemento("conta-equipe-da-casa", em: app))
        XCTAssertTrue(elemento("equipe-membro-93000000-0000-0000-0000-000000000001", em: app).waitForExistence(timeout: Espera.aparecer), "A lista da equipe deve carregar")
    }

    private func gerarConvite(_ app: XCUIApplication, para email: String) {
        let campo = app.textFields["equipe-email"]
        trazer(campo, em: app)
        substituirTexto(campo, por: email)
        fecharTeclado(app)
        let gerar = app.buttons["equipe-gerar-convite"]
        trazer(gerar, em: app)
        tocar(gerar)
        XCTAssertTrue(elemento("equipe-convite-pronto", em: app).waitForExistence(timeout: Espera.aparecer), "O convite deve aparecer")
    }

    // MARK: Caminho feliz do administrador

    func testAdministradorGerenciaAEquipeETrocaDeCasa() {
        let app = abrir()
        abrirConta(app)

        // A Conta oferece a equipe (é administradora), a troca (são duas casas) e o convite.
        XCTAssertTrue(elemento("conta-equipe-da-casa", em: app).exists)
        XCTAssertTrue(elemento("conta-trocar-de-casa", em: app).exists)
        capturar("conta", ax5: false)

        // A equipe: as quatro pessoas, o "você" sem ação, os demais com Remover.
        abrirEquipe(app)
        for id in [Self.voce, Self.renata, Self.marina, Self.paulo] {
            XCTAssertTrue(elemento("equipe-membro-\(id)", em: app).exists, "a pessoa \(id) deve estar na lista")
        }
        XCTAssertFalse(elemento("equipe-remover-\(Self.voce)", em: app).exists, "\"Você\" não tem Remover")
        XCTAssertFalse(elemento("equipe-transferir-\(Self.voce)", em: app).exists, "\"Você\" não tem Tornar administrador")
        XCTAssertTrue(elemento("equipe-remover-\(Self.renata)", em: app).exists)
        XCTAssertFalse(elemento("equipe-transferir-\(Self.renata)", em: app).exists, "quem já é administrador não é promovido de novo")
        XCTAssertTrue(elemento("equipe-transferir-\(Self.marina)", em: app).exists)
        capturar("lista", ax5: false)

        // O convite: o link é o da web de dev (o app do esquema Local), com o token no fragmento, e a folha de compartilhar.
        gerarConvite(app, para: "convidada@exemplo.com")
        let link = elemento("equipe-convite-link", em: app)
        XCTAssertTrue(link.exists)
        XCTAssertTrue(("\(link.label) \(link.value ?? "")").contains("https://frila-web-dev.frilabr.workers.dev/app/convite#"), "o link segue o ambiente do app")
        XCTAssertTrue(elemento("equipe-compartilhar-convite", em: app).exists, "o convite sai pela folha de compartilhar do sistema")
        capturar("convite-gerado", ax5: false)

        // Remover Marina: pede confirmação, e depois ela sai da lista.
        let remover = app.buttons["equipe-remover-\(Self.marina)"]
        trazer(remover, em: app)
        tocar(remover)
        XCTAssertTrue(elemento("equipe-confirmar", em: app).waitForExistence(timeout: Espera.aparecer), "A confirmação deve abrir")
        capturar("confirmacao", ax5: false)
        tocar(app.buttons["equipe-confirmar"])
        XCTAssertTrue(elemento("equipe-mensagem", em: app).waitForExistence(timeout: Espera.aparecer), "O aviso da remoção deve aparecer")
        XCTAssertFalse(elemento("equipe-membro-\(Self.marina)", em: app).waitForExistence(timeout: 2), "Marina deve sair da lista")

        // Tornar Paulo administrador: ele deixa de ter a ação, porque já é administrador.
        let transferir = app.buttons["equipe-transferir-\(Self.paulo)"]
        trazer(transferir, em: app)
        tocar(transferir)
        XCTAssertTrue(elemento("equipe-confirmar", em: app).waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["equipe-confirmar"])
        let semAcao = NSPredicate(format: "exists == false")
        let some = XCTNSPredicateExpectation(predicate: semAcao, object: app.buttons["equipe-transferir-\(Self.paulo)"])
        XCTAssertEqual(XCTWaiter.wait(for: [some], timeout: Espera.aparecer), .completed, "Paulo já é administrador")

        // Trocar de casa: a Cantina da Esquina, onde a conta é só operadora, perde a equipe.
        voltar(app)
        tocar(elemento("conta-trocar-de-casa", em: app))
        XCTAssertTrue(elemento("trocar-casa-30000000-0000-0000-0000-000000000001", em: app).waitForExistence(timeout: Espera.aparecer))
        capturar("trocar-de-casa", ax5: false)
        tocar(elemento("trocar-casa-\(Self.cantina)", em: app))
        XCTAssertTrue(app.staticTexts["Cantina da Esquina"].waitForExistence(timeout: Espera.aparecer), "O perfil deve mostrar a casa escolhida")
        XCTAssertTrue(elemento("conta-trocar-de-casa", em: app).exists)
        XCTAssertFalse(elemento("conta-equipe-da-casa", em: app).exists, "operadora não vê a equipe")
    }

    func testTenhoUmConviteRecusaTextoInvalidoEEntraNaCasa() {
        let app = abrir()
        abrirConta(app)
        tocar(elemento("conta-tenho-um-convite", em: app))
        XCTAssertTrue(elemento("convite-campo", em: app).waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["Cole aqui o link do convite que você recebeu."].exists, "a explicação é uma frase só")
        capturar("tenho-um-convite", ax5: false)

        // Texto que não é link nem código: a recusa é local, junto ao botão.
        substituirTexto(app.textFields["convite-campo"], por: "oi, tudo bem?")
        fecharTeclado(app)
        tocar(app.buttons["convite-aceitar"])
        XCTAssertTrue(elemento("convite-erro", em: app).waitForExistence(timeout: Espera.aparecer), "link ou código inválido")
        capturar("tenho-um-convite-invalido", ax5: false)

        // O link inteiro do convite entra na casa; "Abrir a casa" leva a pessoa para ela.
        substituirTexto(app.textFields["convite-campo"], por: "https://frila-web-dev.frilabr.workers.dev/app/convite#\(Self.conviteDeExemplo)")
        fecharTeclado(app)
        tocar(app.buttons["convite-aceitar"])
        XCTAssertTrue(elemento("convite-aceito", em: app).waitForExistence(timeout: Espera.aparecer), "O convite deve ser aceito")
        capturar("convite-aceito", ax5: false)
        tocar(app.buttons["convite-abrir-casa"])
        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: Espera.aparecer), "A casa nova abre em Minhas vagas")
    }

    // MARK: Quem é só operador

    func testOperadorNaoVeAEquipeNemATroca() {
        let app = abrir(cenario: "equipe-da-casa-operador")
        abrirConta(app)

        XCTAssertFalse(elemento("conta-equipe-da-casa", em: app).exists, "operador não vê a equipe da casa")
        XCTAssertFalse(elemento("conta-trocar-de-casa", em: app).exists, "uma casa só: sem troca")
        XCTAssertTrue(elemento("conta-tenho-um-convite", em: app).exists, "o convite vale para toda conta de contratante")
        capturar("conta-operador", ax5: false)
    }

    // MARK: AX5

    /// As telas novas em AX5: o texto cresce e a tela rola, sem cortar nem alargar além da largura.
    func testTelasEmAX5() {
        let app = abrir(ax5: true)
        abrirConta(app)
        capturar("conta", ax5: true)
        // Em AX5 o topo da Conta não mostra as entradas da casa: rola até elas para a captura ver margem e fios.
        rolarAteOTopo(elemento("conta-equipe-da-casa", em: app), em: app)
        capturar("conta-entradas", ax5: true)

        abrirEquipe(app)
        capturar("lista", ax5: true)
        gerarConvite(app, para: "convidada@exemplo.com")
        rolarAteOTopo(elemento("equipe-convite-pronto", em: app), em: app)
        capturar("convite-gerado", ax5: true)
        let remover = app.buttons["equipe-remover-\(Self.marina)"]
        trazer(remover, em: app)
        tocar(remover)
        XCTAssertTrue(elemento("equipe-confirmar", em: app).waitForExistence(timeout: Espera.aparecer))
        capturar("confirmacao", ax5: true)
        tocar(app.buttons["equipe-confirmar-cancelar"])
        voltar(app)

        tocar(elemento("conta-trocar-de-casa", em: app))
        XCTAssertTrue(elemento("trocar-casa-30000000-0000-0000-0000-000000000001", em: app).waitForExistence(timeout: Espera.aparecer))
        capturar("trocar-de-casa", ax5: true)
        voltar(app)

        tocar(elemento("conta-tenho-um-convite", em: app))
        XCTAssertTrue(elemento("convite-campo", em: app).waitForExistence(timeout: Espera.aparecer))
        capturar("tenho-um-convite", ax5: true)
        substituirTexto(app.textFields["convite-campo"], por: "oi")
        fecharTeclado(app)
        tocar(app.buttons["convite-aceitar"])
        XCTAssertTrue(elemento("convite-erro", em: app).waitForExistence(timeout: Espera.aparecer))
        capturar("tenho-um-convite-invalido", ax5: true)
    }
}
