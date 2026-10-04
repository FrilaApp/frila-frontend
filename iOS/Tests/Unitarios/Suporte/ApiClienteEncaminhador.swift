import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Base dos dublês de teste que conformam a `ApiCliente`: encaminha todas as operações da porta
/// para um `ApiClienteEmMemoria`. O dublê herda desta classe e sobrescreve só o que quer espiar ou
/// trocar. Operação nova na porta ganha o encaminhamento aqui, uma vez, e nenhum dublê quebra.
///
/// A subclasse que guarda estado mutável repete `@unchecked Sendable` e protege esse estado.
/// Para partir de outro cenário, ela sobrescreve o `init(base:)` com outro valor padrão.
class ApiClienteEncaminhador: ApiCliente, @unchecked Sendable {
    let base: ApiClienteEmMemoria

    init(base: ApiClienteEmMemoria = ApiClienteEmMemoria()) {
        self.base = base
    }

    // Entrada
    func solicitarCodigo(email: String) async throws { try await base.solicitarCodigo(email: email) }
    func verificarCodigo(email: String, codigo: String) async throws { try await base.verificarCodigo(email: email, codigo: codigo) }
    func entrarDemonstracao(email: String, codigo: String) async throws { try await base.entrarDemonstracao(email: email, codigo: codigo) }
    func possuiSessao() async -> Bool { await base.possuiSessao() }

    // Conta e perfil
    func minhaConta() async throws -> Conta { try await base.minhaConta() }
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta { try await base.criarConta(cadastro) }
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional { try await base.criarPerfilProfissional(dados) }
    func meuPerfilProfissional() async throws -> PerfilProfissional { try await base.meuPerfilProfissional() }
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional { try await base.atualizarPerfilProfissional(alteracao) }

    // Estabelecimento
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento { try await base.cadastrarEstabelecimento(cadastro) }
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] { try await base.meusEstabelecimentos() }
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel { try await base.painelEstabelecimento(id: id, periodo: periodo) }

    // Catálogo e vagas
    func funcoes() async throws -> [Funcao] { try await base.funcoes() }
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada { try await base.publicarVaga(publicacao) }
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada { try await base.republicarVaga(id: id, periodo: periodo, chave: chave) }
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] { try await base.vagasAbertas(filtro) }
    func detalheDaVaga(id: UUID) async throws -> Vaga { try await base.detalheDaVaga(id: id) }
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura { try await base.candidatar(vagaID: vagaID) }
    func perfilPublico(id: UUID) async throws -> PerfilPublico { try await base.perfilPublico(id: id) }

    // Modo seleção
    func candidatosDaVaga(id: UUID) async throws -> [Candidato] { try await base.candidatosDaVaga(id: id) }
    func escolherCandidato(candidaturaID: UUID) async throws -> ResultadoConfirmacao { try await base.escolherCandidato(candidaturaID: candidaturaID) }
    func retirarCandidatura(id: UUID) async throws -> Candidatura { try await base.retirarCandidatura(id: id) }
    func minhasCandidaturas(estado: EstadoCandidatura?) async throws -> [Candidatura] { try await base.minhasCandidaturas(estado: estado) }

    // Turno
    func meusTurnos() async throws -> [Turno] { try await base.meusTurnos() }
    /// A `ler` da porta tem implementação padrão, que não é despachada pela subclasse: fica aqui para
    /// poder ser sobrescrita. Chama o `meusTurnos` deste objeto, e não o da base.
    func ler() async throws -> LeituraDeTurnos { LeituraDeTurnos(turnos: try await meusTurnos(), origem: .rede) }
    func contatoDoTurno(id: UUID) async throws -> Contato { try await base.contatoDoTurno(id: id) }
    func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho { try await base.avisarACaminho(turnoID: turnoID) }
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await base.fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await base.fazerCheckout(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao { try await base.avaliar(turnoID: turnoID, resposta: resposta) }

    // Turno do contratante
    func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro { try await base.confirmarCheckinManual(turnoID: turnoID) }
    func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento { try await base.reabrirPorAtraso(posicaoID: posicaoID) }

    // Cancelamento
    func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento { try await base.cancelarPosicao(id: id, motivo: motivo) }
    func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada { try await base.cancelarVaga(id: id, motivo: motivo) }

    // Confiança e direitos
    func denunciar(_ denuncia: Denuncia) async throws -> Protocolo { try await base.denunciar(denuncia) }
    func bloquear(_ alvo: Alvo) async throws -> Bloqueio { try await base.bloquear(alvo) }
    func situacaoDaConta() async throws -> SituacaoDaConta { try await base.situacaoDaConta() }
    func contestarSuspensao(relato: String) async throws -> Protocolo { try await base.contestarSuspensao(relato: relato) }
    func exportarMeusDados() async throws -> Data { try await base.exportarMeusDados() }
    func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos { try await base.exportarTurnos(pedido) }

    // Aplicativo e dispositivo
    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }
    func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo { try await base.registrarDispositivo(tokenFCM: tokenFCM) }
    func removerDispositivo(tokenFCM: String) async throws { try await base.removerDispositivo(tokenFCM: tokenFCM) }
    func sair(tokenFCM: String?) async { await base.sair(tokenFCM: tokenFCM) }
}

/// Dublê mínimo, do jeito que a base é usada: sobrescreve uma operação e herda o resto.
private final class ApiSemTurnos: ApiClienteEncaminhador, @unchecked Sendable {
    override func meusTurnos() async throws -> [Turno] { [] }
}

@Suite("Base encaminhadora dos dublês de ApiCliente")
struct ApiClienteEncaminhadorTests {
    @Test("O que a subclasse não sobrescreve vai para o dublê em memória, inclusive as RPCs da Sprint 2")
    func encaminha() async throws {
        let base = ApiClienteEmMemoria()
        let api: any ApiCliente = ApiClienteEncaminhador(base: base)

        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)

        #expect(await base.chamadasACandidatar == 1)
        #expect(try await api.meusTurnos().map(\.id) == [turnoID])
        #expect(try await api.ler().turnos.map(\.id) == [turnoID])
        #expect(try await api.situacaoDaConta() == SituacaoDaConta(estado: .ativa, suspensao: nil))
        await #expect(throws: ErroDaApi(codigo: .checkinPendente)) { try await api.confirmarCheckinManual(turnoID: turnoID) }
    }

    @Test("A operação sobrescrita vale pela porta, e a leitura de turnos passa por ela")
    func sobrescreve() async throws {
        let base = ApiClienteEmMemoria()
        let api: any ApiCliente = ApiSemTurnos(base: base)
        let vaga = try #require(try await api.vagasAbertas().first)
        _ = try await api.candidatar(vagaID: vaga.id)

        #expect(try await base.meusTurnos().count == 1)
        #expect(try await api.meusTurnos().isEmpty)
        #expect(try await api.ler().turnos.isEmpty)
    }
}
