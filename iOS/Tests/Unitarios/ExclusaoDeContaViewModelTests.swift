import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Exclusão de Conta: View Model (#50)")
struct ExclusaoDeContaViewModelTests {

    private final class DublePortaExclusao: ExclusaoDeContaPorta, @unchecked Sendable {
        var resultado: Result<ExclusaoDeConta, Error> = .success(
            ExclusaoDeConta(
                perfilRemovidoEm: Date(),
                dadosApagadosAte: try! DataCivil("2026-10-16"),
                turnosCancelados: 0
            )
        )
        var chamadasExcluir = 0

        func excluirConta() async throws -> ExclusaoDeConta {
            chamadasExcluir += 1
            switch resultado {
            case let .success(res): return res
            case let .failure(erro): throw erro
            }
        }
    }

    private struct RelogioFixo: Relogio {
        let agora: Date
    }

    private func criarTurnoDeTeste(id: UUID = UUID(), inicioEmHoras: Double, duracaoHoras: Double = 4) -> Turno {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let inicio = agora.addingTimeInterval(inicioEmHoras * 3600)
        let fim = inicio.addingTimeInterval(duracaoHoras * 3600)
        let periodo = try! Periodo(inicio: inicio, fim: fim)
        let vaga = VagaResumo(
            id: UUID(),
            funcao: "Garçom",
            local: "Asa Sul",
            regiaoAdministrativa: "Brasília",
            periodo: periodo,
            valor: Dinheiro(centavos: 15000)
        )
        let contraparte = PerfilPublico(
            id: UUID(),
            tipo: .estabelecimento,
            nome: "Restaurante Teste",
            reputacao: Reputacao(positivas: 10, total: 10, taxaComparecimento: 1.0, turnosConsiderados: 10, turnosRealizados: 10)
        )
        return Turno(
            id: id,
            posicaoID: UUID(),
            vaga: vaga,
            contraparte: contraparte,
            contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3600),
            verificacao: .verificado,
            valorAcordado: vaga.valor,
            podeAvaliar: false
        )
    }

    @Test("Cenário 1: Sucesso sem turnos cancelados conclui exclusão e chama callback")
    func sucessoSemTurnosCancelados() async throws {
        let porta = DublePortaExclusao()
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(porta: porta, aoConcluir: { concluiu = true })

        #expect(!vm.confirmouConsequencias)
        #expect(!vm.excluindo)
        #expect(!vm.exclusaoConcluida)

        // Sem confirmar consequências, chamada é ignorada
        await vm.confirmarExclusao()
        #expect(porta.chamadasExcluir == 0)
        #expect(!concluiu)

        // Confirma consequências e executa
        vm.confirmouConsequencias = true
        await vm.confirmarExclusao()

        #expect(porta.chamadasExcluir == 1)
        #expect(vm.exclusaoConcluida)
        #expect(concluiu)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Cenário 2: Sucesso com turnos cancelados conclui normalmente")
    func sucessoComTurnosCancelados() async throws {
        let porta = DublePortaExclusao()
        porta.resultado = .success(
            ExclusaoDeConta(
                perfilRemovidoEm: Date(),
                dadosApagadosAte: try! DataCivil("2026-10-16"),
                turnosCancelados: 3
            )
        )
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(porta: porta, aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(porta.chamadasExcluir == 1)
        #expect(vm.exclusaoConcluida)
        #expect(concluiu)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Cenário 3: 409 administrador_unico exibe mensagem sem apontar transferência")
    func erroAdministradorUnico() async throws {
        let porta = DublePortaExclusao()
        porta.resultado = .failure(ErroDaApi(codigo: .administradorUnico, codigoOriginal: "administrador_unico"))
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(porta: porta, aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(porta.chamadasExcluir == 1)
        #expect(!vm.exclusaoConcluida)
        #expect(!concluiu)
        #expect(vm.mensagemErro != nil)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroAdminUnico)
        // Regra do cartão: NÃO pode apontar para transferência de administração
        #expect(vm.mensagemErro?.lowercased().contains("transfer") == false)
    }

    @Test("Cenário 4: Falha de rede informa que conta não foi excluída e permite tentar de novo")
    func erroFalhaDeRede() async throws {
        let porta = DublePortaExclusao()
        porta.resultado = .failure(ErroDaApi(codigo: .semRede))
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(porta: porta, aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(porta.chamadasExcluir == 1)
        #expect(!vm.exclusaoConcluida)
        #expect(!concluiu)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroSemRede)
        #expect(vm.mensagemErro?.contains("não foi excluída") == true)

        // Pode tentar novamente
        porta.resultado = .success(
            ExclusaoDeConta(
                perfilRemovidoEm: Date(),
                dadosApagadosAte: try! DataCivil("2026-10-16"),
                turnosCancelados: 0
            )
        )
        await vm.confirmarExclusao()

        #expect(porta.chamadasExcluir == 2)
        #expect(vm.exclusaoConcluida)
        #expect(concluiu)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Listagem e filtro de turnos futuros a serem cancelados")
    func listagemDeTurnosFuturos() async throws {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let relogio = RelogioFixo(agora: agora)

        let turnoPassado = criarTurnoDeTeste(inicioEmHoras: -10, duracaoHoras: 2) // Fim antes de agora
        let turnoFuturo1 = criarTurnoDeTeste(inicioEmHoras: 2, duracaoHoras: 4)  // Fim depois de agora
        let turnoFuturo2 = criarTurnoDeTeste(inicioEmHoras: 24, duracaoHoras: 6) // Mais no futuro

        let porta = DublePortaExclusao()
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: { try await porta.excluirConta() },
            buscarTurnos: { [turnoPassado, turnoFuturo2, turnoFuturo1] },
            relogio: relogio
        )

        await vm.carregar()

        #expect(vm.turnosFuturos.count == 2)
        #expect(vm.turnosFuturos[0].id == turnoFuturo1.id)
        #expect(vm.turnosFuturos[1].id == turnoFuturo2.id)
    }

    @Test("Contratante com turnos futuros carrega turnos a serem cancelados dos seus estabelecimentos")
    func contratanteComTurnosFuturosCarregaDoPainel() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let vm = ExclusaoDeContaViewModel(api: api)

        await vm.carregar()

        #expect(!vm.turnosFuturos.isEmpty)
        let turno = try #require(vm.turnosFuturos.first)
        #expect(turno.id == UUID(uuidString: "82000000-0000-0000-0000-000000000001"))
        #expect(turno.posicaoID == UUID(uuidString: "82000000-0000-0000-0000-000000000002"))
        #expect(!turno.vaga.funcao.isEmpty)
    }

    @Test("Contratante sem estabelecimento retorna lista vazia de turnos futuros sem falhar")
    func contratanteSemEstabelecimentoRetornaTurnosVazios() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratanteSemEstabelecimento)
        let vm = ExclusaoDeContaViewModel(api: api)

        await vm.carregar()

        #expect(vm.turnosFuturos.isEmpty)
        #expect(vm.mensagemErro == nil)
    }
}
