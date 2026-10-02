import Foundation
import FrilaDominio

/// Sair da conta apaga o cache e a fila deste aparelho. O cache guarda o telefone da outra parte
/// (RN10) e a fila guarda ações da conta que saiu: nada disso pode sobrar para a próxima conta que
/// entrar no mesmo iPhone. A exclusão de conta (S2) passa por aqui também.
public struct SaidaDaConta: ContaRepositorio {
    private let limparAvaliacoes: @Sendable () -> Void
    private let api: any ApiCliente
    private let armazenamento: (any CacheLocal & FilaDeAcoes)?
    private let aparelho: AparelhoDePush?

    public init(api: any ApiCliente, armazenamento: (any CacheLocal & FilaDeAcoes)?,
                aparelho: AparelhoDePush? = nil,
                limparAvaliacoes: @escaping @Sendable () -> Void = {}) {
        self.api = api
        self.limparAvaliacoes = limparAvaliacoes
        self.armazenamento = armazenamento
        self.aparelho = aparelho
    }

    /// A saída que o app usa: o token de push guardado neste aparelho sai do servidor antes de a
    /// sessão acabar (#162), para o iPhone não continuar recebendo o push de quem saiu (RN15).
    public func sair() async {
        guard let aparelho else { return await sair(tokenFCM: nil) }
        let api = api
        await aparelho.encerrar { tokenFCM in await api.sair(tokenFCM: tokenFCM) }
        await apagarDadosLocais()
    }

    /// A saída com o token informado por quem chama. Sem token, nada sai do servidor.
    public func sair(tokenFCM: String?) async {
        await api.sair(tokenFCM: tokenFCM)
        await apagarDadosLocais()
    }

    /// Exclusão definitiva de conta (S2, RF25): chama a exclusão na porta informada e,
    /// somente após a confirmação do servidor (202), apaga o cache, a fila, o destino guardado
    /// e a sessão no Keychain. Se a porta falhar (sem rede, administrador_unico, etc.),
    /// nenhum dado local é removido.
    @discardableResult
    public func excluir(porta: any ExclusaoDeContaPorta) async throws -> ExclusaoDeConta {
        let resultado = try await porta.excluirConta()
        await api.sair(tokenFCM: nil)
        await apagarDadosLocais()
        return resultado
    }

    /// Versão que utiliza a própria API quando ela conforma a `ExclusaoDeContaPorta`.
    @discardableResult
    public func excluir() async throws -> ExclusaoDeConta {
        guard let porta = api as? any ExclusaoDeContaPorta else {
            throw ErroDaApi(codigo: .respostaInvalida)
        }
        return try await excluir(porta: porta)
    }

    /// Quando a sessão é encerrada sem a pessoa pedir (401 de conta excluída ou suspensa, sessão
    /// trocada), o efeito sobre o aparelho é o mesmo de sair.
    public func acompanharEncerramentos(de observador: any ObservadorDeSessao) async {
        for await _ in observador.encerramentos() {
            await apagarDadosLocais()
        }
    }

    private func apagarDadosLocais() async {
        limparAvaliacoes()
        // Sessão que acabou sem saída pedida não tem mais como tirar o token do servidor: a conta
        // excluída já teve os aparelhos removidos por lá, e a outra só deixa de ser a dona na
        // próxima entrada neste aparelho. Aqui o aparelho deixa de ser dela.
        await aparelho?.desvincular()
        if let armazenamento {
            // `ArmazenamentoSwiftData.limpar` apaga turnos, funções, sessão e fila de uma vez; as duas
            // chamadas mantêm a regra certa se as portas passarem a ter implementações separadas.
            try? await (armazenamento as any CacheLocal).limpar()
            try? await (armazenamento as any FilaDeAcoes).limpar()
        }
        DestinoGuardado.limpar()
    }
}
