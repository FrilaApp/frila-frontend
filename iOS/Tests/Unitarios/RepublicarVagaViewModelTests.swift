import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
@testable import FrilaDominio
import Testing
import SwiftData

private actor EspiaoRepublicacao {
    private(set) var chamadas = 0
    private(set) var chaves: [UUID] = []
    private(set) var id: UUID?
    private(set) var periodo: Periodo?
    private(set) var concluido = false

    func gravar(id: UUID, periodo: Periodo, chave: UUID) {
        chamadas += 1
        chaves.append(chave)
        self.id = id
        self.periodo = periodo
    }

    func concluir() {
        concluido = true
    }
}

@Suite("RepublicarVagaViewModelTests")
struct RepublicarVagaViewModelTests {
    private static let duasHoras: TimeInterval = 2 * 3600
    private static let quatroHoras: TimeInterval = 4 * 3600
    private static let umDia: TimeInterval = 24 * 3600

    private func criarVagaNoPainel(
        id: UUID = UUID(),
        modo: ModoPreenchimento = .urgencia,
        posicoes: Int = 2
    ) throws -> VagaNoPainel {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let periodo = try Periodo(inicio: base.addingTimeInterval(Self.duasHoras), fim: base.addingTimeInterval(Self.quatroHoras))
        let resumo = VagaResumo(
            id: id,
            funcao: "Garçom",
            local: "Bar da Praia",
            regiaoAdministrativa: "Asa Sul",
            periodo: periodo,
            valor: Dinheiro(centavos: 15000)
        )
        let listaPosicoes = (0..<posicoes).map { _ in
            PosicaoNoPainel(
                id: UUID(),
                estado: .cumprida,
                profissional: nil,
                turnoID: UUID(),
                verificacao: nil,
                emAtraso: false
            )
        }
        return VagaNoPainel(
            vaga: resumo,
            modo: modo,
            estado: .encerrada,
            alertaVagaVazia: false,
            candidatosPendentes: 0,
            posicoes: listaPosicoes
        )
    }

    @Test("Republicação bem-sucedida preenche resultado e conclui")
    @MainActor
    func sucessoRepublicacao() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let esperadoID = UUID()
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                return VagaPublicada(vagaID: esperadoID, posicoes: [UUID(), UUID()])
            },
            aoConcluir: { _ in
                await espiao.concluir()
            }
        )

        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        #expect(viewModel.validar())
        await viewModel.republicar()

        #expect(viewModel.resultado?.vagaID == esperadoID)
        #expect(viewModel.resultado?.posicoes.count == 2)
        #expect(viewModel.mensagemErro == nil)
        #expect(!viewModel.camposBloqueados)
        #expect(!viewModel.enviando)
        let idGravado = await espiao.id
        let periodoGravado = await espiao.periodo
        let chaves = await espiao.chaves
        let concluido = await espiao.concluido
        #expect(idGravado == vaga.vaga.id)
        #expect(periodoGravado != nil)
        #expect(!chaves.isEmpty)
        #expect(concluido)
    }

    @Test("Validação local: início no passado")
    @MainActor
    func inicioNoPassado() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(-3600)
        viewModel.fim = base.addingTimeInterval(3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.inicio] == TextosRepublicarVaga.inicioNoPassado)
    }

    @Test("Validação local: fim antes ou igual ao início")
    @MainActor
    func fimAntesDoInicio() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.fimAntesDoInicio)
    }

    @Test("Validação local: turno com menos de 2 horas (RN03)")
    @MainActor
    func turnoCurto() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600 + 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.turnoCurto)
    }

    @Test("Validação local: turno com mais de 16 horas (RN03)")
    @MainActor
    func turnoLongo() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600 + 17 * 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.turnoLongo)
    }

    @Test("Validação local: modo seleção com menos de 24 horas de antecedência (RN24)")
    @MainActor
    func selecaoSemAntecedenciaLocal() throws {
        let vaga = try criarVagaNoPainel(modo: .selecao)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(12 * 3600)
        viewModel.fim = base.addingTimeInterval(16 * 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.inicio] == TextosRepublicarVaga.selecaoSemAntecedencia)
    }

    @Test("Erro 404 nao_encontrado: mensagem correta e campos desbloqueados")
    @MainActor
    func erroNaoEncontrado() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .naoEncontrado) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.naoEncontrado)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 403 sem_permissao: mensagem correta")
    @MainActor
    func erroSemPermissao() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .semPermissao) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.semPermissao)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 422 vaga_oculta (contrato 0.2.23): mensagem correta")
    @MainActor
    func erroVagaOculta() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .vagaOculta) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.vagaOculta)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 422 perfil_incompativel: mensagem correta")
    @MainActor
    func erroPerfilIncompativel() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .perfilIncompativel) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.perfilIncompativel)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Sem rede: trava campos, gera chave, guarda erro e permite reenviar")
    @MainActor
    func semRedeBloqueiaCamposEGuardaChave() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .semRede) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.camposBloqueados)
        #expect(viewModel.mensagemErro == TextosRepublicarVaga.semRede)
        #expect(viewModel.chave != nil)
    }

    @Test("Reenvio com a mesma chave após falha de rede")
    @MainActor
    func reenvioComMesmaChave() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                let chamadas = await espiao.chamadas
                if chamadas == 1 {
                    throw ErroDaApi(codigo: .semRede)
                }
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()
        #expect(viewModel.camposBloqueados)
        let chamadas1 = await espiao.chamadas
        #expect(chamadas1 == 1)
        let chavePrimeira = viewModel.chave
        #expect(chavePrimeira != nil)

        await viewModel.republicar()
        let chamadas2 = await espiao.chamadas
        #expect(chamadas2 == 2)
        #expect(viewModel.resultado != nil)
        #expect(!viewModel.camposBloqueados)
        let chavesUtilizadas = await espiao.chaves
        #expect(chavesUtilizadas.count == 2)
        #expect(chavesUtilizadas[0] == chavesUtilizadas[1])
        #expect(viewModel.chave == chavePrimeira)
    }

    @Test("Toque duplo enquanto enviando não chama a API duas vezes")
    @MainActor
    func toqueDuploIgnorado() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                try await Task.sleep(nanoseconds: 50_000_000)
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        let tarefa1 = Task { await viewModel.republicar() }
        await viewModel.republicar()

        _ = await tarefa1.result
        let chamadas = await espiao.chamadas
        #expect(chamadas == 1)
    }

    @Test("68-B1: Fila injetada persiste operação completa antes do envio e sucesso remove sem deixar órfãos")
    @MainActor
    func filaPersistePayloadEChaveERemoveSemOrfaos() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let fila = FilaEspia()
        let espiao = EspiaoRepublicacao()

        let vm = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            fila: fila,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                let chamadas = await espiao.chamadas
                if chamadas == 1 {
                    throw ErroDaApi(codigo: .semRede)
                }
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )

        vm.inicio = base.addingTimeInterval(3 * 3600)
        vm.fim = base.addingTimeInterval(7 * 3600)

        // Primeira tentativa: sem rede
        await vm.republicar()

        #expect(vm.camposBloqueados)
        let pendentes1 = await fila.pendentes()
        #expect(pendentes1.count == 1)
        let acao1 = pendentes1[0]
        #expect(acao1.tipo == .republicacaoVaga)
        #expect(acao1.republicacao != nil)
        #expect(acao1.republicacao?.vagaID == vaga.vaga.id)
        #expect(acao1.republicacao?.periodo.inicio == vm.inicio)
        #expect(acao1.republicacao?.periodo.fim == vm.fim)
        #expect(acao1.chave == vm.chave)

        // Segunda tentativa: sucesso
        await vm.republicar()

        #expect(vm.resultado != nil)
        #expect(!vm.camposBloqueados)
        let pendentes2 = await fila.pendentes()
        #expect(pendentes2.isEmpty)
        let removidas = await fila.removidas
        #expect(removidas == [acao1.id])
    }

    @Test("68-B1: Recuperação de tentativa pendente ao reabrir a folha restaura período, chave e bloqueio")
    @MainActor
    func recuperarTentativaAposReabertura() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let fila = FilaEspia()
        let chavePendente = UUID()
        let inicioPendente = base.addingTimeInterval(5 * 3600)
        let fimPendente = base.addingTimeInterval(9 * 3600)
        let periodoPendente = try Periodo(inicio: inicioPendente, fim: fimPendente)
        let repPendente = RepublicacaoVaga(vagaID: vaga.vaga.id, periodo: periodoPendente)
        let acaoPendente = AcaoPendente(
            tipo: .republicacaoVaga,
            instanteDoToque: base,
            chave: chavePendente,
            republicacao: repPendente
        )
        await fila.enfileirar(acaoPendente)

        let espiao = EspiaoRepublicacao()
        let vm = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            fila: fila,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )

        // Simula abertura da tela com restauração
        await vm.restaurarTentativaPendente()

        #expect(vm.camposBloqueados)
        #expect(vm.chave == chavePendente)
        #expect(vm.inicio == inicioPendente)
        #expect(vm.fim == fimPendente)
        #expect(vm.republicacaoPendente == repPendente)

        // Envia tentativa recuperada
        await vm.republicar()

        #expect(vm.resultado != nil)
        let chamadas = await espiao.chamadas
        #expect(chamadas == 1)
        let chaves = await espiao.chaves
        #expect(chaves == [chavePendente])
        let pendentes = await fila.pendentes()
        #expect(pendentes.isEmpty)
    }

    @Test("68-B2: Alteração de data durante o envio é bloqueada e não afeta o reenvio idempotente")
    @MainActor
    func alteracaoDuranteEnvioNaoMudaPeriodoDoReenvio() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let servidorLento = ServidorLentoEspiao()

        let vm = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, periodo, chave in
                try await servidorLento.executar(periodo: periodo, chave: chave)
            }
        )

        let inicioOriginal = base.addingTimeInterval(3 * 3600)
        let fimOriginal = base.addingTimeInterval(7 * 3600)
        vm.inicio = inicioOriginal
        vm.fim = fimOriginal

        // Inicia envio
        let envio = Task { await vm.republicar() }
        while !(await servidorLento.esperando) { await Task.yield() }

        #expect(vm.enviando)
        // Mesmo que campos sofram mutação em memória enquanto enviando:
        vm.inicio = base.addingTimeInterval(24 * 3600)
        vm.fim = base.addingTimeInterval(28 * 3600)

        // Libera falha de rede
        await servidorLento.liberar(erro: ErroDaApi(codigo: .semRede))
        await envio.value

        #expect(vm.camposBloqueados)

        // Tenta novamente
        await vm.republicar()

        let periodosRecebidos = await servidorLento.periodos
        let chavesRecebidas = await servidorLento.chaves

        #expect(periodosRecebidos.count == 2)
        #expect(chavesRecebidas.count == 2)
        // Ambas as chamadas devem ter o período original congelado e a mesma chave!
        #expect(periodosRecebidos[0] == periodosRecebidos[1])
        #expect(periodosRecebidos[0].inicio == inicioOriginal)
        #expect(periodosRecebidos[0].fim == fimOriginal)
        #expect(chavesRecebidas[0] == chavesRecebidas[1])
    }

    private func origem(api: any ApiCliente, base: Date) async throws -> VagaNoPainel {
        let estabelecimento = try #require(await api.meusEstabelecimentos().first)
        let periodo = try Periodo(inicio: base.addingTimeInterval(-86400), fim: base.addingTimeInterval(86400))
        let painel = try await api.painelEstabelecimento(id: estabelecimento.id, periodo: periodo)
        return try #require(painel.vagas.first)
    }

    @Test("Sincronizador comprova publicação, período e chave; fila vazia não basta")
    func sincronizadorRepublicaVaga() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let api = ApiRepublicacaoRegistrada(base: ApiClienteEmMemoria(
            cenario: .vagaEncerradaContratante, relogio: RelogioRepublicacao(agora: base)))
        let vaga = try await origem(api: api, base: base)
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let periodo = try Periodo(inicio: base.addingTimeInterval(3 * 3600), fim: base.addingTimeInterval(7 * 3600))
        let acao = AcaoPendente(tipo: .republicacaoVaga, instanteDoToque: base, chave: UUID(),
                                republicacao: RepublicacaoVaga(vagaID: vaga.id, periodo: periodo))
        try await fila.enfileirar(acao)
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(try await fila.pendentes().isEmpty)
        #expect(await api.registro.recebidas == [RepublicacaoRecebida(id: vaga.id, periodo: periodo, chave: acao.chave)])
        let publicada = try #require(await api.registro.publicadas.first)
        let detalhe = try await api.detalheDaVaga(id: publicada.vagaID)
        #expect(detalhe.periodo == periodo)
        #expect(detalhe.id != vaga.id)
        #expect(try await api.republicarVaga(id: vaga.id, periodo: periodo, chave: acao.chave) == publicada)
    }

    @Test("Resposta perdida: fechar e reabrir conserva fila real, chave, período e única vaga")
    @MainActor
    func respostaPerdidaComFilaRealEReabertura() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let api = ApiRepublicacaoRegistrada(base: ApiClienteEmMemoria(
            cenario: .vagaEncerradaContratante, relogio: RelogioRepublicacao(agora: base)), perderPrimeiraResposta: true)
        let vaga = try await origem(api: api, base: base)
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let fila = ArmazenamentoSwiftData(modelContainer: container)
        var primeiraFolha: RepublicarVagaViewModel? = RepublicarVagaViewModel(
            vagaOriginal: vaga, api: api, fila: fila, agora: { base })
        #expect(primeiraFolha?.textoAoFechar == TextosRepublicarVaga.cancelar)
        await primeiraFolha?.republicar()
        #expect(primeiraFolha?.resultado == nil)
        #expect(primeiraFolha?.textoAoFechar == TextosRepublicarVaga.fechar)
        let guardada = try #require(await fila.pendentes().first)
        let publicada = try #require(await api.registro.publicadas.first)
        #expect(try await api.detalheDaVaga(id: publicada.vagaID).periodo == guardada.republicacao?.periodo)
        primeiraFolha = nil // Fechar dispensa a folha sem remover a ação.
        #expect(try await fila.pendentes() == [guardada])
        let filaReaberta = ArmazenamentoSwiftData(modelContainer: container)
        let segundaFolha = RepublicarVagaViewModel(vagaOriginal: vaga, api: api, fila: filaReaberta, agora: { base })
        await segundaFolha.restaurarTentativaPendente()
        #expect(segundaFolha.chave == guardada.chave)
        #expect(segundaFolha.acaoPendente?.id == guardada.id)
        #expect(segundaFolha.republicacaoPendente == guardada.republicacao)
        #expect(segundaFolha.textoAoFechar == TextosRepublicarVaga.fechar)
        await segundaFolha.republicar()
        #expect(segundaFolha.resultado == publicada)
        #expect(try await filaReaberta.pendentes().isEmpty)
        let recebidas = await api.registro.recebidas
        #expect(recebidas.count == 2)
        #expect(recebidas[0] == recebidas[1])
        let estabelecimento = try #require(await api.meusEstabelecimentos().first)
        let painel = try await api.painelEstabelecimento(id: estabelecimento.id, periodo: guardada.republicacao!.periodo)
        #expect(painel.vagas.map(\.id) == [publicada.vagaID])
    }

    @Test("Recusa anterior não impede destravar a republicação atual")
    @MainActor
    func duasRecusasDesbloqueiamAtual() async throws {
        let fila = FilaEspia()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let model = RepublicarVagaViewModel(vagaOriginal: try criarVagaNoPainel(), fila: fila,
            agora: { base }, republicar: { _, _, _ in throw ErroDaApi(codigo: .semRede) })
        await model.republicar()
        let anterior = try #require(await fila.pendentes().first)
        try await fila.recusar(anterior, codigo: .horarioInvalido)
        await model.carregarRecusaDaFila()
        await model.republicar()
        let atual = try #require(await fila.pendentes().first)
        try await fila.recusar(atual, codigo: .semPermissao)
        await model.carregarRecusaDaFila()
        #expect(model.recusaDaFila?.id == atual.id)
        #expect(!model.camposBloqueados)
    }

    @Test("Recusa definitiva remove republicação da fila real sem registrar sucesso",
           arguments: [CodigoErroAPI.naoEncontrado, .vagaOculta, .horarioInvalido])
    @MainActor
    func sincronizadorRemoveRecusaDefinitiva(codigo: CodigoErroAPI) async throws {
        let api = ApiRepublicacaoRegistrada(erro: codigo)
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let periodo = try Periodo(inicio: base, fim: base.addingTimeInterval(4 * 3600))
        let vaga = try criarVagaNoPainel()
        let acao = AcaoPendente(tipo: .republicacaoVaga, instanteDoToque: base, chave: UUID(),
                                republicacao: RepublicacaoVaga(vagaID: vaga.id, periodo: periodo))
        try await fila.enfileirar(acao)
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(try await fila.pendentes().isEmpty)
        #expect(await api.registro.publicadas.isEmpty)
        #expect(await api.registro.recebidas.count == 1)
        #expect(try await fila.recusadas() == [AcaoRecusada(acao: acao, codigo: codigo)])
        let model = RepublicarVagaViewModel(vagaOriginal: vaga, api: api, fila: fila)
        await model.restaurarTentativaPendente()
        #expect(model.recusaDaFila == AcaoRecusada(acao: acao, codigo: codigo))
        #expect(!model.camposBloqueados)
        await model.fecharAvisoDaFila()
        #expect(model.recusaDaFila == nil)
        #expect(try await fila.recusadas().isEmpty)
        try await fila.enfileirar(acao)
        #expect(try await fila.pendentes().isEmpty)
    }

    @Test("Reabrir bloqueia confirmação até ler tentativa, sem criar outra chave")
    @MainActor
    func confirmacaoDuranteRestauracaoNaoDuplica() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let periodo = try Periodo(inicio: base.addingTimeInterval(3 * 3600), fim: base.addingTimeInterval(7 * 3600))
        let acao = AcaoPendente(tipo: .republicacaoVaga, instanteDoToque: base, chave: UUID(),
                                republicacao: RepublicacaoVaga(vagaID: vaga.id, periodo: periodo))
        let fila = FilaLeituraControlada(acao: acao)
        let espiao = EspiaoRepublicacao()
        let vm = RepublicarVagaViewModel(vagaOriginal: vaga, fila: fila, agora: { base }, republicar: { id, periodo, chave in
            await espiao.gravar(id: id, periodo: periodo, chave: chave)
            return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
        })
        #expect(!vm.podeConfirmar)
        let restauracao = Task { await vm.restaurarTentativaPendente() }
        while !(await fila.lendo) { await Task.yield() }
        await vm.republicar()
        #expect(await espiao.chamadas == 0)
        #expect(vm.chave == nil)
        #expect(!vm.podeConfirmar)
        await fila.liberar()
        await restauracao.value
        #expect(vm.podeConfirmar)
        #expect(vm.chave == acao.chave)
        await vm.republicar()
        #expect(await espiao.chaves == [acao.chave])
    }

    @Test("Falha ao ler fila bloqueia nova tentativa em vez de gerar outra chave")
    @MainActor
    func falhaAoRestaurarNaoCriaChave() async throws {
        let vaga = try criarVagaNoPainel()
        let espiao = EspiaoRepublicacao()
        let vm = RepublicarVagaViewModel(vagaOriginal: vaga, fila: FilaLeituraComErro(), republicar: { id, periodo, chave in
            await espiao.gravar(id: id, periodo: periodo, chave: chave)
            return VagaPublicada(vagaID: UUID(), posicoes: [])
        })
        await vm.republicar()
        #expect(!vm.podeConfirmar)
        #expect(vm.chave == nil)
        #expect(vm.mensagemErro == TextosRepublicarVaga.erroAoLerFila)
        #expect(await espiao.chamadas == 0)
    }

    @Test("Início padrão de vaga em seleção é 25 h e abre sem erro de validação")
    @MainActor
    func selecaoAbreComInicioPadraoValido() throws {
        let vaga = try criarVagaNoPainel(modo: .selecao)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        // Não mexe em início/fim: usa os valores padrão do init
        #expect(viewModel.inicio == base.addingTimeInterval(25 * 3600))
        #expect(viewModel.fim == base.addingTimeInterval(29 * 3600))
        #expect(viewModel.validar())
        #expect(viewModel.erros.isEmpty)
    }

    @Test("Início padrão de vaga em urgência continua 3 h")
    @MainActor
    func urgenciaContinuaComInicioPadrao3h() throws {
        let vaga = try criarVagaNoPainel(modo: .urgencia)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        #expect(viewModel.inicio == base.addingTimeInterval(3 * 3600))
        #expect(viewModel.fim == base.addingTimeInterval(7 * 3600))
        #expect(viewModel.validar())
        #expect(viewModel.erros.isEmpty)
    }

}

private actor FilaEspia: FilaDeAcoes {
    private var avisos: [AcaoRecusada] = []
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws {
        avisos.append(AcaoRecusada(acao: acao, codigo: codigo))
        remover(id: acao.id)
    }
    func recusadas() -> [AcaoRecusada] { avisos }

    var acoes: [AcaoPendente] = []
    var enfileiradas: [AcaoPendente] = []
    var removidas: [UUID] = []

    func enfileirar(_ acao: AcaoPendente) {
        enfileiradas.append(acao)
        if let idx = acoes.firstIndex(where: { $0.id == acao.id }) {
            acoes[idx] = acao
        } else {
            acoes.append(acao)
        }
    }
    func pendentes() -> [AcaoPendente] { acoes }
    func remover(id: UUID) {
        removidas.append(id)
        acoes.removeAll { $0.id == id }
    }
    func limpar() { acoes = [] }
}

private actor ServidorLentoEspiao {
    var periodos: [Periodo] = []
    var chaves: [UUID] = []
    var esperando = false
    private var continuacao: CheckedContinuation<Void, Never>?
    private var erroParaLancar: Error?

    func executar(periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        periodos.append(periodo)
        chaves.append(chave)
        if chaves.count == 1 {
            esperando = true
            await withCheckedContinuation { cont in
                self.continuacao = cont
            }
            if let erro = erroParaLancar {
                throw erro
            }
        }
        return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
    }

    func liberar(erro: Error? = nil) {
        self.erroParaLancar = erro
        esperando = false
        continuacao?.resume()
        continuacao = nil
    }
}

private struct RelogioRepublicacao: Relogio { let agora: Date }
private struct RepublicacaoRecebida: Equatable, Sendable {
    let id: UUID
    let periodo: Periodo
    let chave: UUID
}
private actor RegistroRepublicacoes {
    var recebidas: [RepublicacaoRecebida] = []
    var publicadas: [VagaPublicada] = []
    let perderPrimeiraResposta: Bool
    let erro: CodigoErroAPI?
    init(perderPrimeiraResposta: Bool, erro: CodigoErroAPI?) {
        self.perderPrimeiraResposta = perderPrimeiraResposta
        self.erro = erro
    }
    func executar(base: ApiClienteEmMemoria, id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        recebidas.append(RepublicacaoRecebida(id: id, periodo: periodo, chave: chave))
        if let erro { throw ErroDaApi(codigo: erro) }
        let publicada = try await base.republicarVaga(id: id, periodo: periodo, chave: chave)
        publicadas.append(publicada)
        if perderPrimeiraResposta, recebidas.count == 1 { throw ErroDaApi(codigo: .semRede) }
        return publicada
    }
}
private final class ApiRepublicacaoRegistrada: ApiClienteEncaminhador, @unchecked Sendable {
    let registro: RegistroRepublicacoes
    init(base: ApiClienteEmMemoria = ApiClienteEmMemoria(), perderPrimeiraResposta: Bool = false, erro: CodigoErroAPI? = nil) {
        registro = RegistroRepublicacoes(perderPrimeiraResposta: perderPrimeiraResposta, erro: erro)
        super.init(base: base)
    }
    override func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        try await registro.executar(base: base, id: id, periodo: periodo, chave: chave)
    }
}
private actor FilaLeituraControlada: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    var acoes: [AcaoPendente]
    var lendo = false
    private var continuacao: CheckedContinuation<Void, Never>?
    private var suspender = true
    init(acao: AcaoPendente) { acoes = [acao] }
    func enfileirar(_ acao: AcaoPendente) { acoes = [acao] }
    func pendentes() async -> [AcaoPendente] {
        if suspender {
            suspender = false
            lendo = true
            await withCheckedContinuation { continuacao = $0 }
        }
        return acoes
    }
    func liberar() { continuacao?.resume(); continuacao = nil }
    func remover(id: UUID) { acoes.removeAll { $0.id == id } }
    func limpar() { acoes = [] }
}
private actor FilaLeituraComErro: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    func pendentes() throws -> [AcaoPendente] { throw ErroDaApi(codigo: .respostaInvalida) }
    func enfileirar(_ acao: AcaoPendente) {}
    func remover(id: UUID) {}
    func limpar() {}
}
