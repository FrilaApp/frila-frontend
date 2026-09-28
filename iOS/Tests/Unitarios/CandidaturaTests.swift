import Foundation
import FrilaApresentacao
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
        let preenchida = CandidaturaViewModel(vaga: vaga, candidatar: falhando(ErroDaApi(codigo: .posicaoJaPreenchida)), meusTurnos: { [] })
        let encerrada = CandidaturaViewModel(vaga: vaga, candidatar: falhando(ErroDaApi(codigo: .vagaEncerrada)), meusTurnos: { [] })
        await preenchida.candidatar()
        await encerrada.candidatar()
        #expect(preenchida.estado == .concluida(.vagaPreenchida))
        #expect(encerrada.estado == .concluida(.vagaEncerrada))
    }

    @Test("Turno sobreposto traz o turno em conflito, achado em meus_turnos")
    func turnoSobreposto() async throws {
        let api = ApiClienteEmMemoria(cenario: .inelegivel)
        let vaga = try await vagaDoDuble(api)
        let vm = CandidaturaViewModel(vaga: vaga, api: api)
        await vm.candidatar()
        guard case let .concluida(.inelegivel(.turnoSobreposto(conflito))) = vm.estado else {
            Issue.record("esperado turno sobreposto: \(vm.estado)"); return
        }
        let turno = try #require(conflito)
        #expect(turno.vaga.periodo.inicio < vaga.periodo.fim && vaga.periodo.inicio < turno.vaga.periodo.fim)
    }

    @Test("Turno sobreposto sem conseguir ler meus_turnos: resultado sem o link")
    func turnoSobrepostoSemConflito() async throws {
        let vaga = try await vagaDoDuble(ApiClienteEmMemoria())
        let vm = CandidaturaViewModel(
            vaga: vaga,
            candidatar: falhando(ErroDaApi(codigo: .inelegivel, detalhes: "turno_sobreposto")),
            meusTurnos: { throw ErroDaApi(codigo: .semRede) }
        )
        await vm.candidatar()
        #expect(vm.estado == .concluida(.inelegivel(.turnoSobreposto(conflito: nil))))
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
        let vm = CandidaturaViewModel(vaga: vaga, candidatar: falhando(erro), meusTurnos: { [] })
        await vm.candidatar()
        #expect(vm.estado == .concluida(esperado))
    }

    @Test("Candidatura pendente não existe na v1.0: vira falha tipada")
    func pendente() async throws {
        let vaga = try await vagaDoDuble(ApiClienteEmMemoria())
        let vm = CandidaturaViewModel(
            vaga: vaga,
            candidatar: { _ in ResultadoCandidatura(estado: .pendente, candidaturaID: UUID(), posicaoID: nil, turnoID: nil, contato: nil) },
            meusTurnos: { [] }
        )
        await vm.candidatar()
        guard case let .concluida(.falha(erro)) = vm.estado else { Issue.record("esperado falha: \(vm.estado)"); return }
        #expect(erro.codigoOriginal == "candidatura_pendente")
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
            },
            meusTurnos: { [] }
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
}
