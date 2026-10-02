import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ExclusaoDeContaViewModel {
    public private(set) var turnosFuturos: [Turno] = []
    public private(set) var carregandoTurnos = false
    public var confirmouConsequencias = false
    public private(set) var excluindo = false
    public private(set) var mensagemErro: String?
    public private(set) var exclusaoConcluida = false

    private let executarExclusao: @Sendable () async throws -> ExclusaoDeConta
    private let buscarTurnos: (@Sendable () async throws -> [Turno])?
    private let aoConcluir: () -> Void
    private let relogio: any Relogio

    public init(
        executarExclusao: @escaping @Sendable () async throws -> ExclusaoDeConta,
        buscarTurnos: (@Sendable () async throws -> [Turno])? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        aoConcluir: @escaping () -> Void = {}
    ) {
        self.executarExclusao = executarExclusao
        self.buscarTurnos = buscarTurnos
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
        let busca: @Sendable () async throws -> [Turno]
        if let buscarTurnos {
            busca = buscarTurnos
        } else {
            busca = {
                let conta = try await api.minhaConta()
                if conta.perfil == .contratante {
                    return try await Self.buscarTurnosContratante(api: api, relogio: relogio)
                }
                return try await api.meusTurnos()
            }
        }
        self.init(
            executarExclusao: acao,
            buscarTurnos: busca,
            relogio: relogio,
            aoConcluir: aoConcluir
        )
    }

    public static func buscarTurnosContratante(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema()
    ) async throws -> [Turno] {
        let estabelecimentos = try await api.meusEstabelecimentos()
        guard !estabelecimentos.isEmpty else { return [] }
        let agora = relogio.agora
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        let de = agora.addingTimeInterval(-86400)
        let ate = calendario.date(byAdding: .year, value: 1, to: agora) ?? agora.addingTimeInterval(365 * 86400)
        guard let periodo = try? Periodo(inicio: de, fim: ate) else {
            return []
        }
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
        return turnos
    }

    public func carregar() async {
        guard let buscarTurnos else { return }
        carregandoTurnos = true
        defer { carregandoTurnos = false }
        do {
            let todos = try await buscarTurnos()
            let agora = relogio.agora
            turnosFuturos = todos
                .filter { $0.vaga.periodo.fim >= agora }
                .sorted { $0.vaga.periodo.inicio < $1.vaga.periodo.inicio }
        } catch {
            // Se falhar ao buscar turnos (ex: offline), mantém lista vazia e não impede ver as consequências
            turnosFuturos = []
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
