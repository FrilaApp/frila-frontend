import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

/// As bordas da tela de conta suspensa que `ContaSuspensaViewModelTests` não exercita: a situação
/// que não carrega (sem rede, erro da API, erro desconhecido), a contestação que chega pela
/// situação, os códigos de validação do servidor e o botão de sair.
@MainActor
@Suite("Conta suspensa: falhas ao carregar, códigos do servidor e saída")
struct ContaSuspensaBordasTests {
    private nonisolated static let agora = Date(timeIntervalSince1970: 1_791_000_000)

    private nonisolated static func suspensa(contestacao: Protocolo? = nil) -> SituacaoDaConta {
        SituacaoDaConta(estado: .suspensa, suspensao: Suspensao(motivo: "Denúncia grave", desde: agora, contestacao: contestacao))
    }

    private nonisolated static func protocolo() throws -> Protocolo {
        Protocolo(ocorrenciaID: UUID(), tipo: .contestacao, criadaEm: agora, prazoRespostaAte: try DataCivil(ano: 2026, mes: 10, dia: 10))
    }

    @Test("Carregar sem rede, com erro da API ou com erro desconhecido mostra a mensagem certa e não muda a situação")
    func carregarComFalhas() async {
        let semRede = ContaSuspensaViewModel(
            situacao: Self.suspensa(), obterSituacao: { throw ErroDaApi(codigo: .semRede) }, enviarContestacaoAcao: { _ in throw ErroQualquer() }
        )
        await semRede.carregar()
        #expect(semRede.mensagemErro == TextosContaSuspensa.erroSemRede)
        #expect(semRede.situacao?.estado == .suspensa)
        #expect(!semRede.carregando)

        let erroDaApi = ContaSuspensaViewModel(
            obterSituacao: { throw ErroDaApi(codigo: .naoAutenticado) }, enviarContestacaoAcao: { _ in throw ErroQualquer() }
        )
        await erroDaApi.carregar()
        #expect(erroDaApi.mensagemErro == TextosContaSuspensa.erroGenerico)

        let desconhecido = ContaSuspensaViewModel(
            obterSituacao: { throw ErroQualquer() }, enviarContestacaoAcao: { _ in throw ErroQualquer() }
        )
        await desconhecido.carregar()
        #expect(desconhecido.mensagemErro == TextosContaSuspensa.erroGenerico)
        #expect(!desconhecido.contaReativada)
    }

    @Test("Carregar com a contestação já aberta no servidor entra em análise e bloqueia nova contestação")
    func carregarComContestacaoAberta() async throws {
        let protocolo = try Self.protocolo()
        let vm = ContaSuspensaViewModel(
            obterSituacao: { Self.suspensa(contestacao: protocolo) }, enviarContestacaoAcao: { _ in throw ErroQualquer() }
        )

        await vm.carregar()

        #expect(vm.protocolo == protocolo)
        #expect(vm.emAnalise)
        #expect(!vm.podeContestar)
    }

    @Test("Contestar: 422 campo_invalido, 422 campo_obrigatorio e sem_rede mostram cada um a sua mensagem; outro código a genérica",
          arguments: [
              (CodigoErroAPI.campoInvalido, TextosContaSuspensa.relatoMinimo),
              (.campoObrigatorio, TextosContaSuspensa.relatoObrigatorio),
              (.semRede, TextosContaSuspensa.erroSemRede),
              (.naoAutenticado, TextosContaSuspensa.erroGenerico),
          ])
    func contestarComCodigosDoServidor(codigo: CodigoErroAPI, mensagem: String) async {
        let vm = ContaSuspensaViewModel(
            situacao: Self.suspensa(), obterSituacao: { Self.suspensa() }, enviarContestacaoAcao: { _ in throw ErroDaApi(codigo: codigo) }
        )
        vm.relato = "Fui suspenso por engano, nunca faltei a um turno."

        await vm.enviarContestacao()

        #expect(vm.mensagemErro == mensagem)
        #expect(vm.protocolo == nil)
        #expect(!vm.enviandoContestacao)
        #expect(vm.podeContestar, "a pessoa pode corrigir e tentar de novo")
    }

    @Test("Sair chama a saída da conta recebida pela tela")
    func sair() {
        var saiu = false
        let vm = ContaSuspensaViewModel(
            situacao: Self.suspensa(), obterSituacao: { Self.suspensa() }, enviarContestacaoAcao: { _ in throw ErroQualquer() },
            sair: { saiu = true }
        )

        vm.executarSair()

        #expect(saiu)
    }

    @Test("Motivo e data vêm da suspensão; sem situação, o motivo é vazio e a data nula")
    func motivoEData() {
        let semSituacao = ContaSuspensaViewModel(obterSituacao: { Self.suspensa() }, enviarContestacaoAcao: { _ in throw ErroQualquer() })
        #expect(semSituacao.motivo == "")
        #expect(semSituacao.dataSuspensao == nil)

        let comSituacao = ContaSuspensaViewModel(situacao: Self.suspensa(), obterSituacao: { Self.suspensa() }, enviarContestacaoAcao: { _ in throw ErroQualquer() })
        #expect(comSituacao.motivo == "Denúncia grave")
        #expect(comSituacao.dataSuspensao == Self.agora)
    }
}
