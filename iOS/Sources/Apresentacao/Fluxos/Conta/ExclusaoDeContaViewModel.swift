import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ExclusaoDeContaViewModel {
    public private(set) var turnosFuturos: [Turno] = []
    public private(set) var avisoListaTurnos: String?
    public private(set) var listaTurnosIndisponivel = false
    public private(set) var carregandoTurnos = false
    public var confirmouConsequencias = false
    public private(set) var excluindo = false
    public private(set) var mensagemErro: String?
    public private(set) var exclusaoConcluida = false

    private let executarExclusao: @Sendable () async throws -> ExclusaoDeConta
    private struct ConsultaTurnos: Sendable {
        let turnos: [Turno]
        let limitada: Bool
    }

    private let consultarTurnos: (@Sendable () async throws -> ConsultaTurnos)?
    private let aoConcluir: () -> Void
    private let relogio: any Relogio

    public convenience init(
        executarExclusao: @escaping @Sendable () async throws -> ExclusaoDeConta,
        buscarTurnos: (@Sendable () async throws -> [Turno])? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        aoConcluir: @escaping () -> Void = {}
    ) {
        let consulta: (@Sendable () async throws -> ConsultaTurnos)?
        if let buscarTurnos {
            consulta = { ConsultaTurnos(turnos: try await buscarTurnos(), limitada: false) }
        } else {
            consulta = nil
        }
        self.init(
            executarExclusao: executarExclusao,
            consultarTurnos: consulta,
            relogio: relogio,
            aoConcluir: aoConcluir
        )
    }

    private init(
        executarExclusao: @escaping @Sendable () async throws -> ExclusaoDeConta,
        consultarTurnos: (@Sendable () async throws -> ConsultaTurnos)?,
        relogio: any Relogio,
        aoConcluir: @escaping () -> Void
    ) {
        self.executarExclusao = executarExclusao
        self.consultarTurnos = consultarTurnos
        self.relogio = relogio
        self.aoConcluir = aoConcluir
    }

    public convenience init(
        porta: any ExclusaoDeContaPorta,
        buscarTurnos: (@Sendable () async throws -> [Turno])? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        aoConcluir: @escaping () -> Void = {}
    ) {
        self.init(
            executarExclusao: { try await porta.excluirConta() },
            buscarTurnos: buscarTurnos,
            relogio: relogio,
            aoConcluir: aoConcluir
        )
    }

    public convenience init(
        api: any ApiCliente,
        executarExclusao: (@Sendable () async throws -> ExclusaoDeConta)? = nil,
        buscarTurnos: (@Sendable () async throws -> [Turno])? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        aoConcluir: @escaping () -> Void = {}
    ) {
        let acao: @Sendable () async throws -> ExclusaoDeConta
        if let executarExclusao {
            acao = executarExclusao
        } else if let porta = api as? any ExclusaoDeContaPorta {
            acao = { try await porta.excluirConta() }
        } else {
            acao = { throw ErroDaApi(codigo: .respostaInvalida) }
        }
        let busca: @Sendable () async throws -> ConsultaTurnos
        if let buscarTurnos {
            busca = { ConsultaTurnos(turnos: try await buscarTurnos(), limitada: false) }
        } else {
            busca = {
                let conta = try await api.minhaConta()
                if conta.perfil == .contratante {
                    return try await Self.consultarTurnosContratante(api: api, relogio: relogio)
                }
                return ConsultaTurnos(turnos: try await api.meusTurnos(), limitada: false)
            }
        }
        self.init(
            executarExclusao: acao,
            consultarTurnos: busca,
            relogio: relogio,
            aoConcluir: aoConcluir
        )
    }

    public static func buscarTurnosContratante(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema()
    ) async throws -> [Turno] {
        try await consultarTurnosContratante(api: api, relogio: relogio).turnos
    }

    private static func consultarTurnosContratante(api: any ApiCliente, relogio: any Relogio) async throws -> ConsultaTurnos {
        let estabelecimentos = try await api.meusEstabelecimentos()
        guard !estabelecimentos.isEmpty else { return ConsultaTurnos(turnos: [], limitada: false) }
        let agora = relogio.agora
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        let de = agora.addingTimeInterval(-86400)
        let ate = calendario.date(byAdding: .year, value: 1, to: agora) ?? agora.addingTimeInterval(365 * 86400)
        let periodo = try Periodo(inicio: de, fim: ate)
        var turnos: [Turno] = []
        for est in estabelecimentos {
            let painel = try await api.painelEstabelecimento(id: est.id, periodo: periodo)
            for vagaNoPainel in painel.vagas {
                for posicao in vagaNoPainel.posicoes where posicao.estado == .confirmada {
                    let turnoID = posicao.turnoID ?? posicao.id
                    let contraparte = posicao.profissional ?? PerfilPublico(
                        id: UUID(),
                        tipo: .profissional,
                        nome: String(localized: "Profissional", bundle: bundleApresentacao),
                        reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
                    )
                    let turno = Turno(
                        id: turnoID,
                        posicaoID: posicao.id,
                        vaga: vagaNoPainel.vaga,
                        contraparte: contraparte,
                        contatoVisivelAte: vagaNoPainel.vaga.periodo.fim,
                        aCaminhoEm: posicao.aCaminhoEm,
                        checkin: nil,
                        checkout: nil,
                        verificacao: posicao.verificacao ?? .pendente,
                        valorAcordado: vagaNoPainel.vaga.valor,
                        podeAvaliar: false,
                        contato: nil
                    )
                    turnos.append(turno)
                }
            }
        }
        return ConsultaTurnos(turnos: turnos, limitada: true)
    }

    public func carregar() async {
        guard !carregandoTurnos, let consultarTurnos else { return }
        carregandoTurnos = true
        defer { carregandoTurnos = false }
        do {
            let consulta = try await consultarTurnos()
            listaTurnosIndisponivel = false
            avisoListaTurnos = consulta.limitada ? TextosExclusaoDeConta.listaLimitada : nil
            let agora = relogio.agora
            turnosFuturos = consulta.turnos
                .filter { $0.vaga.periodo.inicio > agora }
                .sorted { $0.vaga.periodo.inicio < $1.vaga.periodo.inicio }
        } catch {
            listaTurnosIndisponivel = true
            avisoListaTurnos = TextosExclusaoDeConta.listaIndisponivel
        }
    }

    public func confirmarExclusao() async {
        guard confirmouConsequencias, !excluindo else { return }
        excluindo = true
        mensagemErro = nil
        do {
            _ = try await executarExclusao()
            exclusaoConcluida = true
            aoConcluir()
        } catch let erroApi as ErroDaApi {
            switch erroApi.codigo {
            case .administradorUnico:
                mensagemErro = TextosExclusaoDeConta.erroAdminUnico
            case .semRede:
                mensagemErro = TextosExclusaoDeConta.erroSemRede
            default:
                mensagemErro = TextosExclusaoDeConta.erroGenerico
            }
        } catch {
            mensagemErro = TextosExclusaoDeConta.erroGenerico
        }
        excluindo = false
    }
}
