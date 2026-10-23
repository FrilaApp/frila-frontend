import XCTest

/// O destino do toque num push (#8) no dublê, pelo caminho inteiro: o aparelho ganha um token
/// simulado, a conta que entrou o registra, e `-FRILA_PUSH` entrega o payload ao roteador único.
@MainActor
final class PushUITests: XCTestCase {
    /// `vaga.json` do dublê.
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    /// O turno dos cenários do contratante.
    private let turnoDaCasa = "82000000-0000-0000-0000-000000000001"
    private let idDesconhecido = "99999999-0000-0000-0000-000000000001"
    /// O turno dos cenários de turno confirmado do profissional.
    private let turnoProfissionalID = "23000000-0000-0000-0000-000000000001"
    /// O turno concluído para avaliação do profissional.
    private let turnoEncerradoID = "22000000-0000-0000-0000-000000000001"

    private func abrir(
        _ cenario: String,
        push tipo: String,
        id: String? = nil,
        posicaoID: String? = nil,
        outros: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-FRILA_SCENARIO", cenario, "-FRILA_PUSH", tipo]
        if let id { args += ["-FRILA_PUSH_ID", id] }
        if let posicaoID { args += ["-FRILA_PUSH_POSICAO_ID", posicaoID] }
        app.launchArguments = args + outros
        app.launch()
        return app
    }

    func testPushDeVagaAbreODetalheSemCandidatar() {
        let app = abrir("success", push: "vaga", id: vagaID)

        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "o toque abre o detalhe, nunca aceita sozinho")
    }

    func testPushDeVagaIndisponivelAbreATelaPropriaEVoltaParaALista() {
        let app = abrir("success", push: "vaga", id: idDesconhecido)

        XCTAssertTrue(app.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Vaga encerrada"].exists)
        XCTAssertFalse(app.buttons["candidatar"].exists)

        tocar(app.buttons["voltar-para-lista"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testPushEntregueAntesDeOAparelhoSerDaContaNaoAbreNada() {
        let app = abrir("success", push: "vaga", id: vagaID, outros: ["-FRILA_PUSH_DE_ANTES"])

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 3), "push de outra conta não abre destino")
    }

    func testPushDeTurnoQueNaoEDaContaNaoMostraTurnoELevaAosMeusTurnos() {
        let app = abrir("success", push: "lembrete_3h", id: idDesconhecido)

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-aviso-nao-encontrado"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-meu-turno"].exists)

        tocar(app.buttons["ver-meus-turnos"])
        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 10))
    }

    func testPushDaCasaAbreOTurnoParaQuemContrata() {
        let app = abrir("checkin-manual-pendente", push: "checkin_manual_pendente", id: turnoDaCasa)

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Confirmar presença"].exists, "o toque abre o turno, e quem confirma é a pessoa")
    }

    func testPushDeOutroPerfilNaoAbreNada() {
        // Aviso de quem trabalha chegando a uma conta de contratante: fica em Minhas vagas.
        let app = abrir("checkin-manual-pendente", push: "vaga", id: vagaID)

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["detalhe-vaga-contratante"].exists)
    }

    /// Missão 2 / Cartões SIPQtYWH e aAQflYu8:
    /// Grupo 1: Vagas do profissional - `vagas_agrupadas`.
    func testPushDeVagasAgrupadasAbreListaDeVagas() {
        let app = abrir("success", push: "vagas_agrupadas")
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
    }

    /// Missão 2 / Cartões SIPQtYWH e aAQflYu8:
    /// Grupo 2: Gestão do contratante - `vaga_sem_elegiveis`, `vaga_vazia`, `atraso_15min`, `checkin`.
    func testPushesDeGestaoDoContratanteAbremDestinosCorretos() {
        // 1. vaga_sem_elegiveis: abre minhas-vagas
        let appVagaSemElegiveis = abrir("painel-contratante", push: "vaga_sem_elegiveis", id: vagaID)
        XCTAssertTrue(
            appVagaSemElegiveis.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Push de vaga_sem_elegiveis deve abrir minhas-vagas"
        )

        // 2. vaga_vazia: abre minhas-vagas
        let appVagaVazia = abrir("alerta-vaga-vazia", push: "vaga_vazia", id: vagaID)
        XCTAssertTrue(
            appVagaVazia.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Push de vaga_vazia deve abrir minhas-vagas"
        )

        // 3. atraso_15min: abre turno-do-contratante
        let appAtraso = abrir("atraso-no-turno", push: "atraso_15min", id: turnoDaCasa)
        XCTAssertTrue(
            appAtraso.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 15),
            "Push de atraso_15min deve abrir turno-do-contratante"
        )

        // 4. checkin: abre turno-do-contratante
        let appCheckin = abrir("checkin-manual-pendente", push: "checkin", id: turnoDaCasa)
        XCTAssertTrue(
            appCheckin.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 15),
            "Push de checkin deve abrir turno-do-contratante"
        )
    }

    /// Missão 2 / Cartões SIPQtYWH e aAQflYu8:
    /// Grupo 3: Turno do profissional - `confirmacao`, `lembrete_24h`, `lembrete_3h`, `inicio_sem_checkin`, `fim_sem_checkout`, `avaliacao_disponivel`.
    func testPushesDeTurnoDoProfissionalAbremMeuTurnoEAvaliacao() {
        let tiposDeTurno = ["confirmacao", "lembrete_24h", "lembrete_3h", "inicio_sem_checkin", "fim_sem_checkout"]
        for tipo in tiposDeTurno {
            let app = abrir("turno-confirmado-perto", push: tipo, id: turnoProfissionalID)
            XCTAssertTrue(
                app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 15),
                "Push do tipo \(tipo) deve abrir tela-meu-turno para o profissional"
            )
        }

        // avaliacao_disponivel: abre tela-avaliacao
        let appAvaliacao = abrir("turno-encerrado", push: "avaliacao_disponivel", id: turnoEncerradoID)
        XCTAssertTrue(
            appAvaliacao.descendants(matching: .any)["tela-avaliacao"].waitForExistence(timeout: 15),
            "Push de avaliacao_disponivel deve abrir tela-avaliacao para o profissional"
        )
    }

    /// Missão 2 / Cartões SIPQtYWH e aAQflYu8:
    /// Grupo 4: Encerramento e exceções - `cancelamento`, `candidatura_recusada`, `selecao_encerrada`, `selecao_lembrete`, `suspensao`, `reativacao`.
    func testPushesDeEncerramentoEExcecoesAbremDestinosOuReavaliamConta() {
        // 1. cancelamento com posicao_id: abre tela-meus-turnos
        let appCancelamentoComPosicao = abrir("turno-cancelado", push: "cancelamento", posicaoID: "22000000-0000-0000-0000-000000000002")
        XCTAssertTrue(
            appCancelamentoComPosicao.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 15),
            "Cancelamento com posicao_id deve abrir tela-meus-turnos"
        )

        // 2. cancelamento de vaga sem posicao: abre vaga-indisponivel
        let appCancelamentoVaga = abrir("success", push: "cancelamento", id: idDesconhecido)
        XCTAssertTrue(
            appCancelamentoVaga.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15),
            "Cancelamento de vaga sem posicao deve abrir vaga-indisponivel"
        )

        // 3. cancelamento no contratante: abre minhas-vagas
        let appCancelamentoContr = abrir("painel-contratante", push: "cancelamento", id: vagaID)
        XCTAssertTrue(
            appCancelamentoContr.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Cancelamento para contratante deve abrir minhas-vagas"
        )

        // 4. candidatura_recusada: abre vaga-indisponivel
        let appRecusada = abrir("success", push: "candidatura_recusada", id: idDesconhecido)
        XCTAssertTrue(
            appRecusada.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15),
            "Candidatura recusada deve abrir vaga-indisponivel"
        )

        // 5. selecao_encerrada: no profissional abre vaga-indisponivel
        let appSelecaoEncerradaProf = abrir("success", push: "selecao_encerrada", id: idDesconhecido)
        XCTAssertTrue(
            appSelecaoEncerradaProf.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15),
            "Selecao encerrada para profissional deve abrir vaga-indisponivel"
        )

        // 6. selecao_encerrada: no contratante abre minhas-vagas
        let appSelecaoEncerradaContr = abrir("painel-contratante", push: "selecao_encerrada", id: vagaID)
        XCTAssertTrue(
            appSelecaoEncerradaContr.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Selecao encerrada para contratante deve abrir minhas-vagas"
        )

        // 7. selecao_lembrete: no contratante abre minhas-vagas
        let appSelecaoLembrete = abrir("painel-contratante", push: "selecao_lembrete", id: vagaID)
        XCTAssertTrue(
            appSelecaoLembrete.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Selecao lembrete para contratante deve abrir minhas-vagas"
        )

        // 8. suspensao: tipo sem tela propria de destino de vaga/turno; reavalia a conta exibindo tela-conta-suspensa
        let appSuspensao = abrir("conta-suspensa", push: "suspensao")
        XCTAssertTrue(
            appSuspensao.descendants(matching: .any)["tela-conta-suspensa"].waitForExistence(timeout: 15),
            "Push de suspensao deve reavaliar a conta e apresentar tela-conta-suspensa"
        )

        // 9. reativacao: tipo sem tela propria de destino de vaga/turno; reavalia a conta conservando o fluxo ativo
        let appReativacao = abrir("success", push: "reativacao")
        XCTAssertTrue(
            appReativacao.navigationBars["Vagas no DF"].waitForExistence(timeout: 15),
            "Push de reativacao deve reavaliar a conta mantendo o catalogo de vagas aberto"
        )
    }
}
