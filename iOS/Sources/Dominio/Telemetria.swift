import Foundation
import os

/// Um evento que não chegou ao servidor e espera a rede voltar. Guarda a conta que o gerou: a fila
/// é de uma conta só, e o evento de outra pessoa nunca sai pelo login de quem entrou depois.
public struct EventoDeTelemetriaPendente: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let contaID: UUID
    /// Já com o `ocorridoEm` do momento real: o reenvio não troca a data pela hora da volta da rede.
    public let registro: RegistroDeEvento
    public let guardadoEm: Date

    public init(id: UUID = UUID(), contaID: UUID, registro: RegistroDeEvento, guardadoEm: Date) {
        self.id = id
        self.contaID = contaID
        self.registro = registro
        self.guardadoEm = guardadoEm
    }
}

/// Onde os eventos de telemetria esperam quando o envio falha por rede (RNF08).
public protocol FilaDeTelemetria: Sendable {
    /// Guarda o evento para a conta da sessão local e descarta os mais antigos acima de `limite`.
    /// Sem sessão local conhecida não guarda nada: sem dono, o evento poderia sair pela conta errada.
    func guardar(_ registro: RegistroDeEvento, em instante: Date, limite: Int) async throws
    /// Do mais antigo para o mais novo.
    func eventosPendentes() async throws -> [EventoDeTelemetriaPendente]
    func remover(ids: [UUID]) async throws
    /// Só um reenvio por vez: dois em paralelo mandariam o mesmo evento duas vezes (o servidor não deduplica).
    func reservarReenvio() async -> Bool
    func liberarReenvio() async
    func limpar() async throws
}

/// A fila que o app ligou na abertura. Os registradores criados pelas telas a usam por padrão, para o
/// evento offline ser guardado sem cada tela ter de receber o banco. Fica vazia nos testes.
public enum FilaDeTelemetriaDoApp {
    private static let guardada = OSAllocatedUnfairLock<(any FilaDeTelemetria)?>(initialState: nil)

    public static var atual: (any FilaDeTelemetria)? { guardada.withLock { $0 } }

    public static func ligar(_ fila: (any FilaDeTelemetria)?) { guardada.withLock { $0 = fila } }
}

/// Despachante assíncrono e resiliente de eventos de telemetria do Frila (RN15, RNF08, T-0017).
/// Garante que:
/// 1. Apenas eventos do enum fechado `EventoDeTelemetria` são emitidos.
/// 2. Nenhuma falha de rede/RPC quebra o fluxo ou exibe erro ao usuário.
/// 3. Metadados opcionais contêm apenas identificadores relacionais (`vagaID`, `turnoID`).
/// 4. O evento que falha por rede fica guardado com a hora em que aconteceu e sai quando a rede volta.
public actor RegistradorDeTelemetria {
    /// Acima disso o mais antigo sai. 200 cobre dias sem rede (um turno gera de 3 a 6 eventos) e,
    /// com poucos bytes por evento, o banco local não cresce sem fim.
    public static let limiteDePendentes = 200
    /// Evento mais velho que isso não é mais enviado. A retenção do servidor é de 90 dias; 30 deixa
    /// folga larga e evita injetar na análise um dado de um mês atrás como se fosse recente.
    public static let idadeMaxima: TimeInterval = 30 * 24 * 60 * 60

    private let api: any ApiCliente
    private let fila: (any FilaDeTelemetria)?
    private let relogio: any Relogio

    public init(
        api: any ApiCliente,
        fila: (any FilaDeTelemetria)? = FilaDeTelemetriaDoApp.atual,
        relogio: any Relogio = RelogioDoSistema()
    ) {
        self.api = api
        self.fila = fila
        self.relogio = relogio
    }

    /// Emite um evento de telemetria sem propagar exceções (resiliência total).
    @discardableResult
    public func registrar(
        _ evento: EventoDeTelemetria,
        vagaID: UUID? = nil,
        turnoID: UUID? = nil,
        ocorridoEm: Date? = nil
    ) async -> Bool {
        let agora = relogio.agora
        // O servidor recusa data futura (`registro_no_futuro`); com o relógio do aparelho adiantado,
        // o evento sai com a hora de agora em vez de ser perdido.
        let momento = ocorridoEm.map { min($0, agora) }
        let registro = RegistroDeEvento(evento: evento, vagaID: vagaID, turnoID: turnoID, ocorridoEm: momento)
        do {
            let registrado = try await api.registrarEvento(registro)
            // A rede está boa: aproveita para esvaziar o que ficou para trás, sem segurar quem chamou.
            if fila != nil { Task { [weak self] in await self?.reenviar() } }
            return registrado
        } catch {
            // Falha de telemetria é silenciosa e nunca quebra o fluxo do usuário (RNF08, RN15).
            if Self.deveGuardar(depoisDe: error) {
                await guardar(RegistroDeEvento(
                    evento: evento, vagaID: vagaID, turnoID: turnoID, ocorridoEm: momento ?? agora
                ), agora: agora)
            }
            return false
        }
    }

    /// Manda o que ficou guardado, do mais antigo para o mais novo, e para na primeira falha de rede.
    /// Chamado quando a conexão volta, na abertura do app e depois de cada envio que dá certo.
    public func reenviar() async {
        guard let fila, await fila.reservarReenvio() else { return }
        await reenviarReservado(fila)
        await fila.liberarReenvio()
    }

    private func reenviarReservado(_ fila: any FilaDeTelemetria) async {
        guard let pendentes = try? await fila.eventosPendentes(), !pendentes.isEmpty else { return }
        // Sem saber quem está logado (sem rede, sem sessão), nada sai: o evento espera.
        guard let contaAtual = try? await api.minhaConta().id else { return }
        let agora = relogio.agora
        for pendente in pendentes {
            let ocorridoEm = pendente.registro.ocorridoEm ?? pendente.guardadoEm
            // Outra conta ou velho demais: descarta sem enviar.
            guard pendente.contaID == contaAtual, agora.timeIntervalSince(ocorridoEm) <= Self.idadeMaxima else {
                try? await fila.remover(ids: [pendente.id])
                continue
            }
            // Um relógio que andou para trás entre o registro e o reenvio não gera data futura.
            let registro = RegistroDeEvento(
                evento: pendente.registro.evento, vagaID: pendente.registro.vagaID,
                turnoID: pendente.registro.turnoID, ocorridoEm: min(ocorridoEm, agora)
            )
            do {
                _ = try await api.registrarEvento(registro)
            } catch {
                // Rede ainda ruim: mantém este e os seguintes, na ordem. Recusa definitiva (422): sai.
                guard !Self.deveGuardar(depoisDe: error) else { return }
            }
            try? await fila.remover(ids: [pendente.id])
        }
    }

    private func guardar(_ registro: RegistroDeEvento, agora: Date) async {
        guard let fila else { return }
        // Guardar também é telemetria: se o banco falhar, o evento se perde e o fluxo segue.
        try? await fila.guardar(registro, em: agora, limite: Self.limiteDePendentes)
    }

    /// Falha de rede, de servidor (5xx, 429) ou de sessão em renovação passa com o tempo, então o
    /// evento fica guardado. Recusa do servidor (422 `campo_obrigatorio`, `campo_invalido`,
    /// `registro_no_futuro`, 403, 404, 400) é definitiva: reenviar o mesmo evento falharia sempre.
    static func deveGuardar(depoisDe erro: Error) -> Bool {
        guard let erro = erro as? ErroDaApi else { return true }
        if erro.codigoOriginal == "400" || erro.codigoOriginal == "http_400" { return false }
        switch erro.codigo {
        case .semRede, .desconhecido, .respostaInvalida, .limiteExcedido, .naoAutenticado: return true
        default: return false
        }
    }

    /// Dispara o registro em uma Task desacoplada (fire-and-forget seguro).
    public nonisolated func disparar(
        _ evento: EventoDeTelemetria,
        vagaID: UUID? = nil,
        turnoID: UUID? = nil,
        ocorridoEm: Date? = nil
    ) {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.registrar(
                evento,
                vagaID: vagaID,
                turnoID: turnoID,
                ocorridoEm: ocorridoEm
            )
        }
    }
}
