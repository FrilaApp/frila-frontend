import Foundation
import FrilaDominio

/// O ID vem da conta da sessão autenticada. Offline, recupera somente a sessão local;
/// a saída da conta apaga esse cache antes de permitir uma nova entrada.
public enum IdentidadeDaAvaliacao {
    public static func obter(api: any ApiCliente, cache: (any CacheLocal)?, permitirCache: Bool = true) async throws -> UUID {
        // Uma nova autenticação invalida o cache da sessão anterior, inclusive se a rede cair.
        if !permitirCache { try await cache?.limpar() }
        do {
            let sessao = try await api.minhaConta().sessao
            try? await cache?.salvar(sessao: sessao)
            return sessao.usuarioID
        } catch let erro as ErroDaApi where erro.codigo == .semRede && permitirCache {
            if let sessao = try await cache?.sessao() { return sessao.usuarioID }
            throw erro
        }
    }
}
