import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Conta Suspensa: Complementar (#41)")
struct ContaSuspensaViewModelComplementarTests {

    // MARK: - Auxiliares

    private nonisolated static let situacaoSuspensa = SituacaoDaConta(
        estado: .suspensa,
        suspensao: Suspensao(
            motivo: "Denúncia grave confirmada pela Equipe Frila",
            desde: Date(timeIntervalSince1970: 1_700_000_000),
            contestacao: nil
        )
    )

    private func criarVM(
        erroAoContestar: Error? = nil
    ) -> ContaSuspensaViewModel {
        ContaSuspensaViewModel(
            situacao: Self.situacaoSuspensa,
            obterSituacao: { Self.situacaoSuspensa },
            enviarContestacaoAcao: { relato in
                if let erro = erroAoContestar { throw erro }
                return Protocolo(
                    ocorrenciaID: UUID(),
                    tipo: .contestacao,
                    criadaEm: Date(),
                    prazoRespostaAte: try! DataCivil(ano: 2026, mes: 10, dia: 30)
                )
            }
        )
    }

    // MARK: - Testes

    @Test("Abrir e cancelar formulário de contestação limpa mensagemErro")
    func abrirECancelarLimpaMensagemErro() async {
        let vm = criarVM(erroAoContestar: ErroDaApi(codigo: .semRede))

        // Provoca uma mensagemErro via envio com relato válido que falha
        vm.relato = "Relato com mais de dez caracteres"
        vm.abrirFormularioContestacao()
        await vm.enviarContestacao()
        #expect(vm.mensagemErro != nil)

        // Cancelar deve limpar a mensagemErro
        vm.cancelarFormularioContestacao()
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormularioContestacao)

        // Abrir de novo também deve limpar qualquer mensagemErro residual
        // (simula re-abertura após erro anterior ter sido restaurado)
        vm.relato = "Relato curto"
        await vm.enviarContestacao() // não envia porque formulário fechado? Forçar erro:
        vm.abrirFormularioContestacao()
        #expect(vm.mensagemErro == nil)
        #expect(vm.mostrarFormularioContestacao)
    }

    @Test("Relato com espaços nas pontas mas >= 10 caracteres limpos é válido e envia")
    func relatoComEspacosValidoEnvia() async {
        let vm = criarVM()

        vm.abrirFormularioContestacao()
        // 10 caracteres úteis + espaços nas pontas
        vm.relato = "   Dez chars!   "
        #expect(vm.relatoValido)

        await vm.enviarContestacao()

        #expect(vm.protocolo != nil)
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormularioContestacao)
    }

    @Test("Erro desconhecido ao contestar resulta em erroGenerico")
    func erroDesconhecidoMostraGenerico() async {
        struct ErroCustomizado: Error {}
        let vm = criarVM(erroAoContestar: ErroCustomizado())

        vm.abrirFormularioContestacao()
        vm.relato = "Relato válido com mais de dez caracteres"

        await vm.enviarContestacao()

        #expect(vm.mensagemErro == TextosContaSuspensa.erroGenerico)
        #expect(vm.protocolo == nil)
    }
}
