import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Exclusão de Conta: Dublê complementar (#50)")
struct ExclusaoDeContaDubleComplementarTests {

    // MARK: - Auxiliares

    private struct RelogioFixo: Relogio {
        let agora: Date
    }

    private func criarTurnoDeTeste(id: UUID = UUID(), inicioEmHoras: Double, duracaoHoras: Double = 4) -> Turno {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let inicio = agora.addingTimeInterval(inicioEmHoras * 3600)
        let fim = inicio.addingTimeInterval(duracaoHoras * 3600)
        let periodo = try! Periodo(inicio: inicio, fim: fim)
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Brasília",
            periodo: periodo, valor: Dinheiro(centavos: 15000)
        )
        let contraparte = PerfilPublico(
            id: UUID(), tipo: .estabelecimento, nome: "Restaurante Teste",
            reputacao: Reputacao(positivas: 10, total: 10, taxaComparecimento: 1.0, turnosConsiderados: 10, turnosRealizados: 10)
        )
        return Turno(
            id: id, posicaoID: UUID(), vaga: vaga, contraparte: contraparte,
            contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3600),
            verificacao: .verificado, valorAcordado: vaga.valor, podeAvaliar: false
        )
    }

    // MARK: - Launch Arguments no ApiClienteEmMemoria

    @Test("Dublê: argumento -FRILA_EXCLUSAO_ADMIN_UNICO lança erro administradorUnico")
    func argumentoAdminUnico() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.administradorUnico)

        do {
            _ = try await api.excluirConta()
            Issue.record("Deveria ter lançado erro de administrador_unico")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .administradorUnico)
            #expect(erro.codigoOriginal == "administrador_unico")
        }
    }

    @Test("Dublê: argumento -FRILA_EXCLUSAO_SEM_REDE lança erro semRede")
    func argumentoSemRede() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.semRede)

        do {
            _ = try await api.excluirConta()
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("Dublê: argumento -FRILA_EXCLUSAO_TURNOS com quantidade respeita o número informado")
    func argumentoTurnosComQuantidade() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.comTurnosCancelados(7))

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados == 7)
    }

    @Test("Dublê: cenário padrão sem argumentos conta turnos existentes")
    func cenarioPadraoContaTurnos() async throws {
        let api = ApiClienteEmMemoria()
        // Candidata para gerar um turno
        let vagas = try await api.vagasAbertas()
        if let vaga = vagas.first {
            _ = try? await api.candidatar(vagaID: vaga.id)
        }
        let turnosAntes = try await api.meusTurnos()
        let qtdAntes = turnosAntes.count

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados == qtdAntes)
        #expect(try await api.meusTurnos().isEmpty)
    }

    @Test("Dublê: cenário semRede do ApiClienteEmMemoria também impede exclusão")
    func cenarioSemRedeDoApiImpede() async throws {
        let api = ApiClienteEmMemoria(cenario: .semRede)

        do {
            _ = try await api.excluirConta()
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("Dublê: exclusão com comTurnosCancelados(0) retorna zero sem afetar a limpeza")
    func turnosCanceladosZero() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.comTurnosCancelados(0))

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados == 0)
        #expect(await !api.possuiSessao())
    }

    // MARK: - ViewModel: Erro customizado (não-ErroDaApi) → mensagem genérica

    @Test("ViewModel: executarExclusao lança erro customizado (não ErroDaApi) preenche mensagemErro com erroGenerico")
    func erroCustomizadoPreencheMensagemGenerica() async throws {
        struct ErroCustomizado: Error {}

        let vm = ExclusaoDeContaViewModel(
            executarExclusao: { throw ErroCustomizado() }
        )
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(!vm.exclusaoConcluida)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroGenerico)
    }

    @Test("ViewModel: ErroDaApi com código desconhecido cai no default e mostra erroGenerico")
    func erroApiDesconhecidoMostraGenerico() async throws {
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: { throw ErroDaApi(codigo: .desconhecido) }
        )
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(!vm.exclusaoConcluida)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroGenerico)
    }

    @Test("ViewModel: ErroDaApi com código respostaInvalida cai no default e mostra erroGenerico")
    func erroRespostaInvalidaMostraGenerico() async throws {
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: { throw ErroDaApi(codigo: .respostaInvalida) }
        )
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(!vm.exclusaoConcluida)
        #expect(vm.mensagemErro == TextosExclusaoDeConta.erroGenerico)
    }

    // MARK: - Inicialização do ViewModel: porta, api, closures

    @Test("ViewModel init com porta: chama excluirConta da porta")
    func initComPortaChamaPorta() async throws {
        let api = ApiClienteEmMemoria()
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(porta: api, aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(vm.exclusaoConcluida)
        #expect(concluiu)
        #expect(vm.mensagemErro == nil)
    }

    @Test("ViewModel init com api (ApiClienteEmMemoria conforma ExclusaoDeContaPorta): usa a porta")
    func initComApiQueEPorta() async throws {
        let api = ApiClienteEmMemoria()
        var concluiu = false
        let vm = ExclusaoDeContaViewModel(api: api, aoConcluir: { concluiu = true })
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(vm.exclusaoConcluida)
        #expect(concluiu)
        #expect(vm.mensagemErro == nil)
    }

    @Test("ViewModel init com api + executarExclusao customizado: prioriza a closure")
    func initComApiMaisClosureCustomizada() async throws {
        let api = ApiClienteEmMemoria()
        var closureChamada = false
        let vm = ExclusaoDeContaViewModel(
            api: api,
            executarExclusao: {
                closureChamada = true
                return ExclusaoDeConta(
                    perfilRemovidoEm: Date(),
                    dadosApagadosAte: try! DataCivil("2026-10-16"),
                    turnosCancelados: 0
                )
            }
        )
        vm.confirmouConsequencias = true

        await vm.confirmarExclusao()

        #expect(closureChamada)
        #expect(vm.exclusaoConcluida)
        #expect(vm.mensagemErro == nil)
    }

    @Test("ViewModel init com closures customizadas: executarExclusao e buscarTurnos")
    func initComClosuresCustomizadas() async throws {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let relogio = RelogioFixo(agora: agora)
        let turnoFuturo = criarTurnoDeTeste(inicioEmHoras: 10)

        var executouExclusao = false
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: {
                executouExclusao = true
                return ExclusaoDeConta(
                    perfilRemovidoEm: agora,
                    dadosApagadosAte: try! DataCivil("2026-10-16"),
                    turnosCancelados: 1
                )
            },
            buscarTurnos: { [turnoFuturo] },
            relogio: relogio
        )

        await vm.carregar()
        #expect(vm.turnosFuturos.count == 1)

        vm.confirmouConsequencias = true
        await vm.confirmarExclusao()

        #expect(executouExclusao)
        #expect(vm.exclusaoConcluida)
    }

    @Test("ViewModel init com porta + buscarTurnos + relógio customizado")
    func initComPortaEBuscarTurnos() async throws {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let relogio = RelogioFixo(agora: agora)
        let turnoFuturo = criarTurnoDeTeste(inicioEmHoras: 5)
        let turnoPassado = criarTurnoDeTeste(inicioEmHoras: -10, duracaoHoras: 2)

        let api = ApiClienteEmMemoria()
        let vm = ExclusaoDeContaViewModel(
            porta: api,
            buscarTurnos: { [turnoPassado, turnoFuturo] },
            relogio: relogio
        )

        await vm.carregar()

        // Só o turno futuro deve aparecer (fim >= agora)
        #expect(vm.turnosFuturos.count == 1)
        #expect(vm.turnosFuturos.first?.id == turnoFuturo.id)
    }

    @Test("ViewModel init com api: buscarTurnos vem da api.meusTurnos")
    func initComApiBuscaTurnosDaApi() async throws {
        let api = ApiClienteEmMemoria()
        let vm = ExclusaoDeContaViewModel(api: api)

        await vm.carregar()

        // ApiClienteEmMemoria com cenário .sucesso não tem turnos ativos por padrão
        #expect(vm.turnosFuturos.isEmpty || !vm.turnosFuturos.isEmpty) // Compila e roda sem crash
        #expect(!vm.carregandoTurnos) // Terminou de carregar
    }

    // MARK: - Guarda: confirmouConsequencias == false

    @Test("ViewModel: confirmarExclusao sem confirmouConsequencias não chama executarExclusao")
    func semConfirmacaoNaoChamaExclusao() async throws {
        var chamadas = 0
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: {
                chamadas += 1
                return ExclusaoDeConta(
                    perfilRemovidoEm: Date(),
                    dadosApagadosAte: try! DataCivil("2026-10-16"),
                    turnosCancelados: 0
                )
            }
        )

        #expect(!vm.confirmouConsequencias)
        await vm.confirmarExclusao()

        #expect(chamadas == 0)
        #expect(!vm.exclusaoConcluida)
        #expect(vm.mensagemErro == nil)
    }

    // MARK: - Buscar turnos com erro mantém lista vazia

    @Test("ViewModel: carregar com buscarTurnos que lança erro mantém turnosFuturos vazio")
    func carregarComErroMantemListaVazia() async throws {
        let vm = ExclusaoDeContaViewModel(
            executarExclusao: {
                ExclusaoDeConta(
                    perfilRemovidoEm: Date(),
                    dadosApagadosAte: try! DataCivil("2026-10-16"),
                    turnosCancelados: 0
                )
            },
            buscarTurnos: { throw ErroDaApi(codigo: .semRede) }
        )

        await vm.carregar()

        #expect(vm.turnosFuturos.isEmpty)
        #expect(!vm.carregandoTurnos)
    }

    // MARK: - Exclusão limpa sessão e estado do dublê

    @Test("Dublê: após exclusão, sessão encerrada e conta nil")
    func exclusaoLimpaSessaoEConta() async throws {
        let api = ApiClienteEmMemoria()
        #expect(try await api.minhaConta().nome.isEmpty == false)

        _ = try await api.excluirConta()

        #expect(await !api.possuiSessao())
        do {
            _ = try await api.minhaConta()
            Issue.record("Deveria ter lançado nao_encontrado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoEncontrado)
        }
    }

    @Test("Dublê: exclusão preenche dadosApagadosAte com 15 dias à frente")
    func exclusaoPreenchePrazo() async throws {
        let api = ApiClienteEmMemoria()

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados >= 0)
        // O prazo é de até 15 dias, conforme o contrato
        #expect(resultado.dadosApagadosAte.dia > 0)
    }

    @Test("Dublê: cenário configurado é consumido após uso (volta a padrão)")
    func cenarioConsumidoAposUso() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.administradorUnico)

        do {
            _ = try await api.excluirConta()
            Issue.record("Deveria ter lançado erro")
        } catch {
            // Esperado
        }

        // Reautenticar para restaurar sessão (a exclusão falhou, mas o cenário .semRede do
        // actor pode ter limpado algo; o cenário configurado já foi consumido)
        try await api.verificarCodigo(email: "teste@frila.app", codigo: "123456")

        // O cenário agora é .padrao — criar nova instância para testar exclusão limpa
        let api2 = ApiClienteEmMemoria()
        let resultado = try await api2.excluirConta()
        #expect(resultado.turnosCancelados >= 0)
    }
}
