import UIKit
import XCTest

@MainActor
final class SuporteTurnoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFolhaDeSuporteExibePrazoMotivosESeguranca() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_SUPORTE_TURNO", "-FRILA_SCENARIO", "success", "-FRILA_CACHE_VAZIO_UI_TEST"]
        app.launch()

        // 1. A folha de suporte abre e exibe o título
        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10), "A folha de suporte no turno deve estar visível")

        // 2. O aviso de prazo de até 5 dias úteis deve estar visível (Critério 2)
        let avisoPrazo = app.descendants(matching: .any)["aviso-prazo-suporte"]
        XCTAssertTrue(avisoPrazo.waitForExistence(timeout: Espera.aparecer), "O aviso de prazo de 5 dias úteis deve estar visível")
        XCTAssertTrue(avisoPrazo.label.contains("Respondemos em até 5 dias úteis"), "Deve explicitar o prazo de 5 dias úteis")

        // 3. Seleção de motivo de risco de segurança exibe aviso imediato e atalhos 190 e 180 (Critério 3)
        let opcaoRisco = app.descendants(matching: .any)["opcao-motivo-risco_seguranca"]
        XCTAssertTrue(opcaoRisco.waitForExistence(timeout: Espera.aparecer), "Opção de risco à segurança deve estar disponível")
        opcaoRisco.tap()

        let avisoSeguranca = app.descendants(matching: .any)["aviso-seguranca-suporte"]
        XCTAssertTrue(avisoSeguranca.waitForExistence(timeout: Espera.aparecer), "Aviso de emergência deve aparecer ao selecionar risco à segurança")

        let botao190 = app.descendants(matching: .any)["botao-ligar-190"]
        XCTAssertTrue(botao190.waitForExistence(timeout: Espera.aparecer), "Botão para ligar 190 deve estar disponível")

        let botao180 = app.descendants(matching: .any)["botao-ligar-180"]
        XCTAssertTrue(botao180.waitForExistence(timeout: Espera.aparecer), "Botão para ligar 180 deve estar disponível")

        // 4. Rola a tela para ver os campos inferiores e botões de ação
        app.swipeUp()

        // 5. Campo de relato opcional aceita texto
        let campoRelato = app.descendants(matching: .any)["campo-relato-suporte"]
        if campoRelato.waitForExistence(timeout: 3) {
            campoRelato.tap()
            campoRelato.typeText("Relato de teste para o suporte.")
        }

        // 6. Botão de envio de e-mail e botão de cópia de dados (Critérios 4 e 5)
        let botaoEnviar = app.descendants(matching: .any)["botao-enviar-email-suporte"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: Espera.aparecer), "Botão para abrir e-mail deve estar presente")

        let botaoCopiar = app.descendants(matching: .any)["botao-copiar-dados-suporte"]
        XCTAssertTrue(botaoCopiar.waitForExistence(timeout: Espera.aparecer), "Botão para copiar dados deve estar presente")
        if !botaoCopiar.isHittable {
            app.swipeUp()
        }
        botaoCopiar.tap()

        let avisoCopiado = app.descendants(matching: .any)["aviso-dados-copiados"]
        XCTAssertTrue(avisoCopiado.waitForExistence(timeout: Espera.aparecer), "Confirmação de cópia dos dados deve ser exibida após o toque")

        // 7. Botão fechar
        let botaoFechar = app.buttons["botao-fechar-suporte"]
        XCTAssertTrue(botaoFechar.waitForExistence(timeout: Espera.aparecer), "Botão de fechar folha deve estar acessível")
    }

    /// Critério 4 do #71: Com Reduzir Movimento ligado, nenhuma animação de deslocamento.
    func testFolhaDeSuporteComReduzirMovimentoNaoAnimaDeslocamento() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_SUPORTE_TURNO",
            "-FRILA_SCENARIO", "success",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-UIAccessibilityReduceMotionEnabled", "YES"
        ]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10), "A folha de suporte deve abrir")
        let iconeSemMovimento = app.descendants(matching: .any)["icone-prazo-sem-movimento"]
        XCTAssertTrue(iconeSemMovimento.waitForExistence(timeout: Espera.aparecer), "A folha deve reconhecer a preferência de Reduzir Movimento")

        let opcaoRisco = app.descendants(matching: .any)["opcao-motivo-risco_seguranca"]
        XCTAssertTrue(opcaoRisco.waitForExistence(timeout: Espera.aparecer))
        opcaoRisco.tap()

        let avisoSeguranca = app.descendants(matching: .any)["aviso-seguranca-suporte"]
        XCTAssertTrue(avisoSeguranca.waitForExistence(timeout: Espera.aparecer), "Aviso de segurança aparece imediatamente sem animação de deslocamento")
    }

    func testBotaoAjudaTurnoEmTurnoDoContratante() {
        let app = XCUIApplication()
        let turnoID = "82000000-0000-0000-0000-000000000001"
        app.launchArguments = ["-FRILA_SCENARIO", "checkin-manual-pendente", "-FRILA_CACHE_VAZIO_UI_TEST"]
        app.launch()

        let acompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 15))
        acompanhar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10))
        app.swipeUp()
        let botaoAjuda = app.descendants(matching: .any)["botao-ajuda-turno"]
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer), "Botão de ajuda no turno deve estar visível no rodapé do contratante")
        botaoAjuda.tap()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: Espera.aparecer), "Folha de suporte deve abrir ao tocar no botão de ajuda")
        app.buttons["botao-fechar-suporte"].tap()
        XCTAssertFalse(folha.exists)
    }

    func testBotaoAjudaTurnoEmMeuTurno() {
        let app = XCUIApplication()
        let turnoID = "22000000-0000-0000-0000-000000000001"
        app.launchArguments = ["-FRILA_SCENARIO", "turno-encerrado", "-FRILA_CACHE_VAZIO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meus turnos"].tap()

        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        cartao.tap()

        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 10))
        let botaoAjuda = app.descendants(matching: .any)["botao-ajuda-turno"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer), "Botão de ajuda no turno deve estar visível no rodapé do profissional")
        botaoAjuda.tap()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: Espera.aparecer), "Folha de suporte deve abrir ao tocar no botão de ajuda")
        app.buttons["botao-fechar-suporte"].tap()
        XCTAssertFalse(folha.exists)
    }

    /// Subtítulos de seção da folha de suporte possuem traço de cabeçalho para navegação por seção no VoiceOver (71.1).
    func testSubtitulosDeSecaoDaFolhaDeSuporteSaoCabecalhos() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_SUPORTE_TURNO", "-FRILA_SCENARIO", "success", "-FRILA_CACHE_VAZIO_UI_TEST"]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10), "A folha de suporte no turno deve estar visível")

        // 1. Subtítulo da seção de motivo
        let subtituloMotivo = app.staticTexts["Motivo do suporte"]
        XCTAssertTrue(subtituloMotivo.waitForExistence(timeout: Espera.aparecer), "O subtítulo de motivo deve estar visível")
        XCTAssertTrue(subtituloMotivo.ehCabecalho, "O subtítulo de motivo deve ser cabeçalho para VoiceOver")

        salvarCapturaDaFolha(app.screenshot(), nome: "folha-suporte-padrao.png")

        // 2. Subtítulo da seção de relato
        let subtituloRelato = app.staticTexts["Descrição do ocorrido"]
        if !subtituloRelato.waitForExistence(timeout: Espera.aparecer) {
            app.swipeUp()
            XCTAssertTrue(subtituloRelato.waitForExistence(timeout: Espera.aparecer), "O subtítulo de relato deve estar visível")
        }
        XCTAssertTrue(subtituloRelato.ehCabecalho, "O subtítulo de relato deve ser cabeçalho para VoiceOver")

        // 3. Subtítulo da seção de dados do turno
        let subtituloDados = app.staticTexts["Identificação do turno"]
        if !subtituloDados.waitForExistence(timeout: Espera.aparecer) {
            app.swipeUp()
            XCTAssertTrue(subtituloDados.waitForExistence(timeout: Espera.aparecer), "O subtítulo de dados do turno deve estar visível")
        }
        XCTAssertTrue(subtituloDados.ehCabecalho, "O subtítulo de dados do turno deve ser cabeçalho para VoiceOver")
    }

    /// Captura da folha de suporte em tamanho de acessibilidade (AX5) para conferência de layout e texto cortado (71.1).
    func testFolhaDeSuporteEmAX5() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_SUPORTE_TURNO",
            "-FRILA_SCENARIO", "success",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10), "A folha de suporte deve abrir em AX5")

        // 1. Subtítulo da seção de motivo
        let subtituloMotivo = app.staticTexts["Motivo do suporte"]
        XCTAssertTrue(subtituloMotivo.waitForExistence(timeout: Espera.aparecer), "O subtítulo de motivo deve estar visível em AX5")
        XCTAssertTrue(subtituloMotivo.ehCabecalho, "O subtítulo de motivo deve ser cabeçalho em AX5")

        salvarCapturaDaFolha(app.screenshot(), nome: "folha-suporte-ax5.png")

        // 2. Subtítulo da seção de relato
        let subtituloRelato = app.staticTexts["Descrição do ocorrido"]
        if !subtituloRelato.waitForExistence(timeout: Espera.aparecer) {
            app.swipeUp()
            XCTAssertTrue(subtituloRelato.waitForExistence(timeout: Espera.aparecer), "O subtítulo de relato deve estar visível em AX5")
        }
        XCTAssertTrue(subtituloRelato.ehCabecalho, "O subtítulo de relato deve ser cabeçalho em AX5")

        // 3. Subtítulo da seção de dados do turno
        let subtituloDados = app.staticTexts["Identificação do turno"]
        if !subtituloDados.waitForExistence(timeout: Espera.aparecer) {
            app.swipeUp()
            XCTAssertTrue(subtituloDados.waitForExistence(timeout: Espera.aparecer), "O subtítulo de dados do turno deve estar visível em AX5")
        }
        XCTAssertTrue(subtituloDados.ehCabecalho, "O subtítulo de dados do turno deve ser cabeçalho em AX5")
    }

    private func salvarCapturaDaFolha(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        let pasta = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/missoes/capturas/2026-10-09-cabecalhos-suporte"
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome)"))
    }
}

private extension XCUIElement {
    var ehCabecalho: Bool {
        let traits = (value(forKey: "traits") as? NSNumber)?.uint64Value ?? (value(forKey: "traits") as? UInt64) ?? 0
        return (traits & UIAccessibilityTraits.header.rawValue) != 0
    }
}
