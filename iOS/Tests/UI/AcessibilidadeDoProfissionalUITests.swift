import XCTest
import UIKit

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
        XCTAssertGreaterThanOrEqual(maiorIdade.frame.width, 44)
        XCTAssertGreaterThanOrEqual(maiorIdade.frame.height, 44)
        XCTAssertTrue(maiorIdade.isHittable)

        let termos = app.buttons["cadastro-termos"]
        XCTAssertTrue(termos.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(termos.frame.width, 44)
        XCTAssertGreaterThanOrEqual(termos.frame.height, 44)
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
        XCTAssertGreaterThanOrEqual(filtroFuncao.frame.height, 44)

        let filtroData = app.descendants(matching: .any)["filtro-data"]
        XCTAssertTrue(filtroData.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(filtroData.frame.height, 44)

        let filtroDistancia = app.descendants(matching: .any)["filtro-distancia"]
        XCTAssertTrue(filtroDistancia.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(filtroDistancia.frame.height, 44)

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
        XCTAssertGreaterThanOrEqual(denunciar.frame.height, 44)

        let bloquear = app.buttons["bloquear"]
        XCTAssertTrue(bloquear.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(bloquear.frame.height, 44)

        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(candidatar.frame.height, 44)
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
        XCTAssertGreaterThanOrEqual(pickerDia.frame.height, 44)

        let botaoAdicionar = app.buttons["botao-adicionar-janela"]
        XCTAssertTrue(botaoAdicionar.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(botaoAdicionar.frame.height, 44)

        let remover = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'remover-janela-'")).firstMatch
        if remover.waitForExistence(timeout: 5) {
            XCTAssertGreaterThanOrEqual(remover.frame.width, 44)
            XCTAssertGreaterThanOrEqual(remover.frame.height, 44)
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
        XCTAssertGreaterThanOrEqual(contato.frame.height, 44)
    }

    // MARK: - 7. Meu turno: WhatsApp, Avaliar turno e Ver avaliação (#20, QA do Loki)

    /// O alvo de 44 pt fica dentro do `Link`/`NavigationLink`: antes, o frame ficava por fora e só o
    /// texto (20 pt) recebia o toque. Os cartões contêm os filhos sem encobrir seus identificadores.
    func testMeuTurnoLinksTemAlvoMinimo() {
        let turnoID = "22000000-0000-0000-0000-000000000001"
        for (cenario, botoes) in [("turno-encerrado", ["botao-whatsapp", "botao-abrir-avaliacao"]), ("turno-avaliado", ["botao-ver-avaliacao"])] {
            let app = XCUIApplication()
            app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST"]
            app.launch()
            XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
            app.tabBars.buttons["Meus turnos"].tap()
            let cartao = app.buttons["meu-turno-\(turnoID)"]
            XCTAssertTrue(cartao.waitForExistence(timeout: 10))
            cartao.tap()
            XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
            for identificador in botoes {
                let botao = app.buttons[identificador].firstMatch
                XCTAssertTrue(botao.waitForExistence(timeout: 10), "\(cenario): \(identificador)")
                XCTAssertGreaterThanOrEqual(botao.frame.height, 44, "\(cenario): \(identificador) tem \(botao.frame.height) pt")
            }
            app.terminate()
        }
    }

    private func abrirTurnoCancelado(tamanho: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado", "-FRILA_CACHE_VAZIO_UI_TEST"]
        if let tamanho { app.launchArguments += ["-UIPreferredContentSizeCategoryName", tamanho] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Meus turnos"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meus turnos"].tap()
        let cartao = app.buttons["meu-turno-22000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        cartao.tap()
        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
        return app
    }

    func testMapaDoTurnoCanceladoExisteEPodeSerAcionado() {
        let app = abrirTurnoCancelado()
        defer { app.terminate() }
        let mapa = app.buttons["atalho-mapas"]
        guard mapa.waitForExistence(timeout: 5) else {
            XCTFail("o link do mapa precisa estar na árvore de acessibilidade")
            return
        }
        XCTAssertTrue(mapa.isHittable)
        XCTAssertGreaterThanOrEqual(mapa.frame.width, 44)
        XCTAssertGreaterThanOrEqual(mapa.frame.height, 44)
        mapa.tap()
        let mapas = XCUIApplication(bundleIdentifier: "com.apple.Maps")
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(mapas.wait(for: .runningForeground, timeout: 10) || safari.wait(for: .runningForeground, timeout: 5), "o toque abre o destino do link")
    }

    func testEnderecoEQuemRecebeDoTurnoCanceladoNaoCortamEmAX5() {
        let app = abrirTurnoCancelado(tamanho: Self.ax5)
        defer { app.terminate() }
        let endereco = app.staticTexts["endereco-do-turno"]
        let quemRecebe = app.staticTexts["quem-recebe-no-turno"]
        let mapa = app.buttons["atalho-mapas"]
        XCTAssertTrue(endereco.waitForExistence(timeout: 5))
        XCTAssertTrue(quemRecebe.waitForExistence(timeout: 5))
        XCTAssertTrue(mapa.waitForExistence(timeout: 5))
        // No tamanho máximo, quem recebe fica abaixo do endereço e do link.
        XCTAssertGreaterThanOrEqual(quemRecebe.frame.minY, mapa.frame.maxY)
        let largura = app.windows.firstMatch.frame.width
        let fonte = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        for texto in [endereco, quemRecebe] {
            XCTAssertGreaterThanOrEqual(texto.frame.minX, 0)
            XCTAssertLessThanOrEqual(texto.frame.maxX, largura)
            let medida = UILabel()
            medida.font = fonte
            medida.text = texto.label
            medida.numberOfLines = 0
            let altura = medida.sizeThatFits(CGSize(width: texto.frame.width, height: .greatestFiniteMagnitude)).height
            XCTAssertGreaterThanOrEqual(texto.frame.height, altura - 2, "todo o texto tem espaço para suas linhas")
        }
        // O título do turno ocupa a primeira dobra no SE em AX5: registra os textos verificados.
        for _ in 0..<6 where quemRecebe.frame.maxY > app.tabBars.firstMatch.frame.minY {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(endereco.isHittable)
        XCTAssertTrue(quemRecebe.isHittable)
        XCTAssertTrue(mapa.isHittable)
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "turno-cancelado-AX5"
        captura.lifetime = .keepAlways
        add(captura)
    }

}
