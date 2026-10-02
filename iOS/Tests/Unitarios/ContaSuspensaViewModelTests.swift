import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Conta Suspensa: View Model (#41)")
struct ContaSuspensaViewModelTests {

    @Test("Cenário 1: Conta suspensa carrega motivo, data e estado de contestação")
    func contaSuspensaCarregaDadosIniciais() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)

        #expect(vm.situacao == nil)
        #expect(vm.protocolo == nil)
        #expect(!vm.emAnalise)
        #expect(vm.podeContestar)

        await vm.carregar()

        #expect(vm.situacao?.estado == .suspensa)
        #expect(vm.motivo == "Denúncia grave confirmada pela Equipe Frila")
        #expect(vm.dataSuspensao != nil)
        #expect(vm.protocolo == nil)
        #expect(!vm.emAnalise)
        #expect(vm.podeContestar)
        #expect(!vm.contaReativada)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Cenário 2: Contestar com sucesso gera protocolo e entra em análise")
    func contestarComSucesso() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)
        await vm.carregar()

        #expect(vm.podeContestar)
        #expect(!vm.mostrarFormularioContestacao)

        vm.abrirFormularioContestacao()
        #expect(vm.mostrarFormularioContestacao)

        vm.relato = "Tenho provas de que a denúncia não procede"
        #expect(vm.relatoValido)

        await vm.enviarContestacao()

        #expect(vm.protocolo != nil)
        #expect(vm.emAnalise)
        #expect(!vm.mostrarFormularioContestacao)
        #expect(!vm.podeContestar)
        #expect(vm.mensagemErro == nil)
        #expect(vm.avisoExplicacao409 == nil)
    }

    @Test("Cenário 3a: 409 contestação já aberta bloqueia segunda tentativa com explicação")
    func contestacaoJaAberta409BloqueiaComExplicacao() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)
        await vm.carregar()

        // Primeira contestação com sucesso
        vm.abrirFormularioContestacao()
        vm.relato = "Primeira contestação válida e aceita"
        await vm.enviarContestacao()
        #expect(vm.protocolo != nil)
        #expect(vm.emAnalise)
        #expect(!vm.podeContestar)

        // Segunda tentativa na tela é bloqueada (não abre formulário)
        vm.abrirFormularioContestacao()
        #expect(!vm.mostrarFormularioContestacao)

        // O backend/dublê recusa nova contestação com 409 contestacao_ja_aberta
        do {
            _ = try await api.contestarSuspensao(relato: "Tentativa de reenvio direto")
            Issue.record("Deveria ter lançado contestacao_ja_aberta")
        } catch let erroApi as ErroDaApi {
            #expect(erroApi.codigo == .contestacaoJaAberta)
        }
    }

    @Test("Cenário 3b: 409 mesmo com contestação == nil (contestação anterior já resolvida no backend)")
    func contestacao409MesmoSemProtocoloAberto() async throws {
        let situacaoSemProtocolo = SituacaoDaConta(
            estado: .suspensa,
            suspensao: Suspensao(
                motivo: "Suspensão com contestação passada já encerrada",
                desde: Date(),
                contestacao: nil
            )
        )

        let vm = ContaSuspensaViewModel(
            situacao: situacaoSemProtocolo,
            obterSituacao: { situacaoSemProtocolo },
            enviarContestacaoAcao: { _ in throw ErroDaApi(codigo: .contestacaoJaAberta) }
        )

        #expect(vm.protocolo == nil)
        #expect(vm.podeContestar)

        vm.abrirFormularioContestacao()
        vm.relato = "Nova tentativa de contestação"
        await vm.enviarContestacao()

        #expect(vm.bloqueadoPor409)
        #expect(vm.avisoExplicacao409 == TextosContaSuspensa.contestacaoJaExiste)
        #expect(!vm.podeContestar)
        #expect(!vm.mostrarFormularioContestacao)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Cenário 4: Relato curto ou vazio é validado antes de enviar")
    func validacaoRelatoCurtoEVazio() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)
        await vm.carregar()

        vm.abrirFormularioContestacao()

        // 1. Relato vazio
        vm.relato = "   "
        #expect(!vm.relatoValido)
        await vm.enviarContestacao()
        #expect(vm.mensagemErro == TextosContaSuspensa.relatoObrigatorio)
        #expect(vm.protocolo == nil)

        // 2. Relato com menos de 10 caracteres
        vm.relato = "Curto!"
        #expect(!vm.relatoValido)
        await vm.enviarContestacao()
        #expect(vm.mensagemErro == TextosContaSuspensa.relatoMinimo)
        #expect(vm.protocolo == nil)
    }

    @Test("Cenário 5: Erro de rede ao contestar exibe mensagem amigável sem travar")
    func erroDeRedeAoContestar() async throws {
        let vm = ContaSuspensaViewModel(
            situacao: SituacaoDaConta(
                estado: .suspensa,
                suspensao: Suspensao(motivo: "Suspenso", desde: Date(), contestacao: nil)
            ),
            obterSituacao: { throw ErroDaApi(codigo: .semRede) },
            enviarContestacaoAcao: { _ in throw ErroDaApi(codigo: .semRede) }
        )

        vm.abrirFormularioContestacao()
        vm.relato = "Relato válido para contestar sem conexão"
        await vm.enviarContestacao()

        #expect(vm.mensagemErro == TextosContaSuspensa.erroSemRede)
        #expect(vm.protocolo == nil)
        #expect(!vm.enviandoContestacao)
        #expect(vm.podeContestar)
    }

    @Test("Cenário 6a: Conta reativada no backend ao recarregar chama aoReativar")
    func contaReativadaNoCarregar() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        var reativou = false
        let vm = ContaSuspensaViewModel(api: api, aoReativar: { reativou = true })

        await vm.carregar()
        #expect(!vm.contaReativada)
        #expect(!reativou)

        // Simula reativação da conta
        await api.reativarConta()
        await vm.carregar()

        #expect(vm.contaReativada)
        #expect(reativou)
        #expect(!vm.podeContestar)
    }

    @Test("Cenário 6b: Conta reativada enquanto tela aberta ao contestar (semSuspensaoAtiva) chama aoReativar")
    func contaReativadaAoContestarSemSuspensaoAtiva() async throws {
        var reativou = false
        let vm = ContaSuspensaViewModel(
            situacao: SituacaoDaConta(
                estado: .suspensa,
                suspensao: Suspensao(motivo: "Suspenso", desde: Date(), contestacao: nil)
            ),
            obterSituacao: {
                SituacaoDaConta(estado: .ativa, suspensao: nil)
            },
            enviarContestacaoAcao: { _ in
                throw ErroDaApi(codigo: .semSuspensaoAtiva)
            },
            aoReativar: { reativou = true }
        )

        vm.abrirFormularioContestacao()
        vm.relato = "Contestando enquanto reativa no backend"
        await vm.enviarContestacao()

        #expect(vm.contaReativada)
        #expect(reativou)
    }

    @Test("Cenário 7: Abertura com contestação já aberta no backend exibe protocolo diretamente")
    func aberturaComContestacaoJaAberta() async throws {
        let protocoloExistente = Protocolo(
            ocorrenciaID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            tipo: .contestacao,
            criadaEm: Date(),
            prazoRespostaAte: try! DataCivil("2026-10-09")
        )
        let situacaoComContestacao = SituacaoDaConta(
            estado: .suspensa,
            suspensao: Suspensao(
                motivo: "Suspensão sob análise",
                desde: Date(),
                contestacao: protocoloExistente
            )
        )

        let vm = ContaSuspensaViewModel(
            situacao: situacaoComContestacao,
            obterSituacao: { situacaoComContestacao },
            enviarContestacaoAcao: { _ in throw ErroDaApi(codigo: .contestacaoJaAberta) }
        )

        #expect(vm.protocolo == protocoloExistente)
        #expect(vm.emAnalise)
        #expect(!vm.podeContestar)
    }

    @Test("Cenário 8: Abrir e cancelar formulário de contestação limpa mensagemErro")
    func abrirECancelarLimpaMensagemErro() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)
        await vm.carregar()

        vm.abrirFormularioContestacao()
        vm.relato = "curto"
        await vm.enviarContestacao()
        #expect(vm.mensagemErro != nil)

        vm.cancelarFormularioContestacao()
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormularioContestacao)

        vm.abrirFormularioContestacao()
        #expect(vm.mensagemErro == nil)
        #expect(vm.mostrarFormularioContestacao)
    }

    @Test("Cenário 9: Relato com espaços nas pontas mas >= 10 caracteres limpos é válido e envia")
    func relatoComEspacosValidoEnvia() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let vm = ContaSuspensaViewModel(api: api)
        await vm.carregar()

        vm.abrirFormularioContestacao()
        vm.relato = "   Dez chars!   "
        #expect(vm.relatoValido)

        await vm.enviarContestacao()

        #expect(vm.protocolo != nil)
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormularioContestacao)
    }

    @Test("Cenário 10: Erro customizado não-API ao contestar resulta em erroGenerico")
    func erroDesconhecidoMostraGenerico() async throws {
        struct ErroCustomizado: Error {}
        let vm = ContaSuspensaViewModel(
            situacao: SituacaoDaConta(
                estado: .suspensa,
                suspensao: Suspensao(motivo: "Suspenso", desde: Date(), contestacao: nil)
            ),
            obterSituacao: {
                SituacaoDaConta(estado: .suspensa, suspensao: Suspensao(motivo: "Suspenso", desde: Date(), contestacao: nil))
            },
            enviarContestacaoAcao: { _ in throw ErroCustomizado() }
        )

        vm.abrirFormularioContestacao()
        vm.relato = "Relato válido com mais de dez caracteres"
        await vm.enviarContestacao()

        #expect(vm.mensagemErro == TextosContaSuspensa.erroGenerico)
        #expect(vm.protocolo == nil)
    }
}

