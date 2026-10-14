import Foundation

/// Despachante assíncrono e resiliente de eventos de telemetria do Frila (RN15, RNF08, T-0017).
/// Garante que:
/// 1. Apenas eventos do enum fechado `EventoDeTelemetria` são emitidos.
/// 2. Nenhuma falha de rede/RPC quebra o fluxo ou exibe erro ao usuário.
/// 3. Metadados opcionais contêm apenas identificadores relacionais (`vagaID`, `turnoID`).
public actor RegistradorDeTelemetria {
    private let api: any ApiCliente

    public init(api: any ApiCliente) {
        self.api = api
    }

    /// Emite um evento de telemetria sem propagar exceções (resiliência total).
    @discardableResult
    public func registrar(
        _ evento: EventoDeTelemetria,
        vagaID: UUID? = nil,
        turnoID: UUID? = nil,
        ocorridoEm: Date? = nil
    ) async -> Bool {
        let registro = RegistroDeEvento(
            evento: evento,
            vagaID: vagaID,
            turnoID: turnoID,
            ocorridoEm: ocorridoEm
        )
        do {
            return try await api.registrarEvento(registro)
        } catch {
            // Falha de telemetria é silenciosa e nunca quebra o fluxo do usuário (RNF08, RN15).
            return false
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
