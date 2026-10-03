import XCTest

@MainActor
final class SuporteTurnoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFolhaDeSuporteExibePrazoMotivosESeguranca() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_SUPORTE_TURNO", "-FRILA_SCENARIO", "success"]
        app.launch()

        // 1. A folha de suporte abre e exibe o título
        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10), "A folha de suporte no turno deve estar visível")

        // 2. O aviso de prazo de até 5 dias úteis deve estar visível (Critério 2)
        let avisoPrazo = app.descendants(matching: .any)["aviso-prazo-suporte"]
        XCTAssertTrue(avisoPrazo.waitForExistence(timeout: 5), "O aviso de prazo de 5 dias úteis deve estar visível")
        XCTAssertTrue(avisoPrazo.label.contains("Respondemos em até 5 dias úteis"), "Deve explicitar o prazo de 5 dias úteis")

        // 3. Seleção de motivo de risco de segurança exibe aviso imediato e atalhos 190 e 180 (Critério 3)
        let opcaoRisco = app.descendants(matching: .any)["opcao-motivo-risco_seguranca"]
        XCTAssertTrue(opcaoRisco.waitForExistence(timeout: 5), "Opção de risco à segurança deve estar disponível")
        opcaoRisco.tap()

        let avisoSeguranca = app.descendants(matching: .any)["aviso-seguranca-suporte"]
        if !avisoSeguranca.waitForExistence(timeout: 5) {
            print("DEBUG HIERARCHY: \(app.debugDescription)")
        }
        XCTAssertTrue(avisoSeguranca.exists, "Aviso de emergência deve aparecer ao selecionar risco à segurança")

        let botao190 = app.descendants(matching: .any)["botao-ligar-190"]
        XCTAssertTrue(botao190.waitForExistence(timeout: 5), "Botão para ligar 190 deve estar disponível")

        let botao180 = app.descendants(matching: .any)["botao-ligar-180"]
        XCTAssertTrue(botao180.waitForExistence(timeout: 5), "Botão para ligar 180 deve estar disponível")

        // 4. Rola a tela para ver os campos inferiores e botões de ação
        app.swipeUp()

        // 5. Campo de relato opcional aceita texto
        let campoRelato = app.textViews["campo-relato-suporte"]
        if campoRelato.waitForExistence(timeout: 3) {
            campoRelato.tap()
            campoRelato.typeText("Relato de teste para o suporte.")
        }

        // 6. Botão de envio de e-mail e botão de cópia de dados (Critérios 4 e 5)
        let botaoEnviar = app.descendants(matching: .any)["botao-enviar-email-suporte"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: 5), "Botão para abrir e-mail deve estar presente")

        let botaoCopiar = app.descendants(matching: .any)["botao-copiar-dados-suporte"]
        XCTAssertTrue(botaoCopiar.waitForExistence(timeout: 5), "Botão para copiar dados deve estar presente")
        botaoCopiar.tap()

        let avisoCopiado = app.descendants(matching: .any)["aviso-dados-copiados"]
        XCTAssertTrue(avisoCopiado.waitForExistence(timeout: 5), "Confirmação de cópia dos dados deve ser exibida após o toque")

        // 7. Botão fechar
        let botaoFechar = app.buttons["botao-fechar-suporte"]
        XCTAssertTrue(botaoFechar.waitForExistence(timeout: 5), "Botão de fechar folha deve estar acessível")
    }
}
