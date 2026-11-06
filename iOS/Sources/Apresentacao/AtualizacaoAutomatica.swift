import Foundation
import FrilaDominio
import Observation
import SwiftUI

/// As listas que se relêem sozinhas. Cada uma tem o próprio intervalo mínimo e a própria vez:
/// a recarga de uma não segura a de outra.
public enum ListaAtualizavel: Hashable, Sendable {
    case vagas
    case meusTurnos
    case minhasCandidaturas
    case minhasVagas
    case turnoDoContratante
    case equipeDeConfianca
}

/// O que fazer com um pedido de releitura.
public enum DecisaoDaAtualizacao: Equatable, Sendable {
    /// Reler agora. Ao terminar, quem recebeu chama `concluir`.
    case recarregar
    /// Reler depois de esperar estes segundos (o intervalo curto do push). A vez da lista fica
    /// reservada; ao fim da espera, quem recebeu chama `retomar`.
    case esperar(TimeInterval)
    /// Nada a fazer.
    case ignorar
}

/// A regra da atualização automática, sem SwiftUI e sem relógio próprio: o instante vem de fora,
/// para os testes conduzirem o tempo.
///
/// - Só com sessão: sem conta na tela, nenhum pedido passa.
/// - Uma recarga por lista de cada vez: o pedido que chega com outra em voo (ou esperando a vez)
///   não abre uma segunda.
/// - Intervalo mínimo entre recargas da mesma lista (30 s), contado do fim da anterior (com ou sem
///   sucesso): alternar de app não martela o servidor.
/// - Um aviso de push que a lista ainda não atendeu passa por cima dos 30 s, mas não do intervalo
///   curto do push (3 s): uma rajada de pushes dá no máximo uma releitura a cada 3 s. Se o aviso
///   chega com uma recarga em voo, que pode ter saído antes da mudança, a lista é lida mais uma vez
///   depois, respeitando os 3 s.
public struct ControleDaAtualizacao: Sendable {
    public static let intervaloPadrao: TimeInterval = 30
    public static let intervaloDoAvisoPadrao: TimeInterval = 3

    public let intervaloMinimo: TimeInterval
    public let intervaloDoAviso: TimeInterval
    public private(set) var sessaoAtiva = false
    /// Quantos avisos de push da conta na tela chegaram desde a abertura do app. Só cresce: as
    /// listas observam a mudança, e voltar a zero numa troca de conta pareceria um aviso novo.
    public private(set) var avisos = 0
    private var ultimaRecarga: [ListaAtualizavel: Date] = [:]
    private var avisosAtendidos: [ListaAtualizavel: Int] = [:]
    /// Listas com a vez reservada: recarga em voo ou esperando o intervalo curto do push.
    private var ocupadas: Set<ListaAtualizavel> = []
    private var repetir: Set<ListaAtualizavel> = []

    public init(
        intervaloMinimo: TimeInterval = ControleDaAtualizacao.intervaloPadrao,
        intervaloDoAviso: TimeInterval = ControleDaAtualizacao.intervaloDoAvisoPadrao
    ) {
        self.intervaloMinimo = intervaloMinimo
        self.intervaloDoAviso = intervaloDoAviso
    }

    /// A conta entrou ou saiu. Na troca, o que valia para a conta anterior (intervalos e avisos)
    /// é esquecido.
    public mutating func mudarSessao(ativa: Bool) {
        guard ativa != sessaoAtiva else { return }
        sessaoAtiva = ativa
        ultimaRecarga = [:]
        avisosAtendidos = [:]
        repetir = []
    }

    public mutating func avisoChegou() {
        guard sessaoAtiva else { return }
        avisos += 1
    }

    /// A lista tem a vez reservada: recarga em voo ou esperando o intervalo curto do push.
    public func emVoo(_ lista: ListaAtualizavel) -> Bool { ocupadas.contains(lista) }

    /// A própria tela acabou de carregar a lista (a primeira carga, quando aparece): conta como
    /// recarga, e os avisos que já tinham chegado estão nela.
    public mutating func registrarCarga(_ lista: ListaAtualizavel, em agora: Date) {
        guard sessaoAtiva else { return }
        ultimaRecarga[lista] = agora
        avisosAtendidos[lista] = avisos
    }

    public mutating func pedir(_ lista: ListaAtualizavel, em agora: Date) -> DecisaoDaAtualizacao {
        guard sessaoAtiva else { return .ignorar }
        let avisoNovo = avisos > avisosAtendidos[lista, default: avisos]
        if ocupadas.contains(lista) {
            if avisoNovo { repetir.insert(lista) }
            return .ignorar
        }
        let desdeAUltima = ultimaRecarga[lista].map { agora.timeIntervalSince($0) }
        if !avisoNovo, let desdeAUltima, desdeAUltima < intervaloMinimo { return .ignorar }
        ocupadas.insert(lista)
        return proximaVez(lista, em: agora)
    }

    /// Fim da espera do intervalo curto do push.
    public mutating func retomar(_ lista: ListaAtualizavel, em agora: Date) -> DecisaoDaAtualizacao {
        guard sessaoAtiva else {
            ocupadas.remove(lista)
            return .ignorar
        }
        return proximaVez(lista, em: agora)
    }

    /// Fim da recarga. Se um aviso chegou durante ela, a lista é lida de novo, depois do intervalo
    /// curto do push.
    public mutating func concluir(_ lista: ListaAtualizavel, em agora: Date) -> DecisaoDaAtualizacao {
        if sessaoAtiva { ultimaRecarga[lista] = agora }
        guard sessaoAtiva, repetir.contains(lista) else {
            ocupadas.remove(lista)
            repetir.remove(lista)
            return .ignorar
        }
        return proximaVez(lista, em: agora)
    }

    /// A recarga foi cancelada (a tela saiu): a vez da lista é liberada e o intervalo mínimo não
    /// conta, porque a lista não foi relida.
    public mutating func desistir(_ lista: ListaAtualizavel) {
        ocupadas.remove(lista)
        repetir.remove(lista)
        ultimaRecarga[lista] = nil
    }

    /// Com a vez reservada: relê agora, ou espera o que falta do intervalo curto do push.
    private mutating func proximaVez(_ lista: ListaAtualizavel, em agora: Date) -> DecisaoDaAtualizacao {
        if let ultima = ultimaRecarga[lista] {
            let falta = intervaloDoAviso - agora.timeIntervalSince(ultima)
            if falta > 0 { return .esperar(falta) }
        }
        repetir.remove(lista)
        avisosAtendidos[lista] = avisos
        return .recarregar
    }
}

/// O ponto central da atualização automática das listas. Vive com os roteadores
/// (`NavegacaoDoApp`), porque o aviso de push chega pelo `AppDelegate`, e desce para as telas pelo
/// ambiente. As telas não o chamam direto: usam `.atualizacaoAutomatica(_:recarregar:)`.
///
/// Sem timer e sem Realtime: a lista só é relida quando a tela aparece, quando o app volta a ficar
/// ativo e quando chega um aviso de push da conta que está na tela.
@MainActor @Observable
public final class AtualizacaoAutomatica {
    /// A regra muda a cada pedido; só `avisos` é observado, para as telas não se redesenharem à toa.
    @ObservationIgnored public private(set) var controle: ControleDaAtualizacao
    @ObservationIgnored private let relogio: any Relogio
    @ObservationIgnored private let esperar: @Sendable (TimeInterval) async -> Void
    /// Sobe a cada aviso de push da conta na tela: as listas visíveis observam este número.
    public private(set) var avisos = 0

    /// `esperar` é a pausa do intervalo curto do push; os testes trocam por uma que só avança o relógio.
    public init(
        intervaloMinimo: TimeInterval = ControleDaAtualizacao.intervaloPadrao,
        intervaloDoAviso: TimeInterval = ControleDaAtualizacao.intervaloDoAvisoPadrao,
        relogio: any Relogio = RelogioDoSistema(),
        esperar: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        controle = ControleDaAtualizacao(intervaloMinimo: intervaloMinimo, intervaloDoAviso: intervaloDoAviso)
        self.relogio = relogio
        self.esperar = esperar
    }

    public var sessaoAtiva: Bool { controle.sessaoAtiva }

    public func mudarSessao(ativa: Bool) { controle.mudarSessao(ativa: ativa) }

    /// Um push da conta que está na tela chegou com o app aberto, ou a pessoa tocou nele.
    public func avisoChegou() {
        controle.avisoChegou()
        avisos = controle.avisos
    }

    public func registrarCarga(_ lista: ListaAtualizavel) {
        controle.registrarCarga(lista, em: relogio.agora)
    }

    /// Relê a lista se a regra deixar (`ControleDaAtualizacao`). `recarregar` é a releitura em
    /// silêncio da tela: não troca a lista por carregamento e, se falhar, deixa o que está na tela.
    public func pedir(_ lista: ListaAtualizavel, recarregar: @MainActor () async -> Void) async {
        var decisao = controle.pedir(lista, em: relogio.agora)
        while true {
            switch decisao {
            case .ignorar:
                return
            case let .esperar(segundos):
                await esperar(segundos)
                // A tela saiu durante a espera: a vez da lista é liberada.
                if Task.isCancelled {
                    controle.desistir(lista)
                    return
                }
                decisao = controle.retomar(lista, em: relogio.agora)
            case .recarregar:
                await recarregar()
                // A tela saiu no meio: a lista não foi relida de fato, e a próxima aparição relê.
                if Task.isCancelled {
                    controle.desistir(lista)
                    return
                }
                decisao = controle.concluir(lista, em: relogio.agora)
            }
        }
    }
}

/// Quando a tela aparece pela primeira vez, a releitura automática fica para depois ou não?
public enum AtualizacaoAoAparecer: Sendable {
    /// A primeira aparição é a carga da própria tela; as seguintes (voltar de uma tela empilhada,
    /// trocar de aba) relêem.
    case aoVoltar
    /// Toda aparição relê, a primeira também: a tela não carrega sozinha se já há dados.
    case sempre
    /// A tela já recarrega sozinha a cada aparição: a atualização automática não se mete.
    case nunca
}

private struct AtualizacaoAutomaticaDaLista: ViewModifier {
    @Environment(AtualizacaoAutomatica.self) private var atualizacao: AtualizacaoAutomatica?
    @Environment(\.scenePhase) private var fase
    @State private var visivel = false
    @State private var jaApareceu = false
    @State private var tarefa: Task<Void, Never>?
    let lista: ListaAtualizavel
    let aoAparecer: AtualizacaoAoAparecer
    let recarregar: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                visivel = true
                let primeira = !jaApareceu
                jaApareceu = true
                switch aoAparecer {
                case .aoVoltar:
                    if primeira { atualizacao?.registrarCarga(lista) } else { pedir() }
                case .sempre:
                    pedir()
                case .nunca:
                    break
                }
            }
            .onDisappear {
                visivel = false
                tarefa?.cancel()
                tarefa = nil
            }
            // A volta do segundo plano (e o fim de um alerta do sistema por cima do app): o
            // intervalo mínimo segura quem alterna de app o tempo todo.
            .onChange(of: fase) { antiga, nova in
                if antiga != .active, nova == .active { pedir() }
            }
            // Aviso de push com a lista na tela. A lista escondida atende o aviso quando reaparece.
            .onChange(of: atualizacao?.avisos) { pedir() }
    }

    private func pedir() {
        guard visivel, let atualizacao, atualizacao.sessaoAtiva else { return }
        let pedido = Task { await atualizacao.pedir(lista, recarregar: recarregar) }
        // Com uma recarga em voo, o pedido só marca a repetição (se veio de um aviso): a tarefa que
        // a saída da tela cancela continua sendo a que está em voo.
        if !atualizacao.controle.emVoo(lista) { tarefa = pedido }
    }
}

extension View {
    /// Relê a lista sozinha quando a tela volta a aparecer, quando o app volta do segundo plano e
    /// quando chega um push da conta, com intervalo mínimo e uma recarga por vez
    /// (`ControleDaAtualizacao`). `recarregar` deve ser a releitura em silêncio: com dados na tela,
    /// nada de carregamento por cima, e a falha deixa a lista como estava.
    ///
    /// Sem `AtualizacaoAutomatica` no ambiente (prévias, testes, catálogo), não faz nada. Nada é
    /// anunciado ao VoiceOver e nada é animado: a lista só troca de conteúdo.
    public func atualizacaoAutomatica(
        _ lista: ListaAtualizavel,
        aoAparecer: AtualizacaoAoAparecer = .aoVoltar,
        recarregar: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(AtualizacaoAutomaticaDaLista(lista: lista, aoAparecer: aoAparecer, recarregar: recarregar))
    }
}
