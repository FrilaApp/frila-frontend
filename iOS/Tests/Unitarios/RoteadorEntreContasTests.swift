import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Achado do Lince Codex (18/11/2026): o roteador do profissional é do app, não da conta. A candidatura da conta A
/// ainda em voo sobrevivia aos reinícios da saída e da entrada e repunha, para a conta B, o resultado com a vaga de A.

/// O envio que o teste segura: a candidatura só termina quando o teste manda.
private actor EnvioSegurado {
    private var resposta: CheckedContinuation<ResultadoCandidatura, Never>?
    private var esperandoOInicio: [CheckedContinuation<Void, Never>] = []

    func enviar() async -> ResultadoCandidatura {
        await withCheckedContinuation { continuacao in
            resposta = continuacao
            esperandoOInicio.forEach { $0.resume() }
            esperandoOInicio.removeAll()
        }
    }

    func aguardarInicio() async {
        if resposta != nil { return }
        await withCheckedContinuation { esperandoOInicio.append($0) }
    }

    func concluir() {
        resposta?.resume(returning: ResultadoCandidatura(estado: .pendente, candidaturaID: UUID(), posicaoID: nil, turnoID: nil))
        resposta = nil
    }
}

@MainActor
@Suite("Roteador do profissional entre contas: a candidatura em voo não atravessa a troca de conta", .timeLimit(.minutes(1)))
struct RoteadorEntreContasTests {
    private func vagaSintetica() async throws -> Vaga {
        let duble = ApiClienteEmMemoria()
        return try await duble.detalheDaVaga(id: try #require(try await duble.vagasAbertas(.todas).first).id)
    }

    @Test("A candidatura da conta A ainda em voo não repõe o resultado depois da saída de A e da entrada de B")
    func candidaturaEmVooNaoVoltaDepoisDaTrocaDeConta() async throws {
        let envio = EnvioSegurado()
        let viewModelDeA = CandidaturaViewModel(vaga: try await vagaSintetica(), candidatar: { _ in await envio.enviar() })
        let roteador = RoteadorDoProfissional()
        let candidaturaDeA = Task { await roteador.candidatar(viewModel: viewModelDeA) }
        await envio.aguardarInicio()

        roteador.reiniciarParaOutraConta() // saída de A
        roteador.reiniciarParaOutraConta() // entrada de B
        #expect(roteador.caminho.isEmpty)
        #expect(roteador.candidaturaEmAndamento == nil, "o roteador não guarda a candidatura da conta que saiu")

        await envio.concluir()
        await candidaturaDeA.value

        #expect(roteador.caminho.isEmpty, "o resultado da candidatura de A não aparece para B")
        #expect(roteador.aba == .vagas)
    }

    @Test("Depois da troca de conta, a candidatura de B não é barrada pela de A que ainda está em voo")
    func candidaturaDeBNaoEBarradaPelaDeA() async throws {
        let envioDeA = EnvioSegurado()
        let viewModelDeA = CandidaturaViewModel(vaga: try await vagaSintetica(), candidatar: { _ in await envioDeA.enviar() })
        let roteador = RoteadorDoProfissional()
        let candidaturaDeA = Task { await roteador.candidatar(viewModel: viewModelDeA) }
        await envioDeA.aguardarInicio()
        roteador.reiniciarParaOutraConta()

        let vagaDeB = try await vagaSintetica()
        let viewModelDeB = CandidaturaViewModel(vaga: vagaDeB, candidatar: { _ in
            ResultadoCandidatura(estado: .pendente, candidaturaID: UUID(), posicaoID: nil, turnoID: nil)
        })
        await roteador.candidatar(viewModel: viewModelDeB)
        let candidaturaDeB = try #require(viewModelDeB.candidaturaPendente)
        #expect(roteador.caminho == [.resultado(vaga: vagaDeB, resultado: .pendente(candidaturaID: candidaturaDeB))])

        // A resposta de A chega por último e não troca a tela de B.
        await envioDeA.concluir()
        await candidaturaDeA.value
        #expect(roteador.caminho == [.resultado(vaga: vagaDeB, resultado: .pendente(candidaturaID: candidaturaDeB))])
    }

    @Test("Sem troca de conta, voltar para a lista não perde a candidatura em voo: o resultado abre quando chega")
    func semTrocaDeContaOResultadoAbre() async throws {
        let envio = EnvioSegurado()
        let vaga = try await vagaSintetica()
        let viewModel = CandidaturaViewModel(vaga: vaga, candidatar: { _ in await envio.enviar() })
        let roteador = RoteadorDoProfissional()
        let candidatura = Task { await roteador.candidatar(viewModel: viewModel) }
        await envio.aguardarInicio()

        roteador.voltarParaLista()
        await envio.concluir()
        await candidatura.value

        let pendente = try #require(viewModel.candidaturaPendente)
        #expect(roteador.caminho == [.resultado(vaga: vaga, resultado: .pendente(candidaturaID: pendente))])
    }
}
