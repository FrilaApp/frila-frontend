import FrilaDominio
import Foundation
import Observation

/// Por que a pessoa não pôde entrar na vaga.
public enum MotivoInelegivel: Hashable, Sendable {
    /// Já há turno dela no mesmo horário. O servidor não diz qual, e o app não tenta adivinhar: `meus_turnos`
    /// também traz turnos de posições canceladas e o `Turno` não tem estado.
    case turnoSobreposto
    case funcaoIncompativel
    case outro(detalhes: String?)
}

/// O que a candidatura deu. Tudo vem do código do erro e dos `details`, nunca do texto da mensagem.
public enum ResultadoDaCandidatura: Equatable, Sendable {
    case confirmada(turnoID: UUID?, contato: Contato?)
    /// Vaga de seleção (contrato 0.2.24): a candidatura foi enviada e espera a escolha da casa. Não
    /// há posição, turno nem contato; o id é o que `retirar_candidatura` pede.
    case pendente(candidaturaID: UUID)
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
    /// Outra candidatura já está sendo enviada pelo roteador (#239).
    case outraEmAndamento

    /// Só recusas recuperáveis ficam no detalhe. Todo resultado definitivo precisa de uma tela
    /// própria, mesmo que a pessoa tenha saído do detalhe enquanto a chamada terminava.
    var abreTelaPropria: Bool {
        switch self {
        case .naoEncontrada, .falha, .outraEmAndamento: false
        default: true
        }
    }
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
        case .outraEmAndamento: hasher.combine(7)
        case let .pendente(candidaturaID): hasher.combine(8); hasher.combine(candidaturaID)
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
    /// A candidatura pendente da conta nesta vaga de seleção. `Vaga` não diz se quem chama já se
    /// candidatou (lacuna do contrato): o view model cruza com `minhas_candidaturas` pelo id da vaga.
    public private(set) var candidaturaPendente: UUID?
    /// A conferência da candidatura pendente está em voo: até ela voltar, o botão espera.
    public private(set) var conferindo = false
    private let enviar: @Sendable (UUID) async throws -> ResultadoCandidatura
    private let minhasPendentes: (@Sendable () async throws -> [Candidatura])?

    public convenience init(vaga: Vaga, api: any ApiCliente) {
        self.init(
            vaga: vaga,
            candidatar: { try await api.candidatar(vagaID: $0) },
            minhasPendentes: { try await api.minhasCandidaturas(estado: .pendente) }
        )
    }

    public init(
        vaga: Vaga,
        candidatar: @escaping @Sendable (UUID) async throws -> ResultadoCandidatura,
        minhasPendentes: (@Sendable () async throws -> [Candidatura])? = nil
    ) {
        self.vaga = vaga
        self.enviar = candidatar
        self.minhasPendentes = minhasPendentes
    }

    public var enviando: Bool { estado == .enviando }

    /// Só a vaga de seleção tem candidatura pendente. Se a leitura falha, o botão volta: candidatar-se
    /// de novo devolve a mesma candidatura pendente, sem criar outra (contrato 0.2.24).
    public func conferirCandidatura() async {
        guard vaga.modo == .selecao, let minhasPendentes, !conferindo else { return }
        conferindo = true
        defer { conferindo = false }
        guard let pendentes = try? await minhasPendentes() else { return }
        // Uma candidatura enviada ou retirada enquanto a leitura estava em voo vale mais do que ela.
        guard estado == .ocioso, !retirouAgora else { return }
        candidaturaPendente = pendentes.first { $0.vaga.id == vaga.id }?.id
    }

    /// A pessoa retirou a candidatura pendente: o detalhe volta a oferecer Candidatar-me.
    public func candidaturaRetirada() {
        guard !enviando else { return }
        candidaturaPendente = nil
        retirouAgora = true
        estado = .ocioso
    }

    /// A retirada aconteceu nesta tela: a leitura que saiu antes dela não traz a candidatura de volta.
    private var retirouAgora = false

    public func candidatar(cache: (any CacheLocal)? = nil) async {
        // A troca para `enviando` acontece no MainActor antes do primeiro await: um segundo toque que
        // chegue enquanto a chamada está em voo já vê `enviando` e para aqui.
        guard !enviando else { return }
        estado = .enviando
        let resultado: ResultadoDaCandidatura
        do {
            let resposta = try await enviar(vaga.id)
            if resposta.estado == .confirmada, let turnoID = resposta.turnoID, let contato = resposta.contato {
                try? await cache?.salvar(contato: contato, doTurno: turnoID)
            }
            resultado = Self.resultado(resposta)
        } catch let erro as ErroDaApi {
            resultado = Self.mapear(erro)
        } catch {
            resultado = .falha(ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error))))
        }
        if case let .pendente(candidaturaID) = resultado {
            candidaturaPendente = candidaturaID
            retirouAgora = false
        }
        estado = .concluida(resultado)
    }

    /// Depois de um resultado que fica no detalhe (não encontrada, falha ou outra em andamento), deixa tentar de novo.
    public func recomecar() {
        guard !enviando else { return }
        estado = .ocioso
    }

    /// Chamado pelo roteador quando um toque é ignorado porque outra candidatura já está em voo (#239).
    public func indicarOutroEnvioEmAndamento() {
        guard !enviando else { return }
        estado = .concluida(.outraEmAndamento)
    }

    static func resultado(_ resposta: ResultadoCandidatura) -> ResultadoDaCandidatura {
        switch resposta.estado {
        case .confirmada:
            .confirmada(turnoID: resposta.turnoID, contato: resposta.contato)
        case .pendente:
            .pendente(candidaturaID: resposta.candidaturaID)
        }
    }

    static func mapear(_ erro: ErroDaApi) -> ResultadoDaCandidatura {
        switch (erro.codigo, erro.detalhes) {
        case (.posicaoJaPreenchida, _): return .vagaPreenchida
        case (.vagaEncerrada, _): return .vagaEncerrada
        case (.inelegivel, "turno_sobreposto"): return .inelegivel(.turnoSobreposto)
        case (.inelegivel, "perfil_suspenso"): return .contaSuspensa
        case (.inelegivel, "funcao_incompativel"): return .inelegivel(.funcaoIncompativel)
        case let (.inelegivel, detalhes): return .inelegivel(.outro(detalhes: detalhes))
        case (.semPermissao, "conta_suspensa"): return .contaSuspensa
        case (.naoEncontrado, _): return .naoEncontrada
        default: return .falha(erro)
        }
    }
}
