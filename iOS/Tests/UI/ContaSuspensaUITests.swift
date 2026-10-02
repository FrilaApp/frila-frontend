import XCTest

@MainActor
final class ContaSuspensaUITests: XCTestCase {

    func testContaSuspensaNaoChegaAsTelasNormaisEMostraMotivo() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "conta-suspensa"]
        app.launch()

        // 1. A tela de conta suspensa abre diretamente (Critério 1)
        let telaSuspensa = app.descendants(matching: .any)["tela-conta-suspensa"]
        XCTAssertTrue(telaSuspensa.waitForExistence(timeout: 10), "A tela de conta suspensa deve abrir diretamente")

        let aviso = app.descendants(matching: .any)["aviso-conta-suspensa"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "Aviso de conta suspensa deve estar visível")

        let motivo = app.descendants(matching: .any)["texto-motivo-suspensao"]
        XCTAssertTrue(motivo.waitForExistence(timeout: 5), "Motivo da suspensão deve estar visível")

        // 2. O resto do app não abre (as telas normais ficam inacessíveis)
        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertFalse(botaoPerfil.exists, "Telas normais não devem ser acessadas por conta suspensa")

        let botaoMinhasVagas = app.buttons["minhas-vagas"]
        XCTAssertFalse(botaoMinhasVagas.exists, "Telas normais do contratante não devem ser acessadas")

        // 3. Ações secundárias que continuam disponíveis (RF24, RN13)
        let botaoExportar = app.buttons["conta-suspensa-exportar-dados"]
        XCTAssertTrue(botaoExportar.waitForExistence(timeout: 5), "Botão de exportar dados deve estar presente")
        XCTAssertFalse(botaoExportar.isEnabled, "Exportação deve estar desabilitada com aviso de pendência no cartão #219")

        let botaoExcluir = app.buttons["conta-suspensa-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: 5), "Opção de excluir conta deve estar disponível")

        let botaoSair = app.buttons["conta-suspensa-sair"]
        XCTAssertTrue(botaoSair.waitForExistence(timeout: 5), "Opção de sair deve estar disponível")
    }

    func testContestacaoEnviadaMostraProtocoloESegundaTentativaBloqueada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "conta-suspensa"]
        app.launch()

        let telaSuspensa = app.descendants(matching: .any)["tela-conta-suspensa"]
        XCTAssertTrue(telaSuspensa.waitForExistence(timeout: 10))

        // 1. Toca no botão para abrir formulário de contestação
        let botaoContestar = app.buttons["botao-contestar-suspensao"]
        XCTAssertTrue(botaoContestar.waitForExistence(timeout: 5))
        botaoContestar.tap()

        // 2. Preenche o relato com pelo menos 10 caracteres válidos
        let campoRelato = app.descendants(matching: .any)["campo-relato-contestacao"].firstMatch
        XCTAssertTrue(campoRelato.waitForExistence(timeout: 5))
        campoRelato.tap()
        campoRelato.typeText("Contestação com motivos fundamentados pela parte")

        // 3. Envia a contestação
        let botaoEnviar = app.buttons["botao-enviar-contestacao"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: 5))
        botaoEnviar.tap()

        // 4. Protocolo e estado "em análise" são exibidos (Critério 2)
        let statusAnalise = app.descendants(matching: .any)["status-em-analise"]
        XCTAssertTrue(statusAnalise.waitForExistence(timeout: 5), "Estado em análise deve aparecer após envio")

        let protocolo = app.descendants(matching: .any)["protocolo-contestacao"]
        XCTAssertTrue(protocolo.waitForExistence(timeout: 5), "Número do protocolo deve ser exibido")

        let prazo = app.descendants(matching: .any)["prazo-resposta-contestacao"]
        XCTAssertTrue(prazo.waitForExistence(timeout: 5), "Prazo de resposta deve ser exibido")

        // 5. Segunda tentativa de contestação é bloqueada (botão de contestar não está disponível)
        XCTAssertFalse(app.buttons["botao-contestar-suspensao"].exists, "Segunda contestação não deve estar disponível")
        XCTAssertFalse(app.descendants(matching: .any)["campo-relato-contestacao"].exists, "Formulário não deve estar aberto")
    }
}
