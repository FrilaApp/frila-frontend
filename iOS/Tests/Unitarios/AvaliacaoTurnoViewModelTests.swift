import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private actor FilaDeAcoesMemoria: FilaDeAcoes {
    var itens: [AcaoPendente] = []

    init(itens: [AcaoPendente] = []) {
        self.itens = itens
    }

    func enfileirar(_ acao: AcaoPendente) throws {
        itens.append(acao)
    }

    func pendentes() throws -> [AcaoPendente] {
        itens
    }

    func remover(id: UUID) throws {
        itens.removeAll(where: { $0.id == id })
    }

    func limpar() throws {
        itens.removeAll()
    }
}

private final class ApiClienteAvaliacaoDuble: ApiCliente, @unchecked Sendable {
    private let base: ApiClienteEmMemoria
    private let trava = NSLock()
    var erroAvaliar: (any Error)?
    var pausaAvaliar: UInt64 = 0
    private var _chamadasAvaliar: [(turnoID: UUID, resposta: Bool)] = []

    var chamadasAvaliar: [(turnoID: UUID, resposta: Bool)] {
        trava.withLock { _chamadasAvaliar }
    }

    init(base: ApiClienteEmMemoria = ApiClienteEmMemoria()) {
        self.base = base
    }

    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        let (erro, pausa) = trava.withLock {
            _chamadasAvaliar.append((turnoID, resposta))
            return (erroAvaliar, pausaAvaliar)
        }

        if pausa > 0 {
            try? await Task.sleep(nanoseconds: pausa)
        }

        if let erro {
            throw erro
        }
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: Date())
    }

    // Encaminhamentos padrão
    func solicitarCodigo(email: String) async throws { try await base.solicitarCodigo(email: email) }
    func verificarCodigo(email: String, codigo: String) async throws { try await base.verificarCodigo(email: email, codigo: codigo) }
    func entrarDemonstracao(email: String, codigo: String) async throws { try await base.entrarDemonstracao(email: email, codigo: codigo) }
    func possuiSessao() async -> Bool { await base.possuiSessao() }
    func minhaConta() async throws -> Conta { try await base.minhaConta() }
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta { try await base.criarConta(cadastro) }
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional { try await base.criarPerfilProfissional(dados) }
    func meuPerfilProfissional() async throws -> PerfilProfissional { try await base.meuPerfilProfissional() }
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional { try await base.atualizarPerfilProfissional(alteracao) }
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento { try await base.cadastrarEstabelecimento(cadastro) }
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] { try await base.meusEstabelecimentos() }
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel { try await base.painelEstabelecimento(id: id, periodo: periodo) }
    func funcoes() async throws -> [Funcao] { try await base.funcoes() }
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada { try await base.publicarVaga(publicacao) }
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada { try await base.republicarVaga(id: id, periodo: periodo, chave: chave) }
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] { try await base.vagasAbertas(filtro) }
    func detalheDaVaga(id: UUID) async throws -> Vaga { try await base.detalheDaVaga(id: id) }
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura { try await base.candidatar(vagaID: vagaID) }
    func perfilPublico(id: UUID) async throws -> PerfilPublico { try await base.perfilPublico(id: id) }
    func meusTurnos() async throws -> [Turno] { try await base.meusTurnos() }
    func contatoDoTurno(id: UUID) async throws -> Contato { try await base.contatoDoTurno(id: id) }
    func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho { try await base.avisarACaminho(turnoID: turnoID) }
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await base.fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await base.fazerCheckout(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro { try await base.confirmarCheckinManual(turnoID: turnoID) }
    func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento { try await base.reabrirPorAtraso(posicaoID: posicaoID) }
    func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento { try await base.cancelarPosicao(id: id, motivo: motivo) }
    func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada { try await base.cancelarVaga(id: id, motivo: motivo) }
    func denunciar(_ denuncia: Denuncia) async throws -> Protocolo { try await base.denunciar(denuncia) }
    func bloquear(_ alvo: Alvo) async throws -> Bloqueio { try await base.bloquear(alvo) }
    func situacaoDaConta() async throws -> SituacaoDaConta { try await base.situacaoDaConta() }
    func contestarSuspensao(relato: String) async throws -> Protocolo { try await base.contestarSuspensao(relato: relato) }
    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }
    func removerDispositivo(tokenFCM: String) async throws { try await base.removerDispositivo(tokenFCM: tokenFCM) }
    func sair(tokenFCM: String?) async { await base.sair(tokenFCM: tokenFCM) }
}

private final class RelogioSimulado: Relogio, @unchecked Sendable {
    var agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private func criarTurno(
    fim: Date,
    verificacao: Verificacao = .verificado,
    podeAvaliar: Bool = true
) throws -> Turno {
    let inicio = fim.addingTimeInterval(-4 * 3600)
    let vaga = VagaResumo(
        id: UUID(),
        funcao: "Garçom",
        local: "Bar do Lago",
        regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: inicio, fim: fim),
        valor: Dinheiro(centavos: 15000)
    )
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
    let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao)
    return Turno(
        id: UUID(),
        posicaoID: UUID(),
        vaga: vaga,
        contraparte: contraparte,
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3600),
        verificacao: verificacao,
        valorAcordado: vaga.valor,
        podeAvaliar: podeAvaliar
    )
}

@Suite("Avaliação do turno (#22)")
struct AvaliacaoTurnoViewModelTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Sucesso: registra avaliação online e salva resposta no armazenamento local")
    @MainActor
    func sucessoOnline() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.sucesso == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoSucesso)
        #expect(vm.mensagemDeErro == nil)
        #expect(armazenamento.resposta(para: turno.id) == true)
        #expect(api.chamadasAvaliar.count == 1)
        #expect(api.chamadasAvaliar.first?.resposta == true)
    }

    @Test("Erro 422: avaliacao_indisponivel exibe mensagem explicativa")
    @MainActor
    func erro422AvaliacaoIndisponivel() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .avaliacaoIndisponivel)
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == false)
        #expect(vm.sucesso == false)
        #expect(vm.jaAvaliado == false)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)
        #expect(armazenamento.resposta(para: turno.id) == nil)
    }

    @Test("Erro 409: avaliacao_ja_registrada marca como ja avaliado e exibe mensagem")
    @MainActor
    func erro409AvaliacaoJaRegistrada() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .avaliacaoJaRegistrada)
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = false
        let salvou = await vm.salvar()

        #expect(salvou == false)
        #expect(vm.sucesso == false)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Avaliacao.erroJaRegistrada)
        #expect(armazenamento.resposta(para: turno.id) == false)
    }

    @Test("Sem rede: enfileira ação de avaliação na fila offline e salva localmente")
    @MainActor
    func semRedeEnfileirando() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .semRede)
        let fila = FilaDeAcoesMemoria()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            turno: turno,
            api: api,
            fila: fila,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.sucesso == true)
        #expect(vm.enfileiradoOffline == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoOffline)
        #expect(vm.mensagemDeErro == nil)
        #expect(armazenamento.resposta(para: turno.id) == true)

        let pendentes = try await fila.pendentes()
        #expect(pendentes.count == 1)
        #expect(pendentes.first?.tipo == .avaliacao)
        #expect(pendentes.first?.turnoID == turno.id)
        #expect(pendentes.first?.resposta == true)
    }

    @Test("Reentrada com guard: chamadas simultâneas a salvar chamam a API apenas uma vez")
    @MainActor
    func reentradaComGuard() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.pausaAvaliar = 50_000_000 // 50ms
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        async let primeira = vm.salvar()
        async let segunda = vm.salvar()

        let (r1, r2) = await (primeira, segunda)
        #expect((r1 && !r2) || (!r1 && r2))
        #expect(api.chamadasAvaliar.count == 1)
    }

    @Test("Reabrir mostra a resposta dada salva no armazenamento")
    @MainActor
    func reabrirMostraRespostaDada() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()
        armazenamento.salvar(resposta: false, para: turnoID)

        let vm = AvaliacaoTurnoViewModel(
            turnoID: turnoID,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        #expect(vm.resposta == false)
        #expect(vm.jaAvaliado == true)

        let salvou = await vm.salvar()
        #expect(salvou == false)
        #expect(api.chamadasAvaliar.isEmpty)
    }

    @Test("Reabrir carrega resposta da fila de ações pendentes se não gravada no armazenamento")
    @MainActor
    func reabrirCarregaRespostaDaFilaPendente() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let fila = FilaDeAcoesMemoria()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()

        let acao = AcaoPendente(
            tipo: .avaliacao,
            turnoID: turnoID,
            instanteDoToque: agora,
            chave: UUID(),
            resposta: true
        )
        try await fila.enfileirar(acao)

        let vm = AvaliacaoTurnoViewModel(
            turnoID: turnoID,
            api: api,
            fila: fila,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        await vm.carregar()

        #expect(vm.resposta == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.enfileiradoOffline == true)
        #expect(armazenamento.resposta(para: turnoID) == true)
    }

    @Test("Validação local: não permite avaliar antes do fim previsto ou sem presença verificada")
    @MainActor
    func validacaoAntesDoFimOuSemPresenca() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()

        // Turno no futuro
        let turnoFuturo = try criarTurno(fim: agora.addingTimeInterval(3600), verificacao: .verificado)
        let vmFuturo = AvaliacaoTurnoViewModel(
            turnoID: turnoFuturo.id,
            turno: turnoFuturo,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )
        vmFuturo.resposta = true
        let salvouFuturo = await vmFuturo.salvar()
        #expect(salvouFuturo == false)
        #expect(vmFuturo.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)

        // Turno sem presença verificada
        let turnoSemPresenca = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .pendente)
        let vmSemPresenca = AvaliacaoTurnoViewModel(
            turnoID: turnoSemPresenca.id,
            turno: turnoSemPresenca,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )
        vmSemPresenca.resposta = true
        let salvouSemPresenca = await vmSemPresenca.salvar()
        #expect(salvouSemPresenca == false)
        #expect(vmSemPresenca.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)
        #expect(api.chamadasAvaliar.isEmpty)
    }

    @Test("MeuTurnoViewModel: podeAvaliar só é verdadeiro após fim previsto e com presença verificada")
    @MainActor
    func meuTurnoPodeAvaliar() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let relogio = RelogioSimulado(agora)

        // Antes do fim
        let turnoAntesDoFim = try criarTurno(fim: agora.addingTimeInterval(3600), verificacao: .verificado)
        let vm1 = MeuTurnoViewModel(turno: turnoAntesDoFim, api: api, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm1.podeAvaliar == false)

        // Depois do fim, mas presença pendente
        let turnoPendente = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .pendente)
        let vm2 = MeuTurnoViewModel(turno: turnoPendente, api: api, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm2.podeAvaliar == false)

        // Depois do fim, mas presença não verificada
        let turnoNaoVerificado = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .naoVerificado)
        let vm3 = MeuTurnoViewModel(turno: turnoNaoVerificado, api: api, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm3.podeAvaliar == false)

        // Depois do fim e verificado
        let turnoPronto = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .verificado)
        let vm4 = MeuTurnoViewModel(turno: turnoPronto, api: api, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm4.podeAvaliar == true)
        #expect(vm4.jaAvaliado == false)

        // Quando avaliado
        armazenamento.salvar(resposta: true, para: turnoPronto.id)
        #expect(vm4.respostaAvaliacao == true)
        #expect(vm4.jaAvaliado == true)
    }
}
