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

/// A regra da atualização automática, sem SwiftUI e sem relógio próprio: o instante vem de fora,
/// para os testes conduzirem o tempo.
///
/// - Só com sessão: sem conta na tela, nenhum pedido passa.
/// - Uma recarga por lista de cada vez: o pedido que chega com outra em voo não abre uma segunda.
/// - Intervalo mínimo entre recargas da mesma lista, contado do fim da anterior (com ou sem
///   sucesso): alternar de app não martela o servidor.
/// - Um aviso de push que a lista ainda não atendeu passa por cima do intervalo. Se ele chega com
///   uma recarga em voo, que pode ter saído antes da mudança, a lista é lida mais uma vez no fim.
public struct ControleDaAtualizacao: Sendable {
    public static let intervaloPadrao: TimeInterval = 30

    public let intervaloMinimo: TimeInterval
    public private(set) var sessaoAtiva = false
    /// Quantos avisos de push da conta na tela chegaram desde a abertura do app. Só cresce: as
    /// listas observam a mudança, e voltar a zero numa troca de conta pareceria um aviso novo.
    public private(set) var avisos = 0
    private var ultimaRecarga: [ListaAtualizavel: Date] = [:]
    private var avisosAtendidos: [ListaAtualizavel: Int] = [:]
    private var emVoo: Set<ListaAtualizavel> = []
    private var repetir: Set<ListaAtualizavel> = []

    public init(intervaloMinimo: TimeInterval = ControleDaAtualizacao.intervaloPadrao) {
        self.intervaloMinimo = intervaloMinimo
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

    public func emVoo(_ lista: ListaAtualizavel) -> Bool { emVoo.contains(lista) }

    /// A própria tela acabou de carregar a lista (a primeira carga, quando aparece): conta como
    /// recarga, e os avisos que já tinham chegado estão nela.
    public mutating func registrarCarga(_ lista: ListaAtualizavel, em agora: Date) {
        guard sessaoAtiva else { return }
        ultimaRecarga[lista] = agora
        avisosAtendidos[lista] = avisos
    }

    /// `true` quando a recarga deve sair agora. Quem recebe `true` chama `concluir` ao terminar.
    public mutating func pedir(_ lista: ListaAtualizavel, em agora: Date) -> Bool {
        guard sessaoAtiva else { return false }
        let avisoNovo = avisos > avisosAtendidos[lista, default: avisos]
        if emVoo.contains(lista) {
            if avisoNovo { repetir.insert(lista) }
            return false
        }
        if !avisoNovo, let ultima = ultimaRecarga[lista], agora.timeIntervalSince(ultima) < intervaloMinimo {
            return false
        }
        emVoo.insert(lista)
        avisosAtendidos[lista] = avisos
        return true
    }

    /// Fim da recarga. `true` quando um aviso chegou durante ela: a lista é lida de novo, e quem
    /// recebe `true` chama `concluir` outra vez ao terminar.
    public mutating func concluir(_ lista: ListaAtualizavel, em agora: Date) -> Bool {
        if sessaoAtiva { ultimaRecarga[lista] = agora }
        guard sessaoAtiva, repetir.remove(lista) != nil else {
            emVoo.remove(lista)
            return false
        }
        avisosAtendidos[lista] = avisos
        return true
    }

    /// A recarga foi cancelada (a tela saiu): a vez da lista é liberada e o intervalo mínimo não
    /// conta, porque a lista não foi relida.
    public mutating func desistir(_ lista: ListaAtualizavel) {
        emVoo.remove(lista)
        repetir.remove(lista)
        ultimaRecarga[lista] = nil
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
    /// Sobe a cada aviso de push da conta na tela: as listas visíveis observam este número.
    public private(set) var avisos = 0

    public init(intervaloMinimo: TimeInterval = ControleDaAtualizacao.intervaloPadrao, relogio: any Relogio = RelogioDoSistema()) {
        controle = ControleDaAtualizacao(intervaloMinimo: intervaloMinimo)
        self.relogio = relogio
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
        guard controle.pedir(lista, em: relogio.agora) else { return }
        while true {
            await recarregar()
            // A tela saiu no meio: a lista não foi relida de fato, e a próxima aparição relê.
            if Task.isCancelled {
                controle.desistir(lista)
                return
            }
            guard controle.concluir(lista, em: relogio.agora) else { return }
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
