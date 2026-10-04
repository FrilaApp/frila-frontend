import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private func vagaDoDuble(_ api: ApiClienteEmMemoria) async throws -> Vaga {
    let aberta = try #require(try await api.vagasAbertas(.todas).first)
    return try await api.detalheDaVaga(id: aberta.id)
}

private func falhando(_ erro: ErroDaApi) -> @Sendable (UUID) async throws -> ResultadoCandidatura {
    { _ in throw erro }
}

@MainActor
@Suite("Candidatura (#105): resultados, toque duplo e erro tipado")
struct CandidaturaViewModelTests {
    @Test("Somente função incompatível oferece o destino de ajuste de funções")
    func ajusteDeFuncoesSomenteParaFuncaoIncompativel() {
        let vagaID = UUID()
        let resultados: [ResultadoDaCandidatura] = [
            .confirmada(turnoID: nil, contato: nil), .pendente(candidaturaID: UUID()),
            .vagaPreenchida, .vagaEncerrada, .inelegivel(.turnoSobreposto),
            .inelegivel(.funcaoIncompativel), .inelegivel(.outro(detalhes: nil)),
            .contaSuspensa, .naoEncontrada, .falha(ErroDaApi(codigo: .semRede)), .outraEmAndamento
        ]
        for resultado in resultados {
            let roteador = RoteadorDoProfissional()
            roteador.ajustarFuncoes(vagaID: vagaID, resultado: resultado)
            #expect(roteador.caminho == (resultado == .inelegivel(.funcaoIncompativel)
                                       ? [.ajustarFuncoes(vagaID: vagaID)] : []))
        }
    }

    @Test("Após salvar a função exigida, uma nova tentativa manual pode confirmar a candidatura")
    func ajustarFuncaoPermiteTentarNovamente() async throws {
        let api = ApiClienteEmMemoria(cenario: .funcaoIncompativel)
        let vaga = try await vagaDoDuble(api)
        let primeira = CandidaturaViewModel(vaga: vaga, api: api)
        await primeira.candidatar()
        #expect(primeira.estado == .concluida(.inelegivel(.funcaoIncompativel)))

        let perfil = PerfilProfissionalViewModel(api: api, modo: .edicao)
        await perfil.carregar()
        #expect(!perfil.funcoesSelecionadas.contains(vaga.funcao.id))
        perfil.alternarFuncao(vaga.funcao.id)
        #expect(await perfil.salvar())
        #expect(await api.chamadasACandidatar == 1, "salvar o perfil não envia candidatura")

        let novaTentativa = CandidaturaViewModel(vaga: vaga, api: api)
        await novaTentativa.candidatar()
        guard case .concluida(.confirmada) = novaTentativa.estado else {
            Issue.record("A nova tentativa deveria confirmar: \(novaTentativa.estado)"); return
        }
    }

    @Test("Confirmada: devolve o turno e o contato da confirmação")
    func confirmada() async throws {
        let api = ApiClienteEmMemoria()
        let vm = CandidaturaViewModel(vaga: try await vagaDoDuble(api), api: api)
        #expect(vm.estado == .ocioso)
        await vm.candidatar()
        guard case let .concluida(.confirmada(turnoID, contato)) = vm.estado else {
            Issue.record("esperado confirmada: \(vm.estado)"); return
        }
        #expect(turnoID != nil)
        #expect(contato != nil)
    }

    @Test("Os cenários do dublê chegam como resultados tipados distintos",
          arguments: [
              (ApiClienteEmMemoria.Cenario.vagaPreenchida, "vagaPreenchida"),
              (.vagaEncerrada, "vagaEncerrada"),
              (.inelegivelSuspenso, "contaSuspensa"),
          ])
    func cenarios(cenario: ApiClienteEmMemoria.Cenario, esperado: String) async throws {
        let api = ApiClienteEmMemoria(cenario: cenario)
        let vm = CandidaturaViewModel(vaga: try await vagaDoDuble(ApiClienteEmMemoria()), api: api)
        await vm.candidatar()
        let esperadoTipado: ResultadoDaCandidatura = switch esperado {
        case "vagaPreenchida": .vagaPreenchida
        case "vagaEncerrada": .vagaEncerrada
        default: .contaSuspensa
        }
        #expect(vm.estado == .concluida(esperadoTipado))
    }

    @Test("409 posicao_ja_preenchida é vagaPreenchida e 409 vaga_encerrada é vagaEncerrada, nunca o mesmo caso")
    func conflitosDistintos() async throws {
        let vaga = try await vagaDoDuble(ApiClienteEmMemoria())
        let preenchida = CandidaturaViewModel(vaga: vaga, candidatar: falhando(ErroDaApi(codigo: .posicaoJaPreenchida)))
        let encerrada = CandidaturaViewModel(vaga: vaga, candidatar: falhando(ErroDaApi(codigo: .vagaEncerrada)))
        await preenchida.candidatar()
        await encerrada.candidatar()
        #expect(preenchida.estado == .concluida(.vagaPreenchida))
        #expect(encerrada.estado == .concluida(.vagaEncerrada))
    }

    @Test("Turno sobreposto é resultado próprio, sem buscar nem apontar um turno específico")
    func turnoSobreposto() async throws {
        let api = ApiClienteEmMemoria(cenario: .inelegivel)
        let vm = CandidaturaViewModel(vaga: try await vagaDoDuble(ApiClienteEmMemoria()), api: api)
        await vm.candidatar()
        #expect(vm.estado == .concluida(.inelegivel(.turnoSobreposto)))
    }

    @Test("Outros códigos: função incompatível, 403 conta suspensa, 404, sem rede",
          arguments: [
              (ErroDaApi(codigo: .inelegivel, detalhes: "funcao_incompativel"), ResultadoDaCandidatura.inelegivel(.funcaoIncompativel)),
              (ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), .contaSuspensa),
              (ErroDaApi(codigo: .naoEncontrado), .naoEncontrada),
              (ErroDaApi(codigo: .semRede), .falha(ErroDaApi(codigo: .semRede))),
          ])
    func outrosCodigos(erro: ErroDaApi, esperado: ResultadoDaCandidatura) async throws {
        let vaga = try await vagaDoDuble(ApiClienteEmMemoria())
        let vm = CandidaturaViewModel(vaga: vaga, candidatar: falhando(erro))
        await vm.candidatar()
        #expect(vm.estado == .concluida(esperado))
    }

    @Test("Candidatura pendente (vaga de seleção) é resultado próprio, com o id que a retirada pede")
    func pendente() async throws {
        let vaga = try await vagaDoDuble(ApiClienteEmMemoria())
        let candidaturaID = UUID()
        let vm = CandidaturaViewModel(
            vaga: vaga,
            candidatar: { _ in ResultadoCandidatura(estado: .pendente, candidaturaID: candidaturaID, posicaoID: nil, turnoID: nil, contato: nil) }
        )
        await vm.candidatar()
        #expect(vm.estado == .concluida(.pendente(candidaturaID: candidaturaID)))
        #expect(vm.candidaturaPendente == candidaturaID)
        #expect(ResultadoDaCandidatura.pendente(candidaturaID: candidaturaID).abreTelaPropria)
    }

    @Test("Toque duplo: o segundo toque durante o envio não chama candidatar de novo")
    func toqueDuplo() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try await vagaDoDuble(api)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let vm = CandidaturaViewModel(
            vaga: vaga,
            candidatar: { id in
                avisarChegada.yield()
                for await _ in liberar { break }
                return try await api.candidatar(vagaID: id)
            }
        )
        let primeiro = Task { await vm.candidatar() }
        for await _ in chegou { break }
        #expect(vm.enviando)
        await vm.candidatar()
        #expect(vm.enviando, "o segundo toque voltou sem mudar o estado")
        sinal.yield()
        await primeiro.value
        #expect(await api.chamadasACandidatar == 1)
        guard case .concluida(.confirmada) = vm.estado else { Issue.record("esperado confirmada: \(vm.estado)"); return }
    }

    @Test("Resultado confirmado substitui uma vaga aberta enquanto a candidatura ainda está em voo")
    func resultadoNaoSePerdeAoAbrirOutraVaga() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try await vagaDoDuble(api)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let viewModel = CandidaturaViewModel(vaga: vaga, candidatar: { id in
            avisarChegada.yield()
            for await _ in liberar { break }
            return try await api.candidatar(vagaID: id)
        })
        let roteador = RoteadorDoProfissional()
        roteador.abrirVaga(id: vaga.id)

        let envio = Task { await roteador.candidatar(viewModel: viewModel) }
        for await _ in chegou { break }
        roteador.abrirVaga(id: UUID())
        sinal.yield()
        await envio.value

        guard case let .resultado(vaga: vagaDoResultado, resultado: .confirmada) = roteador.caminho.last else {
            Issue.record("esperado rota de resultado confirmada: \(roteador.caminho)"); return
        }
        #expect(vagaDoResultado.id == vaga.id)
    }

    @Test("Candidatura com falha libera candidaturaEmAndamento no roteador via defer")
    func candidaturaFalhaLiberaRoteadorViaDefer() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try await vagaDoDuble(api)
        let roteador = RoteadorDoProfissional()
        let vm = CandidaturaViewModel(vaga: vaga, candidatar: falhando(ErroDaApi(codigo: .desconhecido)))

        await roteador.candidatar(viewModel: vm)

        #expect(vm.estado == .concluida(.falha(ErroDaApi(codigo: .desconhecido))))
        #expect(roteador.candidaturaEmAndamento == nil, "candidaturaEmAndamento deve ser liberada mesmo quando a chamada falha")
        #expect(roteador.caminho.isEmpty, "não deve navegar para tela de resultado quando a candidatura falha")
    }

    @Test("Conclusão de candidatura anterior não apaga candidaturaEmAndamento mais nova")
    func candidaturaConcluidaNaoApagaCandidaturaMaisNova() async throws {
        let api = ApiClienteEmMemoria()
        let vaga1 = try await vagaDoDuble(api)
        let vaga2 = try await vagaDoDuble(api)
        let roteador = RoteadorDoProfissional()

        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let vm1 = CandidaturaViewModel(vaga: vaga1, candidatar: { _ in
            avisarChegada.yield()
            for await _ in liberar { break }
            throw ErroDaApi(codigo: .desconhecido)
        })
        let vm2 = CandidaturaViewModel(vaga: vaga2, api: api)

        let tarefa1 = Task { await roteador.candidatar(viewModel: vm1) }
        for await _ in chegou { break }

        // Simula uma candidatura mais nova assumindo o roteador enquanto a anterior estava em voo
        roteador.candidaturaEmAndamento = vm2

        sinal.yield()
        await tarefa1.value

        #expect(roteador.candidaturaEmAndamento === vm2, "candidatura mais nova não deve ser apagada pelo término da anterior")
    }

    @Test("Toque ignorado por ter outra candidatura em voo avisa no estado do viewModel")
    func toqueEnquantoOutraEstaEmVooAvisaNoEstado() async throws {
        let api = ApiClienteEmMemoria()
        let vaga1 = try await vagaDoDuble(api)
        let vaga2 = try await vagaDoDuble(api)
        let roteador = RoteadorDoProfissional()

        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let vm1 = CandidaturaViewModel(vaga: vaga1, candidatar: { id in
            avisarChegada.yield()
            for await _ in liberar { break }
            return try await api.candidatar(vagaID: id)
        })
        let vm2 = CandidaturaViewModel(vaga: vaga2, api: api)

        let tarefa1 = Task { await roteador.candidatar(viewModel: vm1) }
        for await _ in chegou { break }

        #expect(vm1.enviando)
        await roteador.candidatar(viewModel: vm2)

        #expect(vm2.estado == .concluida(.outraEmAndamento))
        #expect(roteador.candidaturaEmAndamento === vm1, "a primeira candidatura continua em andamento")

        sinal.yield()
        await tarefa1.value
        #expect(roteador.candidaturaEmAndamento == nil, "após a primeira terminar, o roteador é liberado")
    }

    @Test("Resultado outraEmAndamento gera aviso no detalhe e não abre tela própria")
    func outraEmAndamentoFicaNoDetalhe() {
        #expect(!ResultadoDaCandidatura.outraEmAndamento.abreTelaPropria)
        #expect(AreaDeCandidatura.mensagemNoDetalhe(.outraEmAndamento) == TextosDoProfissional.Candidatura.outraEmAndamento)
    }
}
