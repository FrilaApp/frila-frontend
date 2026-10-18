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
        if !permitirCache { try await purgarDadosLocaisDeOutraConta(cache: cache) }
        do {
            let sessao = try await PrazoDaAbertura.esperar(prazo) { try await api.minhaConta() }.sessao
            // Troca de conta sem saída prévia (ou cache corrompido/ilegível/órfão):
            // Se a sessão anterior for de outro usuário, ou falhar na leitura, ou for nula
            // mas existirem resíduos locais órfãos, purga completamente todos os dados locais
            // ANTES de salvar a nova sessão e antes de qualquer sincronização rodar.
            let precisaPurgar: Bool
            do {
                if let anterior = try await cache?.sessao() {
                    precisaPurgar = (anterior.usuarioID != sessao.usuarioID)
                } else {
                    precisaPurgar = (await cache?.possuiDadosLocais() == true)
                }
            } catch {
                precisaPurgar = true
            }

            if precisaPurgar {
                try await purgarDadosLocaisDeOutraConta(cache: cache)
            }
            try? await cache?.salvar(sessao: sessao)
            return sessao.usuarioID
        } catch let erro as ErroDaApi where erro.codigo == .semRede && permitirCache {
            if let sessao = try await cache?.sessao() { return sessao.usuarioID }
            throw erro
        }
    }

    private static func purgarDadosLocaisDeOutraConta(cache: (any CacheLocal)?) async throws {
        // ArmazenamentoSwiftData.limpar() apaga turnos, contatos, funções, sessão, ações pendentes,
        // ações recusadas e telemetria offline da conta anterior.
        // Isolamento: erro na limpeza do banco local não impede a purga dos outros armazenamentos.
        var erroDeLimpeza: (any Error)?
        do {
            try await cache?.limpar()
        } catch {
            erroDeLimpeza = error
        }
        UserDefaultsArmazenamentoAvaliacoes().limpar()
        CacheEquipeDeConfianca.compartilhado.limpar()
        CacheDeLeituras.compartilhado.limpar()
        DestinoGuardado.limpar()
        URLCache.shared.removeAllCachedResponses()

        // Se a limpeza do cache falhou, impede a persistência da nova sessão para evitar vazamento permanente.
        if let erroDeLimpeza {
            throw erroDeLimpeza
        }
    }
}
