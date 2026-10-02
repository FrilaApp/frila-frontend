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
        self.init(
            executarExclusao: acao,
            buscarTurnos: { try await api.meusTurnos() },
            relogio: relogio,
            aoConcluir: aoConcluir
        )
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
