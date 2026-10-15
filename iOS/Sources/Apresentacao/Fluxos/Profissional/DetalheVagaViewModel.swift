import FrilaDominio
import Foundation
import Observation

public enum EstadoDoDetalhe: Equatable, Sendable {
    case carregando
    case carregado(Vaga)
    /// A vaga não existe mais, não está publicada ou está escondida (`404 nao_encontrado`).
    case naoEncontrada
    case falha(FalhaDaLista)
}

/// Detalhe da vaga (#104). O contrato não devolve telefone nem documento do estabelecimento aqui;
/// o contato só aparece depois da confirmação (RN10).
@MainActor @Observable
public final class DetalheVagaViewModel {
    public let vagaID: UUID
    public private(set) var estado: EstadoDoDetalhe = .carregando
    private(set) var api: (any ApiCliente)?
    private let buscarVaga: @Sendable (UUID) async throws -> Vaga
    /// O último detalhe já visto: aparece na hora e é trocado quando a rede responde.
    private let detalheGuardado: (@Sendable (UUID) -> Vaga?)?
    private let telemetria: RegistradorDeTelemetria?
    private var jaEmitiuAbertura = false

    public convenience init(vagaID: UUID, api: any ApiCliente, telemetria: RegistradorDeTelemetria? = nil) {
        self.init(
            vagaID: vagaID,
            buscarVaga: { id in
                try await CacheDeLeituras.compartilhado.detalheAtual(id: id) { try await api.detalheDaVaga(id: id) }
            },
            telemetria: telemetria ?? RegistradorDeTelemetria(api: api),
            detalheGuardado: { CacheDeLeituras.compartilhado.detalheGuardado(id: $0) }
        )
        self.api = api
    }

    public init(
        vagaID: UUID,
        buscarVaga: @escaping @Sendable (UUID) async throws -> Vaga,
        telemetria: RegistradorDeTelemetria? = nil,
        detalheGuardado: (@Sendable (UUID) -> Vaga?)? = nil
    ) {
        self.detalheGuardado = detalheGuardado
        self.vagaID = vagaID
        self.buscarVaga = buscarVaga
        self.telemetria = telemetria
    }

    public func carregar() async {
        if !jaEmitiuAbertura {
            jaEmitiuAbertura = true
            await telemetria?.registrar(.vagaDetalheAberto, vagaID: vagaID)
        }
        let guardado = detalheGuardado?(vagaID)
        estado = guardado.map { .carregado($0) } ?? .carregando
        do {
            estado = .carregado(try await buscarVaga(vagaID))
        } catch let erro as ErroDaApi where erro.codigo == .naoEncontrado {
            estado = .naoEncontrada
        } catch {
            // Com o detalhe guardado na tela, uma falha de rede não o apaga.
            if guardado == nil { estado = .falha(FalhaDaLista(error)) }
        }
    }
}
