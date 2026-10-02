import XCTest

/// O modo seleção do lado de quem trabalha (#10), no dublê: a candidatura fica enviada, com
/// Retirar candidatura; as pendentes ficam na aba Candidaturas; e quem foi escolhido, recusado ou
/// esperava quando a seleção fechou vê o que aconteceu, inclusive pelo toque no push. A vaga é a
/// de `vaga.json`, e a candidatura dos cenários `candidatura-*` é a de `candidatura-selecao.json`.
@MainActor
final class ModoSelecaoDoProfissionalUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let candidaturaID = "6F1C2A4E-2B7D-4C5E-9A1F-3D2E1C0B9A88"
    /// O turno do cenário `candidatura-escolhida`.
    private let turnoID = "84000000-0000-0000-0000-000000000001"

    override func setUp() {
        continueAfterFailure = false
    }

    private func abrir(_ cenario: String, extras: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + extras
        app.launch()
        return app
    }

    /// O toque num push, pelo roteador único do #8.
    private func abrir(_ cenario: String, push tipo: String, id: String) -> XCUIApplication {
        abrir(cenario, extras: ["-FRILA_PUSH", tipo, "-FRILA_PUSH_ID", id])
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Toca em Retirar candidatura e responde ao alerta com o botão pedido.
    private func retirar(em app: XCUIApplication, responder resposta: String) {
        let retirar = app.buttons["retirar-candidatura"]
        XCTAssertTrue(retirar.waitForExistence(timeout: 10))
        retirar.tap()
        let pergunta = app.alerts["Retirar a candidatura?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        XCTAssertTrue(pergunta.staticTexts["Você deixa de concorrer a esta vaga. Enquanto ela aceitar candidaturas, dá para se candidatar de novo."].exists)
        pergunta.buttons[resposta].tap()
    }

    // MARK: Candidatura enviada e retirada

    func testCandidatarEmVagaDeSelecaoMostraCandidaturaEnviadaEDeixaRetirar() {
        let app = abrir("vaga-em-selecao")

        let vaga = app.buttons["vaga-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        vaga.tap()
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Seleção"].exists, "o detalhe diz que a vaga é de seleção")
        candidatar.tap()

        // Pendente: a tela diz que a candidatura foi enviada, e não que a pessoa está confirmada.
        let enviada = elemento("candidatura-enviada", em: app)
        XCTAssertTrue(enviada.waitForExistence(timeout: 10))
        XCTAssertTrue(enviada.label.contains("Candidatura enviada"), enviada.label)
        XCTAssertTrue(enviada.label.contains("O estabelecimento escolhe entre os candidatos"), enviada.label)
        XCTAssertFalse(elemento("resultado-confirmada", em: app).exists)
        XCTAssertFalse(elemento("contato-do-turno", em: app).exists, "sem escolha não há contato (RN10)")

        // Retirar pede confirmação: Cancelar não retira nada.
        retirar(em: app, responder: "Cancelar")
        XCTAssertTrue(enviada.waitForExistence(timeout: 5))
        XCTAssertFalse(elemento("candidatura-retirada", em: app).exists)

        retirar(em: app, responder: "Retirar")
        let retirada = elemento("candidatura-retirada", em: app)
        XCTAssertTrue(retirada.waitForExistence(timeout: 10))
        XCTAssertTrue(retirada.label.contains("Candidatura retirada"), retirada.label)
        XCTAssertFalse(app.buttons["retirar-candidatura"].exists)

        // A candidatura retirada continua na aba Candidaturas, entre as anteriores.
        app.buttons["ver-minhas-candidaturas"].tap()
        XCTAssertTrue(elemento("tela-minhas-candidaturas", em: app).waitForExistence(timeout: 10))
        let retiradaNaLista = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'candidatura-'")).firstMatch
        XCTAssertTrue(retiradaNaLista.waitForExistence(timeout: 10))
        XCTAssertTrue(retiradaNaLista.label.contains("Você retirou a candidatura"), retiradaNaLista.label)
        XCTAssertFalse(app.staticTexts["Aguardando resposta"].exists)
    }

    func testCandidaturaPendenteFicaNaAbaCandidaturasEODetalheDeixaRetirar() {
        let app = abrir("candidatura-pendente")

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        XCTAssertTrue(app.staticTexts["Aguardando resposta"].waitForExistence(timeout: 10))
        let pendente = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(pendente.waitForExistence(timeout: 5))
        XCTAssertTrue(pendente.label.contains("Aguardando a escolha do estabelecimento"), pendente.label)

        // O toque leva à vaga: no lugar de Candidatar-me, a candidatura enviada com a retirada.
        pendente.tap()
        XCTAssertTrue(elemento("tela-detalhe-vaga", em: app).waitForExistence(timeout: 10))
        XCTAssertTrue(elemento("candidatura-enviada", em: app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["candidatar"].exists)

        retirar(em: app, responder: "Retirar")

        // Retirada, a vaga volta a aceitar a candidatura da pessoa.
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertTrue(elemento("candidatura-retirada", em: app).exists)
        XCTAssertFalse(app.buttons["retirar-candidatura"].exists)

        aba.tap()
        XCTAssertTrue(pendente.waitForExistence(timeout: 10))
        XCTAssertTrue(pendente.label.contains("Você retirou a candidatura"), pendente.label)
    }

    func testRetirarSemConexaoAvisaENaoTiraOBotao() {
        // O aviso de vaga abre o detalhe da vaga em que a conta já tem candidatura pendente.
        let app = abrir("retirar-sem-rede", push: "vaga", id: vagaID)
        XCTAssertTrue(elemento("candidatura-enviada", em: app).waitForExistence(timeout: 15))

        retirar(em: app, responder: "Retirar")

        let falha = elemento("retirada-falha", em: app)
        XCTAssertTrue(falha.waitForExistence(timeout: 10))
        XCTAssertTrue(falha.label.contains("Sem conexão. A candidatura não foi retirada; tente de novo quando a internet voltar."), falha.label)
        XCTAssertTrue(elemento("candidatura-enviada", em: app).exists)
        XCTAssertTrue(app.buttons["retirar-candidatura"].isEnabled, "a retirada não entra em fila: fica para tentar de novo")
        XCTAssertFalse(elemento("candidatura-retirada", em: app).exists)
    }

    // MARK: Critério 1: escolhida e recusada

    func testPushDeConfirmacaoAbreOTurnoDeQuemFoiEscolhido() {
        let app = abrir("candidatura-escolhida", push: "confirmacao", id: turnoID)

        XCTAssertTrue(elemento("tela-meu-turno", em: app).waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Você está confirmado"].exists)
        XCTAssertTrue(elemento("contato-do-turno", em: app).waitForExistence(timeout: 10), "a escolha libera o contato da casa (RN10)")
    }

    func testCandidaturaEscolhidaApareceConfirmadaNaAbaELevaAosMeusTurnos() {
        let app = abrir("candidatura-escolhida")

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        let escolhida = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(escolhida.waitForExistence(timeout: 10))
        XCTAssertTrue(escolhida.label.contains("Confirmada: o turno está em Meus turnos"), escolhida.label)

        escolhida.tap()
        XCTAssertTrue(elemento("tela-meus-turnos", em: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["meu-turno-\(turnoID)"].waitForExistence(timeout: 10))
    }

    func testPushDeCandidaturaRecusadaDizQueOutraPessoaFoiEscolhida() {
        let app = abrir("candidatura-recusada", push: "candidatura_recusada", id: vagaID)

        let indisponivel = elemento("vaga-indisponivel", em: app)
        XCTAssertTrue(indisponivel.waitForExistence(timeout: 15))
        XCTAssertTrue(indisponivel.label.contains("O estabelecimento escolheu outra pessoa"), indisponivel.label)
        XCTAssertTrue(indisponivel.label.contains("A vaga foi preenchida, e a sua candidatura não foi escolhida."), indisponivel.label)
        XCTAssertFalse(app.buttons["candidatar"].exists)
        XCTAssertFalse(app.buttons["retirar-candidatura"].exists)

        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    // MARK: Critério 2: a seleção fechou sem escolha

    func testPushDeSelecaoEncerradaDizQueAVagaFechouSemEscolherACandidatura() {
        let app = abrir("candidatura-expirada", push: "selecao_encerrada", id: vagaID)

        let indisponivel = elemento("vaga-indisponivel", em: app)
        XCTAssertTrue(indisponivel.waitForExistence(timeout: 15))
        XCTAssertTrue(indisponivel.label.contains("A seleção desta vaga foi encerrada"), indisponivel.label)
        XCTAssertTrue(indisponivel.label.contains("A vaga fechou sem que a sua candidatura fosse escolhida."), indisponivel.label)
        XCTAssertFalse(app.buttons["candidatar"].exists)

        // A aba Candidaturas guarda o desfecho, e o toque nela leva à mesma explicação.
        app.buttons["voltar-para-lista"].tap()
        app.tabBars.buttons["Candidaturas"].tap()
        let expirada = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(expirada.waitForExistence(timeout: 10))
        XCTAssertTrue(expirada.label.contains("A seleção foi encerrada sem que a sua candidatura fosse escolhida"), expirada.label)
        expirada.tap()
        XCTAssertTrue(indisponivel.waitForExistence(timeout: 10))
    }

    // MARK: Acessibilidade

    func testCandidaturaPendenteNoMaiorTamanhoDeLetraTemRotuloEAlvoMinimo() {
        let app = abrir("candidatura-pendente", extras: ["-UIPreferredContentSizeCategoryName", Self.ax5])
        let largura = app.windows.firstMatch.frame.width

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        let pendente = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(pendente.waitForExistence(timeout: 10))
        XCTAssertTrue(pendente.isHittable)
        XCTAssertTrue(pendente.label.contains("Aguardando a escolha do estabelecimento"), pendente.label)
        XCTAssertLessThanOrEqual(pendente.frame.maxX, largura, "o cartão da candidatura passou da largura da tela")
        XCTAssertGreaterThanOrEqual(pendente.frame.height, 44)

        pendente.tap()
        let retirar = app.buttons["retirar-candidatura"]
        XCTAssertTrue(retirar.waitForExistence(timeout: 10))
        XCTAssertTrue(retirar.isHittable, "no maior tamanho de letra a retirada fica presa ao rodapé, sempre ao alcance")
        XCTAssertEqual(retirar.label, "Retirar candidatura")
        XCTAssertGreaterThanOrEqual(retirar.frame.height, 44)
        XCTAssertLessThanOrEqual(retirar.frame.maxX, largura)
        XCTAssertTrue(elemento("candidatura-enviada", em: app).label.contains("Candidatura enviada"))

        // O alerta de confirmação cabe e responde no tamanho grande.
        retirar.tap()
        let pergunta = app.alerts["Retirar a candidatura?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        XCTAssertTrue(pergunta.buttons["Retirar"].isHittable)
        pergunta.buttons["Cancelar"].tap()
        XCTAssertTrue(retirar.waitForExistence(timeout: 5))
    }
}
