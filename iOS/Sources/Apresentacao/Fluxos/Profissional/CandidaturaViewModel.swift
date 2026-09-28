import FrilaDominio
import Foundation
import Observation

/// Por que a pessoa não pôde entrar na vaga.
public enum MotivoInelegivel: Hashable, Sendable {
    /// Já há turno dela no mesmo horário. O servidor não manda qual; o app procura em `meus_turnos`.
    case turnoSobreposto(conflito: Turno?)
    case funcaoIncompativel
    case outro(detalhes: String?)
}

/// O que a candidatura deu. Tudo vem do código do erro e dos `details`, nunca do texto da mensagem.
public enum ResultadoDaCandidatura: Equatable, Sendable {
    case confirmada(turnoID: UUID?, contato: Contato?)
    /// `409 posicao_ja_preenchida`: alguém chegou antes (RN19). É resultado normal, não erro.
    case vagaPreenchida
    /// `409 vaga_encerrada`: a vaga foi cancelada, encerrada ou o início já passou.
    case vagaEncerrada
    case inelegivel(MotivoInelegivel)
    /// `422 inelegivel/perfil_suspenso` no `candidatar`, ou `403 sem_permissao/conta_suspensa`.
    case contaSuspensa
    /// `404 nao_encontrado`: a vaga não existe mais ou não está visível.
    case naoEncontrada
    case falha(ErroDaApi)
}

/// Hashable à mão para a rota de navegação: `ErroDaApi` é só Equatable no domínio.
extension ResultadoDaCandidatura: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .confirmada(turnoID, contato): hasher.combine(0); hasher.combine(turnoID); hasher.combine(contato)
        case .vagaPreenchida: hasher.combine(1)
        case .vagaEncerrada: hasher.combine(2)
        case let .inelegivel(motivo): hasher.combine(3); hasher.combine(motivo)
        case .contaSuspensa: hasher.combine(4)
        case .naoEncontrada: hasher.combine(5)
        case let .falha(erro): hasher.combine(6); hasher.combine(erro.codigo); hasher.combine(erro.codigoOriginal); hasher.combine(erro.detalhes)
        }
    }
}

public enum EstadoDaCandidatura: Equatable, Sendable {
    case ocioso
    case enviando
    case concluida(ResultadoDaCandidatura)
}

/// Candidatar-me (#105). Um toque por vez: enquanto uma chamada está em voo, outro toque não faz nada,
/// e o botão fica desabilitado. Não entra na fila de sessão do cliente: um 409 não encerra sessão.
@MainActor @Observable
public final class CandidaturaViewModel {
    public let vaga: Vaga
    public private(set) var estado: EstadoDaCandidatura = .ocioso
    private let enviar: @Sendable (UUID) async throws -> ResultadoCandidatura
    private let buscarMeusTurnos: @Sendable () async throws -> [Turno]

    public convenience init(vaga: Vaga, api: any ApiCliente) {
        self.init(vaga: vaga, candidatar: { try await api.candidatar(vagaID: $0) }, meusTurnos: { try await api.meusTurnos() })
    }

    public init(
        vaga: Vaga,
        candidatar: @escaping @Sendable (UUID) async throws -> ResultadoCandidatura,
        meusTurnos: @escaping @Sendable () async throws -> [Turno]
    ) {
        self.vaga = vaga
        self.enviar = candidatar
        self.buscarMeusTurnos = meusTurnos
    }

    public var enviando: Bool { estado == .enviando }

    public func candidatar() async {
        // A troca para `enviando` acontece no MainActor antes do primeiro await: um segundo toque que
        // chegue enquanto a chamada está em voo já vê `enviando` e para aqui.
        guard !enviando else { return }
        estado = .enviando
        let resultado: ResultadoDaCandidatura
        do {
            resultado = Self.resultado(try await enviar(vaga.id))
        } catch let erro as ErroDaApi {
            resultado = await mapear(erro)
        } catch {
            resultado = .falha(ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error))))
        }
        estado = .concluida(resultado)
    }

    /// Depois de um resultado que fica no detalhe (não encontrada ou falha), deixa tentar de novo.
    public func recomecar() {
        guard !enviando else { return }
        estado = .ocioso
    }

    static func resultado(_ resposta: ResultadoCandidatura) -> ResultadoDaCandidatura {
        switch resposta.estado {
        case .confirmada:
            .confirmada(turnoID: resposta.turnoID, contato: resposta.contato)
        case .pendente:
            // Na v1.0 só existe o modo urgência: candidatura pendente não é resultado esperado.
            .falha(ErroDaApi(codigo: .respostaInvalida, codigoOriginal: "candidatura_pendente"))
        }
    }

    private func mapear(_ erro: ErroDaApi) async -> ResultadoDaCandidatura {
        switch (erro.codigo, erro.detalhes) {
        case (.posicaoJaPreenchida, _): return .vagaPreenchida
        case (.vagaEncerrada, _): return .vagaEncerrada
        case (.inelegivel, "turno_sobreposto"): return .inelegivel(.turnoSobreposto(conflito: await conflito()))
        case (.inelegivel, "perfil_suspenso"): return .contaSuspensa
        case (.inelegivel, "funcao_incompativel"): return .inelegivel(.funcaoIncompativel)
        case let (.inelegivel, detalhes): return .inelegivel(.outro(detalhes: detalhes))
        case (.semPermissao, "conta_suspensa"): return .contaSuspensa
        case (.naoEncontrado, _): return .naoEncontrada
        default: return .falha(erro)
        }
    }

    /// O turno da pessoa que ocupa o mesmo horário da vaga. Sem rede ou sem achar, volta nil e a tela
    /// explica sem o link.
    private func conflito() async -> Turno? {
        guard let turnos = try? await buscarMeusTurnos() else { return nil }
        let alvo = vaga.periodo
        return turnos.first { $0.vaga.periodo.inicio < alvo.fim && alvo.inicio < $0.vaga.periodo.fim }
    }
}
