import Foundation
import FrilaDominio
import Observation

/// A tela que um aviso abre para quem trabalha.
public enum DestinoDoProfissional: Equatable, Sendable {
    /// O detalhe da vaga, ou a tela de vaga indisponível se ela já não aceita candidatura.
    case vaga(UUID)
    /// A lista de vagas.
    case vagas
    /// O turno, com o contato e o registro de presença.
    case turno(UUID)
    case meusTurnos
    case avaliacao(turnoID: UUID)

    /// O destino de cada `tipo`, com os ids que o servidor de fato manda nele. Aviso que não é para
    /// quem trabalha, ou sem o id de que a tela precisa, não abre nada.
    public init?(_ aviso: AvisoDePush) {
        switch aviso.tipo {
        case .vaga, .candidaturaRecusada, .selecaoEncerrada:
            // Recusa e seleção encerrada falam de uma vaga que já não dá para pegar: a mesma rota
            // leva à tela de vaga indisponível, de onde se volta para a lista.
            guard let vagaID = aviso.vagaID else { return nil }
            self = .vaga(vagaID)
        case .vagasAgrupadas:
            self = .vagas
        case .confirmacao, .lembrete24h, .lembrete3h, .inicioSemCheckin, .fimSemCheckout:
            guard let turnoID = aviso.turnoID else { return nil }
            self = .turno(turnoID)
        case .cancelamento:
            // O cancelamento nunca traz `turno_id`. Com `posicao_id`, quem recebe tinha a posição,
            // e o turno cancelado aparece em Meus turnos; sem ele, era candidato de uma vaga
            // recolhida, que não tem turno.
            if aviso.posicaoID != nil {
                self = .meusTurnos
            } else if let vagaID = aviso.vagaID {
                self = .vaga(vagaID)
            } else {
                return nil
            }
        case .avaliacaoDisponivel:
            guard let turnoID = aviso.turnoID else { return nil }
            self = .avaliacao(turnoID: turnoID)
        case .vagaSemElegiveis, .atraso15min, .vagaVazia, .checkin, .checkinManualPendente, .suspensao, .reativacao:
            return nil
        }
    }
}

public enum DestinoDoPush: Equatable, Sendable {
    case profissional(DestinoDoProfissional)
    case contratante(AvisoDoContratante)
    /// `suspensao` e `reativacao`: o app reavalia a conta, e é a situação dela que decide a tela.
    case situacaoDaConta
}

/// Qual fluxo está na tela para a conta que entrou.
public enum FluxoDaConta: Equatable, Sendable {
    case profissional
    case contratante
    /// Conta sem fluxo montado: cadastro por terminar, ou profissional sem funções e horários.
    case nenhum
}

/// Quem está neste aparelho na hora do toque.
public struct ContaNoAparelho: Equatable, Sendable {
    public let contaID: UUID
    public let fluxo: FluxoDaConta
    /// O vínculo do aparelho com a conta, como o `AparelhoDePush` o guarda.
    public let vinculo: VinculoDoAparelho?

    public init(contaID: UUID, fluxo: FluxoDaConta, vinculo: VinculoDoAparelho?) {
        self.contaID = contaID
        self.fluxo = fluxo
        self.vinculo = vinculo
    }
}

public enum DecisaoDoPush: Equatable, Sendable {
    case abrir(DestinoDoPush)
    case ignorar(Motivo)

    public enum Motivo: Equatable, Sendable {
        /// Sem `tipo`, ou com um tipo que este app não conhece.
        case payloadInvalido
        case semSessao
        /// O aparelho não está entregue à conta que está nele, ou o aviso chegou antes de estar.
        case deOutraConta
        /// O tipo não é para o perfil que está na tela, ou veio sem o id de que a tela precisa.
        case semDestino
    }
}

/// O ponto único por onde o toque num push entra (#8). Recebe o payload, confere que o aviso é da
/// conta que está no aparelho e manda para o roteador do profissional ou para o do contratante.
/// Nunca age sozinho: abre a tela, e quem candidata, confirma ou reabre é a pessoa.
///
/// **Push de outra conta.** O payload não diz para quem é o aviso (RN15), então a conferência usa o
/// que o aparelho sabe: a conta à qual ele está entregue no servidor e desde quando
/// (`VinculoDoAparelho`). O aviso entregue antes disso era de quem estava aqui antes, e não abre
/// nada; na troca de conta, "antes disso" inclui a carência depois da confirmação do servidor. Depois disso, o perfil ainda precisa ser o do aviso, e a tela de destino lê os dados com a
/// sessão de quem está no aparelho: o turno ou a vaga de outra conta dá "não encontrado".
@MainActor @Observable
public final class RoteadorDePush {
    private enum Sessao {
        /// O app ainda não sabe se há sessão (abertura a frio pelo toque).
        case desconhecida
        case ausente
        case ativa(ContaNoAparelho)
    }

    private let profissional: RoteadorDoProfissional
    private let contratante: RoteadorDoContratante
    private var sessao = Sessao.desconhecida
    private var pendente: (payload: [String: String], entregueEm: Date)?

    /// Sobe a cada aviso de suspensão ou reativação: quem observa reavalia a conta.
    public private(set) var reavaliacoesDaConta = 0
    /// A última decisão tomada, para os testes e para o diagnóstico.
    public private(set) var ultimaDecisao: DecisaoDoPush?

    public init(profissional: RoteadorDoProfissional, contratante: RoteadorDoContratante) {
        self.profissional = profissional
        self.contratante = contratante
    }

    /// O toque na notificação, com o `userInfo` dela e o instante em que o sistema a entregou.
    /// Com o app recém-aberto pelo toque, a decisão espera a conta ser conhecida e volta `nil`.
    @discardableResult
    public func tocar(payload: [AnyHashable: Any], entregueEm: Date) -> DecisaoDoPush? {
        let campos = Self.campos(payload)
        switch sessao {
        case .desconhecida:
            pendente = (campos, entregueEm)
            return nil
        case .ausente:
            return concluir(.ignorar(.semSessao))
        case let .ativa(conta):
            return concluir(Self.decidir(payload: campos, entregueEm: entregueEm, conta: conta))
        }
    }

    /// Com o app aberto, só é mostrada a notificação que o toque abriria: há sessão, o aparelho
    /// está entregue a ela, a entrega veio depois disso e o aviso tem destino no perfil da conta.
    /// O aviso sem `tipo`, de outro perfil ou de antes do vínculo não ganha faixa nem som.
    public func apresenta(payload: [AnyHashable: Any], entregueEm: Date) -> Bool {
        guard case let .ativa(conta) = sessao else { return false }
        if case .abrir = Self.decidir(payload: Self.campos(payload), entregueEm: entregueEm, conta: conta) { return true }
        return false
    }

    /// A conta que está no aparelho ficou conhecida, ou o vínculo dela mudou. O toque que esperava
    /// por isso é decidido agora.
    public func contaAtiva(_ conta: ContaNoAparelho) {
        sessao = .ativa(conta)
        guard let pendente else { return }
        self.pendente = nil
        concluir(Self.decidir(payload: pendente.payload, entregueEm: pendente.entregueEm, conta: conta))
    }

    /// Não há sessão: o toque que esperava é descartado, e os próximos não abrem nada.
    public func semSessao() {
        sessao = .ausente
        guard pendente != nil else { return }
        pendente = nil
        concluir(.ignorar(.semSessao))
    }

    /// A decisão, sem efeito nenhum: é o que os testes de cada tipo exercitam.
    public nonisolated static func decidir(payload: [AnyHashable: Any], entregueEm: Date, conta: ContaNoAparelho?) -> DecisaoDoPush {
        guard let aviso = AvisoDePush(payload: payload) else { return .ignorar(.payloadInvalido) }
        guard let conta else { return .ignorar(.semSessao) }
        guard vinculoVale(conta, entregueEm: entregueEm) else { return .ignorar(.deOutraConta) }
        if aviso.tipo == .suspensao || aviso.tipo == .reativacao { return .abrir(.situacaoDaConta) }
        switch conta.fluxo {
        case .profissional:
            guard let destino = DestinoDoProfissional(aviso) else { return .ignorar(.semDestino) }
            return .abrir(.profissional(destino))
        case .contratante:
            guard let destino = AvisoDoContratante(tipo: aviso.tipo.rawValue, payload: aviso.payload) else { return .ignorar(.semDestino) }
            return .abrir(.contratante(destino))
        case .nenhum:
            return .ignorar(.semDestino)
        }
    }

    private nonisolated static func vinculoVale(_ conta: ContaNoAparelho, entregueEm: Date) -> Bool {
        guard let vinculo = conta.vinculo else { return false }
        return vinculo.contaID == conta.contaID && entregueEm >= vinculo.desde
    }

    @discardableResult
    private func concluir(_ decisao: DecisaoDoPush) -> DecisaoDoPush {
        ultimaDecisao = decisao
        guard case let .abrir(destino) = decisao else { return decisao }
        switch destino {
        case let .profissional(destino): profissional.abrir(destino)
        case let .contratante(aviso): contratante.abrir(aviso)
        case .situacaoDaConta: reavaliacoesDaConta += 1
        }
        return decisao
    }

    /// Só os campos de texto do payload: é tudo o que o roteamento usa, e é `Sendable`.
    private nonisolated static func campos(_ payload: [AnyHashable: Any]) -> [String: String] {
        payload.reduce(into: [:]) { campos, par in
            if let chave = par.key as? String, let valor = par.value as? String { campos[chave] = valor }
        }
    }
}

extension RoteadorDoProfissional {
    /// O destino de um aviso substitui a pilha: abre a tela dele, e não uma por cima da outra.
    public func abrir(_ destino: DestinoDoProfissional) {
        switch destino {
        case let .vaga(vagaID):
            aba = .vagas
            caminho = [.vagaDoAviso(vagaID: vagaID)]
        case .vagas:
            aba = .vagas
            caminho = []
        case let .turno(turnoID):
            // Como a avaliação, o turno do aviso fica na pilha que o roteador comanda.
            aba = .vagas
            caminho = [.turnoDoAviso(turnoID: turnoID)]
        case .meusTurnos:
            caminho = []
            aba = .turnos
        case let .avaliacao(turnoID):
            aba = .vagas
            caminho = [.avaliacao(turnoID: turnoID)]
        }
        avisosAbertos += 1
    }
}
