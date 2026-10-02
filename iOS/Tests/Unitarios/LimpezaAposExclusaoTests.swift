import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Limpeza após exclusão de conta e dublê em memória (#50)")
struct LimpezaAposExclusaoTests {

    private func criarArmazenamentoLocal() throws -> ArmazenamentoSwiftData {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        return ArmazenamentoSwiftData(modelContainer: container)
    }

    private func popularDadosLocais(no local: ArmazenamentoSwiftData, instante: Date) async throws -> Turno {
        let inicio = instante.addingTimeInterval(3_600)
        let fim = inicio.addingTimeInterval(3_600)
        let resumo = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 12_000)
        )
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = Contato(
            nome: "Bistrô",
            telefone: "+5561999990000",
            whatsappURL: URL(string: "https://wa.me/5561999990000")!,
            visivelAte: visivelAte
        )
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: resumo,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1)),
            contatoVisivelAte: visivelAte, verificacao: .pendente, valorAcordado: resumo.valor, podeAvaliar: false,
            contato: contato
        )
        try await local.salvar(sessao: SessaoUsuario(usuarioID: UUID(), perfil: .profissional))
        try await local.salvar(turnos: [turno], em: instante)
        try await local.salvar(funcoes: [Funcao(id: UUID(), nome: "Garçom", categoria: "Restaurante")])
        try await local.enfileirar(AcaoPendente(tipo: .checkin, turnoID: turno.id, instanteDoToque: instante, chave: UUID(), distanciaMetros: 20))
        DestinoGuardado.salvar(.profissional)
        return turno
    }

    @Test("Limpeza: Sucesso na exclusão apaga cache, fila, destino guardado e encerra sessão (Critério 2)")
    func sucessoLimpaAparelho() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante)

        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(DestinoGuardado.obter() == .profissional)

        let api = ApiClienteEmMemoria()
        let saida = SaidaDaConta(api: api, armazenamento: local)

        let resultado = try await saida.excluir()
        #expect(resultado.turnosCancelados >= 0)

        // Verificações de limpeza
        #expect(DestinoGuardado.obter() == nil)
        #expect(try await local.sessao() == nil)
        #expect(try await local.turnosValidos(em: instante).isEmpty)
        #expect(try await local.funcoes().isEmpty)
        #expect(try await local.pendentes().isEmpty)
        #expect(await !api.possuiSessao())
    }

    @Test("Cuidado crítico: Erro de rede na exclusão NÃO limpa cache, fila nem sessão")
    func erroDeRedeNaoLimpaAparelho() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante)

        let api = ApiClienteEmMemoria(cenario: .semRede)
        let saida = SaidaDaConta(api: api, armazenamento: local)

        do {
            _ = try await saida.excluir()
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }

        // Nada pode ser apagado se o servidor não confirmou a exclusão!
        #expect(DestinoGuardado.obter() == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(try await !local.funcoes().isEmpty)
    }

    @Test("Cuidado crítico: Erro 409 administrador_unico NÃO limpa cache, fila nem sessão")
    func erroAdministradorUnicoNaoLimpaAparelho() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante)

        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.administradorUnico)
        let saida = SaidaDaConta(api: api, armazenamento: local)

        do {
            _ = try await saida.excluir()
            Issue.record("Deveria ter lançado erro de administrador_unico")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .administradorUnico)
        }

        // Nada pode ser apagado se o servidor recusou com conflito!
        #expect(DestinoGuardado.obter() == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
    }

    @Test("Dublê em memória: após exclusão, minhaConta responde como primeiro acesso (Critério 3)")
    func reentradaAposExclusaoComecaCadastroDoZero() async throws {
        let api = ApiClienteEmMemoria()

        // Antes da exclusão, a conta existe
        let contaAntes = try await api.minhaConta()
        #expect(!contaAntes.nome.isEmpty)

        // Exclui a conta
        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados >= 0)
        #expect(await !api.possuiSessao())

        // Chamada direta a minhaConta responde 404 nao_encontrado (primeiro acesso)
        do {
            _ = try await api.minhaConta()
            Issue.record("Deveria ter lançado nao_encontrado (primeiro acesso)")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoEncontrado)
        }

        // Entrar de novo com o mesmo e-mail (simula re-autenticação)
        try await api.verificarCodigo(email: contaAntes.email, codigo: "123456")
        #expect(await api.possuiSessao())

        // Destino da conta direciona para cadastro
        let destino = try await DestinoDaConta.avaliar(api: api)
        if case .cadastro = destino {
            // Sucesso: direcionado para cadastro!
        } else {
            Issue.record("Deveria ter direcionado para cadastro após exclusão, mas foi para \(destino)")
        }
    }

    @Test("Dublê em memória: cenário com turnos cancelados cancela turnos futuros")
    func dubleCenarioTurnosCancelados() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.comTurnosCancelados(4))

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados == 4)
        #expect(try await api.meusTurnos().isEmpty)
    }
}
