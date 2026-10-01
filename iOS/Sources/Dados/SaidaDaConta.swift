import Foundation
import FrilaDominio

/// Sair da conta apaga o cache e a fila deste aparelho. O cache guarda o telefone da outra parte
/// (RN10) e a fila guarda ações da conta que saiu: nada disso pode sobrar para a próxima conta que
/// entrar no mesmo iPhone. A exclusão de conta (S2) passa por aqui também.
public struct SaidaDaConta: ContaRepositorio {
    private let api: any ApiCliente
    private let armazenamento: any CacheLocal & FilaDeAcoes

    public init(api: any ApiCliente, armazenamento: any CacheLocal & FilaDeAcoes) {
        self.api = api
        self.armazenamento = armazenamento
    }

    public func sair(tokenFCM: String?) async {
        await api.sair(tokenFCM: tokenFCM)
        await apagarDadosLocais()
    }

    /// Quando a sessão é encerrada sem a pessoa pedir (401 de conta excluída ou suspensa, sessão
    /// trocada), o efeito sobre o aparelho é o mesmo de sair.
    public func acompanharEncerramentos(de observador: any ObservadorDeSessao) async {
        for await _ in observador.encerramentos() {
            await apagarDadosLocais()
        }
    }

    private func apagarDadosLocais() async {
        // `ArmazenamentoSwiftData.limpar` apaga turnos, funções, sessão e fila de uma vez; as duas
        // chamadas mantêm a regra certa se as portas passarem a ter implementações separadas.
        try? await (armazenamento as any CacheLocal).limpar()
        try? await (armazenamento as any FilaDeAcoes).limpar()
        DestinoGuardado.limpar()
    }
}
