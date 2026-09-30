import Foundation
import FrilaDominio


/// Meus turnos que abrem em modo avião (RNF06). Cada leitura com rede substitui o cache; sem rede,
/// devolve o que ficou guardado. O `CacheLocal` já aplica as duas regras de prazo: o turno sai 24 h
/// depois do fim e o contato some depois de `visivel_ate` (RN10), as duas pelo relógio do aparelho,
/// porque sem rede não há outro.
///
/// Só `sem_rede` cai no cache. Qualquer outro erro sobe: um 401 com o cache aberto mostraria os
/// turnos de uma conta que acabou de ser encerrada.
public struct TurnosComCache: TurnoRepositorio {
    private let buscar: @Sendable () async throws -> [Turno]
    private let cache: any CacheLocal
    private let relogio: any Relogio

    public init(buscar: @escaping @Sendable () async throws -> [Turno], cache: any CacheLocal, relogio: any Relogio = RelogioDoSistema()) {
        self.buscar = buscar
        self.cache = cache
        self.relogio = relogio
    }

    public func ler() async throws -> LeituraDeTurnos {
        do {
            let turnos = try await buscar()
            // Guardar é conveniência: se falhar, a pessoa continua vendo o que veio da rede.
            try? await cache.salvar(turnos: turnos, em: relogio.agora)
            return LeituraDeTurnos(turnos: turnos, origem: .rede)
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            return LeituraDeTurnos(turnos: try await cache.turnosValidos(em: relogio.agora), origem: .cache)
        }
    }

    public func meusTurnos() async throws -> [Turno] {
        try await ler().turnos
    }
}
