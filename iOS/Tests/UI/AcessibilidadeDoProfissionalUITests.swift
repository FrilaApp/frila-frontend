import XCTest

/// Testes de interface para os achados de acessibilidade corrigidos na entrada e no profissional (#139).
/// Cada controle possui alvo mínimo de 44x44 pt no tamanho padrão; em XXXL, cartão de vaga e filtros
/// permanecem tocáveis e dentro da largura da tela.
@MainActor
final class AcessibilidadeDoProfissionalUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    // MARK: - 1. Entrada e Cadastro

    func testEntradaECadastroAlvosERotulos() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        // 1. TelaEntrada: rotulo do email deve ser "E-mail"
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertEqual(email.label, "E-mail")
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        app.buttons["entrada-receber-codigo"].tap()

        // 2. TelaCodigo: campo de codigo
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        // 3. TelaCadastro: checkboxes com alvos >= 44x44 pt
        let maiorIdade = app.buttons["cadastro-maior-de-idade"]
        XCTAssertTrue(maiorIdade.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(maiorIdade.frame.width)
        XCTAssertAlvoMinimo(maiorIdade.frame.height)
        XCTAssertTrue(maiorIdade.isHittable)

        let termos = app.buttons["cadastro-termos"]
        XCTAssertTrue(termos.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(termos.frame.width)
        XCTAssertAlvoMinimo(termos.frame.height)
        XCTAssertTrue(termos.isHittable)

        // Alterna opcoes pelo toque
        maiorIdade.tap()
        termos.tap()
        XCTAssertTrue(maiorIdade.isSelected)
        XCTAssertTrue(termos.isSelected)
    }

    // MARK: - 2. Vagas e Filtros (Tamanho Padrão)

    func testVagasEFiltrosAlvosNoTamanhoPadrao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let filtroFuncao = app.descendants(matching: .any)["filtro-funcao"]
        XCTAssertTrue(filtroFuncao.waitForExistence(timeout: 5))
        XCTAssertAlvoMinimo(filtroFuncao.frame.height)

        let filtroData = app.descendants(matching: .any)["filtro-data"]
        XCTAssertTrue(filtroData.waitForExistence(timeout: 5))
        XCTAssertAlvoMinimo(filtroData.frame.height)

        let filtroDistancia = app.descendants(matching: .any)["filtro-distancia"]
        XCTAssertTrue(filtroDistancia.waitForExistence(timeout: 5))
        XCTAssertAlvoMinimo(filtroDistancia.frame.height)

        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        XCTAssertTrue(primeira.isHittable)
    }

    // MARK: - 3. Vagas e Filtros (XXXL)

    func testVagasEFiltrosEmTamanhoXXXL() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", Self.ax5]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let larguraTela = app.windows.firstMatch.frame.width
        let alturaTela = app.windows.firstMatch.frame.height

        let filtroFuncao = app.descendants(matching: .any)["filtro-funcao"]
        XCTAssertTrue(filtroFuncao.waitForExistence(timeout: 10))
        XCTAssertTrue(filtroFuncao.isHittable)
        XCTAssertLessThanOrEqual(filtroFuncao.frame.maxX, larguraTela)

        let filtroData = app.descendants(matching: .any)["filtro-data"]
        XCTAssertTrue(filtroData.waitForExistence(timeout: 10))
        XCTAssertTrue(filtroData.isHittable)
        XCTAssertLessThanOrEqual(filtroData.frame.maxX, larguraTela)

        let filtroDistancia = app.descendants(matching: .any)["filtro-distancia"]
        XCTAssertTrue(filtroDistancia.waitForExistence(timeout: 10))
        XCTAssertTrue(filtroDistancia.isHittable)
        XCTAssertLessThanOrEqual(filtroDistancia.frame.maxX, larguraTela)

        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        XCTAssertTrue(primeira.isHittable, "O cartão da vaga deve continuar tocável em XXXL")
        XCTAssertLessThan(primeira.frame.height, alturaTela, "A altura do cartão não deve exceder a altura da tela")
    }

    // MARK: - 4. Detalhe da Vaga

    func testDetalheDaVagaAlvosEDenunciarBloquear() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()

        let denunciar = app.buttons["denunciar"]
        XCTAssertTrue(denunciar.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(denunciar.frame.height)

        let bloquear = app.buttons["bloquear"]
        XCTAssertTrue(bloquear.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(bloquear.frame.height)

        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(candidatar.frame.height)
    }

    func testDetalheDaVagaEmTamanhoXXXL() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001", "-UIPreferredContentSizeCategoryName", Self.ax5]
        app.launch()

        let candidatar = app.buttons["candidatar"]
        if !candidatar.waitForExistence(timeout: 10) {
            XCTFail("DEBUG: \(app.debugDescription)")
            return
        }
        XCTAssertTrue(candidatar.isHittable, "A ação de candidatar deve ser tocável no rodapé em XXXL")
    }

    // MARK: - 5. Perfil Profissional

    func testPerfilProfissionalAlvosDeDisponibilidadeEAdicao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        let btnPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(btnPerfil.waitForExistence(timeout: 10))
        btnPerfil.tap()

        let btnFuncoes = app.buttons["perfil-funcoes-horarios"]
        XCTAssertTrue(btnFuncoes.waitForExistence(timeout: 10))
        btnFuncoes.tap()

        let pickerDia = app.descendants(matching: .any)["picker-dia-semana"]
        XCTAssertTrue(pickerDia.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(pickerDia.frame.height)

        let botaoAdicionar = app.buttons["botao-adicionar-janela"]
        XCTAssertTrue(botaoAdicionar.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(botaoAdicionar.frame.height)

        let remover = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'remover-janela-'")).firstMatch
        if remover.waitForExistence(timeout: 5) {
            XCTAssertAlvoMinimo(remover.frame.width)
            XCTAssertAlvoMinimo(remover.frame.height)
        }
    }

    // MARK: - 6. Candidatura e Contato do Turno

    func testResultadoCandidaturaContatoDoTurnoAlvoMinimo() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()

        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        candidatar.tap()

        let contato = app.descendants(matching: .any)["contato-do-turno"]
        XCTAssertTrue(contato.waitForExistence(timeout: 10))
        XCTAssertAlvoMinimo(contato.frame.height)
    }

    // MARK: - 7. Meu turno: WhatsApp, Avaliar turno e Ver avaliação (#20, QA do Loki)

    /// O alvo de 44 pt fica dentro do `Link`/`NavigationLink`: antes, o frame ficava por fora e só o
    /// texto (20 pt) recebia o toque. Os botões são achados pelo rótulo: o identificador do cartão
    /// (`contato-do-turno`, `cartao-avaliacao-turno`) se propaga aos filhos e cobre o deles.
    func testMeuTurnoLinksTemAlvoMinimo() {
        let turnoID = "22000000-0000-0000-0000-000000000001"
        for (cenario, botoes) in [("turno-encerrado", ["Abrir no WhatsApp", "Avaliar turno"]), ("turno-avaliado", ["Ver avaliação"])] {
            let app = XCUIApplication()
            app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST"]
            app.launch()
            XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
            app.tabBars.buttons["Meus turnos"].tap()
            let cartao = app.buttons["meu-turno-\(turnoID)"]
            XCTAssertTrue(cartao.waitForExistence(timeout: 10))
            cartao.tap()
            XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
            for rotulo in botoes {
                let botao = app.buttons[rotulo].firstMatch
                XCTAssertTrue(botao.waitForExistence(timeout: 10), "\(cenario): \(rotulo)")
                XCTAssertAlvoMinimo(botao.frame.height, "\(cenario): \(rotulo) tem \(botao.frame.height) pt")
            }
            app.terminate()
        }
    }
}
