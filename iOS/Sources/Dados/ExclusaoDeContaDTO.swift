import Foundation
import FrilaDominio

/// Corpo do pedido de exclusão de conta (contrato: POST /excluir-conta).
public struct RequisicaoExclusaoConta: Encodable, Sendable {
    public let confirmar: Bool

    public init(confirmar: Bool = true) {
        self.confirmar = confirmar
    }
}

/// DTO da resposta da Edge Function `excluir-conta` (schema `ExclusaoDeConta`).
public struct DTOExclusaoDeConta: Decodable, Sendable {
    public let perfil_removido_em: Date
    public let dados_apagados_ate: String
    public let turnos_cancelados: Int

    public init(perfil_removido_em: Date, dados_apagados_ate: String, turnos_cancelados: Int) {
        self.perfil_removido_em = perfil_removido_em
        self.dados_apagados_ate = dados_apagados_ate
        self.turnos_cancelados = turnos_cancelados
    }

    public func dominio() throws -> ExclusaoDeConta {
        guard let dataCivil = try? DataCivil(dados_apagados_ate) else {
            throw ErroDeConversao(campo: "dados_apagados_ate")
        }
        return ExclusaoDeConta(
            perfilRemovidoEm: perfil_removido_em,
            dadosApagadosAte: dataCivil,
            turnosCancelados: turnos_cancelados
        )
    }
}
