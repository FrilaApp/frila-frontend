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

    public convenience init(vagaID: UUID, api: any ApiCliente) {
        self.init(vagaID: vagaID, buscarVaga: { try await api.detalheDaVaga(id: $0) })
        self.api = api
    }

    public init(vagaID: UUID, buscarVaga: @escaping @Sendable (UUID) async throws -> Vaga) {
        self.vagaID = vagaID
        self.buscarVaga = buscarVaga
    }

    public func carregar() async {
        estado = .carregando
        do {
            estado = .carregado(try await buscarVaga(vagaID))
        } catch let erro as ErroDaApi where erro.codigo == .naoEncontrado {
            estado = .naoEncontrada
        } catch {
            estado = .falha(FalhaDaLista(error))
        }
    }
}
