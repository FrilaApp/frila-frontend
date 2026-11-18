import FrilaDominio
import Observation
import SwiftUI

public enum ListaDeCasas: Equatable, Sendable {
    case carregando
    case conteudo([EstabelecimentoDaConta])
    case erro
}

/// Trocar de casa, para quem cuida de mais de uma (`meus_estabelecimentos`, ordenada por nome pelo servidor). Não há RPC de
/// troca: escolher uma casa é só dizer ao app de qual delas falar; as telas de destino leem `meu_estabelecimento` da casa
/// escolhida, como sempre. A lista é sempre a do servidor, lida de novo a cada abertura: a conta pode ter entrado ou saído
/// de uma casa desde a última vez.
@MainActor @Observable
public final class TrocarDeCasaViewModel {
    public private(set) var estado: ListaDeCasas = .carregando

    private let listar: @Sendable () async throws -> [EstabelecimentoDaConta]
    private let prazo: Duration

    public convenience init(api: any ApiCliente, prazo: Duration = .seconds(20)) {
        self.init(prazo: prazo, listar: { try await api.meusEstabelecimentos() })
    }

    public init(prazo: Duration = .seconds(20), listar: @escaping @Sendable () async throws -> [EstabelecimentoDaConta]) {
        self.prazo = prazo
        self.listar = listar
    }

    public func carregar() async {
        estado = .carregando
        let leitura = listar
        do {
            let casas = try await PrazoDaAbertura.esperar(prazo) { try await leitura() }
            estado = .conteudo(casas)
        } catch {
            guard !Task.isCancelled else { return }
            estado = .erro
        }
    }
}
