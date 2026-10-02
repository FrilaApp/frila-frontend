import Foundation

/// Porta para a operação de exclusão definitiva de conta (App Store 5.1.1(v), RF25).
/// Fica em arquivo e protocolo próprios para não colidir com o merge de `ApiCliente` (#50).
public protocol ExclusaoDeContaPorta: Sendable {
    func excluirConta() async throws -> ExclusaoDeConta
}

/// Resposta da exclusão de conta (contrato 0.2.18+, schema `ExclusaoDeConta`).
public struct ExclusaoDeConta: Codable, Equatable, Sendable {
    public let perfilRemovidoEm: Date
    public let dadosApagadosAte: DataCivil
    public let turnosCancelados: Int

    public init(perfilRemovidoEm: Date, dadosApagadosAte: DataCivil, turnosCancelados: Int) {
        self.perfilRemovidoEm = perfilRemovidoEm
        self.dadosApagadosAte = dadosApagadosAte
        self.turnosCancelados = turnosCancelados
    }
}
