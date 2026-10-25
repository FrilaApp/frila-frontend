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

    // MARK: - Suíte Parametrizada dos 19 Tipos de Push (SIPQtYWH / aAQflYu8)

    private struct CasoDePush {
        let tipo: String
        let cenario: String
        let id: String?
        let posicaoID: String?
        let descricaoDestino: String
        let razaoSemTelaAlvo: String?
        let elementoEsperado: @MainActor (XCUIApplication) -> XCUIElement

        init(
            tipo: String,
            cenario: String,
            id: String? = nil,
            posicaoID: String? = nil,
            descricaoDestino: String,
            razaoSemTelaAlvo: String? = nil,
            elementoEsperado: @escaping @MainActor (XCUIApplication) -> XCUIElement
        ) {
            self.tipo = tipo
            self.cenario = cenario
            self.id = id
            self.posicaoID = posicaoID
            self.descricaoDestino = descricaoDestino
            self.razaoSemTelaAlvo = razaoSemTelaAlvo
            self.elementoEsperado = elementoEsperado
        }
    }

    /// Catálogo completo com exatamente os 19 tipos de payload catalogados em `TipoDeAviso`.
    private var casosDePush: [CasoDePush] {
        [
            // 1. Vaga do profissional
            CasoDePush(
                tipo: "vaga",
                cenario: "success",
                id: vagaID,
                descricaoDestino: "tela-detalhe-vaga"
            ) { $0.descendants(matching: .any)["tela-detalhe-vaga"] },

            // 2. Vagas agrupadas do profissional
            CasoDePush(
                tipo: "vagas_agrupadas",
                cenario: "success",
                descricaoDestino: "lista de vagas no DF"
            ) { $0.navigationBars["Vagas no DF"] },

            // 3. Vaga sem elegíveis (gestão do contratante)
            CasoDePush(
                tipo: "vaga_sem_elegiveis",
                cenario: "painel-contratante",
                id: vagaID,
                descricaoDestino: "minhas-vagas"
            ) { $0.descendants(matching: .any)["minhas-vagas"] },

            // 4. Confirmação de turno (profissional)
            CasoDePush(
                tipo: "confirmacao",
                cenario: "turno-confirmado-perto",
                id: turnoProfissionalID,
                descricaoDestino: "tela-meu-turno"
            ) { $0.descendants(matching: .any)["tela-meu-turno"] },

            // 5. Lembrete 24h de turno (profissional)
            CasoDePush(
                tipo: "lembrete_24h",
                cenario: "turno-confirmado-perto",
                id: turnoProfissionalID,
                descricaoDestino: "tela-meu-turno"
            ) { $0.descendants(matching: .any)["tela-meu-turno"] },

            // 6. Lembrete 3h de turno (profissional)
            CasoDePush(
                tipo: "lembrete_3h",
                cenario: "turno-confirmado-perto",
                id: turnoProfissionalID,
                descricaoDestino: "tela-meu-turno"
            ) { $0.descendants(matching: .any)["tela-meu-turno"] },

            // 7. Início de turno sem check-in (profissional)
            CasoDePush(
                tipo: "inicio_sem_checkin",
                cenario: "turno-confirmado-perto",
                id: turnoProfissionalID,
                descricaoDestino: "tela-meu-turno"
            ) { $0.descendants(matching: .any)["tela-meu-turno"] },

            // 8. Atraso de 15min no início (contratante)
            CasoDePush(
                tipo: "atraso_15min",
                cenario: "atraso-no-turno",
                id: turnoDaCasa,
                descricaoDestino: "turno-do-contratante"
            ) { $0.descendants(matching: .any)["turno-do-contratante"] },

            // 9. Fim de turno sem check-out (profissional)
            CasoDePush(
                tipo: "fim_sem_checkout",
                cenario: "turno-confirmado-perto",
                id: turnoProfissionalID,
                descricaoDestino: "tela-meu-turno"
            ) { $0.descendants(matching: .any)["tela-meu-turno"] },

            // 10. Vaga vazia na janela crítica (contratante)
            CasoDePush(
                tipo: "vaga_vazia",
                cenario: "alerta-vaga-vazia",
                id: vagaID,
                descricaoDestino: "minhas-vagas"
            ) { $0.descendants(matching: .any)["minhas-vagas"] },

            // 11. Check-in realizado (contratante)
            CasoDePush(
                tipo: "checkin",
                cenario: "checkin-manual-pendente",
                id: turnoDaCasa,
                descricaoDestino: "turno-do-contratante"
            ) { $0.descendants(matching: .any)["turno-do-contratante"] },

            // 12. Check-in manual pendente de aprovação (contratante)
            CasoDePush(
                tipo: "checkin_manual_pendente",
                cenario: "checkin-manual-pendente",
                id: turnoDaCasa,
                descricaoDestino: "turno-do-contratante"
            ) { $0.descendants(matching: .any)["turno-do-contratante"] },

            // 13. Cancelamento com posição (profissional)
            CasoDePush(
                tipo: "cancelamento",
                cenario: "turno-cancelado",
                posicaoID: "22000000-0000-0000-0000-000000000002",
                descricaoDestino: "tela-meus-turnos"
            ) { $0.descendants(matching: .any)["tela-meus-turnos"] },

            // 14. Avaliação disponível (profissional)
            CasoDePush(
                tipo: "avaliacao_disponivel",
                cenario: "turno-encerrado",
                id: turnoEncerradoID,
                descricaoDestino: "tela-avaliacao"
            ) { $0.descendants(matching: .any)["tela-avaliacao"] },

            // 15. Suspensão de conta (sem tela direta de vaga/turno)
            CasoDePush(
                tipo: "suspensao",
                cenario: "conta-suspensa",
                descricaoDestino: "tela-conta-suspensa",
                razaoSemTelaAlvo: "Sem tela de destino de vaga/turno no payload: o app reavalia a conta no servidor e apresenta bloqueio em tela-conta-suspensa."
            ) { $0.descendants(matching: .any)["tela-conta-suspensa"] },

            // 16. Reativação de conta (sem tela direta de vaga/turno)
            CasoDePush(
                tipo: "reativacao",
                cenario: "success",
                descricaoDestino: "catálogo de vagas ativo",
                razaoSemTelaAlvo: "Sem tela de destino de vaga/turno no payload: o app reavalia a conta no servidor e conserva o fluxo ativo no catálogo de vagas."
            ) { $0.navigationBars["Vagas no DF"] },

            // 17. Candidatura recusada (profissional)
            CasoDePush(
                tipo: "candidatura_recusada",
                cenario: "success",
                id: idDesconhecido,
                descricaoDestino: "vaga-indisponivel"
            ) { $0.descendants(matching: .any)["vaga-indisponivel"] },

            // 18. Seleção encerrada (profissional)
            CasoDePush(
                tipo: "selecao_encerrada",
                cenario: "success",
                id: idDesconhecido,
                descricaoDestino: "vaga-indisponivel"
            ) { $0.descendants(matching: .any)["vaga-indisponivel"] },

            // 19. Lembrete de seleção com prazo próximo (contratante)
            CasoDePush(
                tipo: "selecao_lembrete",
                cenario: "painel-contratante",
                id: vagaID,
                descricaoDestino: "minhas-vagas"
            ) { $0.descendants(matching: .any)["minhas-vagas"] },
        ]
    }

    /// Cartões SIPQtYWH e aAQflYu8:
    /// Suíte parametrizada cobrindo integralmente os 19 tipos de payload catalogados em `TipoDeAviso`.
    /// Valida que cada payload com `-FRILA_PUSH <tipo>` abre a tela correspondente no simulador.
    /// Tipos sem tela de destino direto de vaga/turno no payload (`suspensao`, `reativacao`)
    /// disparam a reavaliação da conta e são validados no estado correspondente.
    func testDezenoveTiposDePushCatalogadosAbremTelaCorrespondente() {
        let casos = casosDePush
        XCTAssertEqual(casos.count, 19, "A suíte parametrizada deve cobrir exatamente os 19 tipos catalogados")

        let tiposUnicos = Set(casos.map(\.tipo))
        XCTAssertEqual(tiposUnicos.count, 19, "Cada um dos 19 tipos deve ser único no catálogo de testes")

        let semTelaAlvo = casos.filter { $0.razaoSemTelaAlvo != nil }
        XCTAssertEqual(
            semTelaAlvo.map(\.tipo).sorted(),
            ["reativacao", "suspensao"],
            "Apenas suspensao e reativacao não possuem tela alvo de vaga/turno no payload"
        )
        for caso in semTelaAlvo {
            XCTAssertFalse(
                caso.razaoSemTelaAlvo?.isEmpty ?? true,
                "Tipo sem tela alvo direta deve conter justificativa explícita"
            )
        }

        for caso in casos {
            let app = abrir(
                caso.cenario,
                push: caso.tipo,
                id: caso.id,
                posicaoID: caso.posicaoID
            )

            let elemento = caso.elementoEsperado(app)
            XCTAssertTrue(
                elemento.waitForExistence(timeout: 15),
                "Push do tipo '\(caso.tipo)' deve abrir \(caso.descricaoDestino)"
            )
            app.terminate()
        }
    }

    /// Variantes complementares de perfil e parâmetros para cancelamento e seleção encerrada.
    func testVariantesDePerfilParaCancelamentoESelecao() {
        // 1. cancelamento de vaga sem posicao: abre vaga-indisponivel
        let appCancelamentoVaga = abrir("success", push: "cancelamento", id: idDesconhecido)
        XCTAssertTrue(
            appCancelamentoVaga.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15),
            "Cancelamento de vaga sem posicao deve abrir vaga-indisponivel"
        )

        // 2. cancelamento no contratante: abre minhas-vagas
        let appCancelamentoContr = abrir("painel-contratante", push: "cancelamento", id: vagaID)
        XCTAssertTrue(
            appCancelamentoContr.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Cancelamento para contratante deve abrir minhas-vagas"
        )

        // 3. selecao_encerrada no contratante: abre minhas-vagas
        let appSelecaoEncerradaContr = abrir("painel-contratante", push: "selecao_encerrada", id: vagaID)
        XCTAssertTrue(
            appSelecaoEncerradaContr.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15),
            "Selecao encerrada para contratante deve abrir minhas-vagas"
        )
    }
}
