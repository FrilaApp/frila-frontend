import Foundation
import FrilaDominio

/// O ID vem da conta da sessão autenticada. Offline, recupera somente a sessão local;
/// a saída da conta apaga esse cache antes de permitir uma nova entrada.
public enum IdentidadeDaAvaliacao {
    /// `prazo`: com rede ruim, vencido o prazo vale a regra de sem rede (a sessão do cache).
    public static func obter(
        api: any ApiCliente, cache: (any CacheLocal)?, permitirCache: Bool = true, prazo: Duration = PrazoDaAbertura.padrao
    ) async throws -> UUID {
        // Uma nova autenticação invalida o cache da sessão anterior, inclusive se a rede cair.
        if !permitirCache { try await cache?.limpar() }
        do {
            let sessao = try await PrazoDaAbertura.esperar(prazo) { try await api.minhaConta() }.sessao
            try? await cache?.salvar(sessao: sessao)
            return sessao.usuarioID
        } catch let erro as ErroDaApi where erro.codigo == .semRede && permitirCache {
            if let sessao = try await cache?.sessao() { return sessao.usuarioID }
            throw erro
        }
    }
}
