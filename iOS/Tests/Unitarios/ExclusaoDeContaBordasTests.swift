import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct RelogioFixo: Relogio {
    let agora: Date
}

/// Contratante com um estabelecimento cujo painel tem uma posição confirmada sem o perfil do
/// profissional (o servidor pode omiti-lo) e uma posição já cancelada.
private final class ApiDoContratante: ApiClienteEncaminhador, @unchecked Sendable {
    let agora: Date
    let estabelecimentoID = UUID()
    init(agora: Date) {
        self.agora = agora
        super.init(base: ApiClienteEmMemoria(cenario: .contratante))
    }

    override func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] {
        [EstabelecimentoDaConta(id: estabelecimentoID, nome: "Bistrô Ipê", papel: .administrador)]
    }

    override func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        let futura = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "CLS 405", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: agora.addingTimeInterval(48 * 3_600), fim: agora.addingTimeInterval(52 * 3_600)),
            valor: Dinheiro(centavos: 18000)
        )
        return Painel(estabelecimentoID: id, vagas: [
            VagaNoPainel(vaga: futura, modo: .urgencia, estado: .preenchida, alertaVagaVazia: false, candidatosPendentes: 0, posicoes: [
                PosicaoNoPainel(id: UUID(), estado: .confirmada, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false),
                PosicaoNoPainel(id: UUID(), estado: .cancelada, profissional: nil, turnoID: UUID(), verificacao: nil, emAtraso: false),
            ]),
        ], checkinsPendentes: [])
    }
}

/// Um cliente que não implementa a porta de exclusão: a tela não pode excluir por ele.
private final class ApiSemPortaDeExclusao: ApiClienteEncaminhador, @unchecked Sendable {}

/// As bordas da exclusão de conta que `ExclusaoDeContaViewModelTests` não exercita.
@MainActor
@Suite("Exclusão de conta: bordas da consulta de turnos e da porta de exclusão")
struct ExclusaoDeContaBordasTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)

    @Test("Consulta do contratante: posição confirmada sem perfil vira turno com contraparte 'Profissional'; a cancelada fica de fora")
    func consultaDoContratanteSemPerfil() async throws {
        let api = ApiDoContratante(agora: agora)

        let turnos = try await ExclusaoDeContaViewModel.buscarTurnosContratante(api: api, relogio: RelogioFixo(agora: agora))

        #expect(turnos.count == 1)
        let turno = try #require(turnos.first)
        #expect(turno.contraparte.nome == "Profissional")
        #expect(turno.contraparte.tipo == .profissional)
        #expect(turno.id == turno.posicaoID, "sem turno_id, o id da posição identifica o turno")
        #expect(turno.verificacao == .pendente)
        #expect(turno.contato == nil)
        #expect(turno.valorAcordado == Dinheiro(centavos: 18000))
    }

    @Test("Com a busca de turnos injetada, a lista não é marcada como limitada")
    func buscaInjetadaNaoEhLimitada() async {
        let vm = ExclusaoDeContaViewModel(api: ApiClienteEmMemoria(cenario: .sucesso), buscarTurnos: { [] }, relogio: RelogioFixo(agora: agora))

        await vm.carregar()

        #expect(vm.avisoListaTurnos == nil)
        #expect(!vm.listaTurnosIndisponivel)
        #expect(vm.turnosFuturos.isEmpty)
    }

    @Test("Cliente sem a porta de exclusão: confirmar não exclui e mostra a mensagem genérica")
    func clienteSemPorta() async {
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(api: ApiSemPortaDeExclusao(), buscarTurnos: { [] }, relogio: RelogioFixo(agora: agora), aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(!vm.exclusaoConcluida)
        #expect(!concluiu)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroGenerico)
        #expect(!vm.excluindo)
    }

    @Test("Sem confirmar as consequências, confirmar não chama a exclusão")
    func semConfirmarAsConsequencias() async {
        let chamadas = Contador()
        let vm = ExclusaoDeContaViewModel(
            api: ApiClienteEmMemoria(cenario: .sucesso),
            executarExclusao: { chamadas.contar(); throw ErroDaApi(codigo: .desconhecido) },
            buscarTurnos: { [] }, relogio: RelogioFixo(agora: agora)
        )

        await vm.confirmarExclusao()

        #expect(chamadas.total == 0)
        #expect(vm.mensagemErro == nil)
    }
}

private final class Contador: @unchecked Sendable {
    private let trava = NSLock()
    private var valor = 0
    var total: Int { trava.withLock { valor } }
    func contar() { trava.withLock { valor += 1 } }
}
