#if DEBUG
import Foundation
import FrilaDominio

/// Só para o UI test (`-FRILA_BUSCA_RESPOSTA_PERDIDA`): a 1ª chamada da busca chega ao servidor, que a cria, e a resposta
/// se perde (rede ruim). O resto passa direto; a mesma chave de novo devolve a chamada já criada, como no servidor. As
/// leituras dos termos do 409 (0.2.95) ficam no padrão do protocolo, que falha: o UI test com o gancho não passa pelo 409.
actor FonteDaBuscaComRespostaPerdida: FonteDaBuscaDeProfissionais {
    private let base: any FonteDaBuscaDeProfissionais
    private var jaPerdeu = false

    init(base: any FonteDaBuscaDeProfissionais) { self.base = base }

    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }

    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        try await base.buscarProfissionais(filtro, cursor: cursor, limite: limite)
    }

    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada {
        let chamada = try await base.chamarProfissional(pedido)
        guard jaPerdeu else {
            jaPerdeu = true
            throw ErroDaApi(codigo: .respostaInvalida)
        }
        return chamada
    }

    func aceitarTermos(versao: String) async throws -> AceiteDeTermos { try await base.aceitarTermos(versao: versao) }
}
#endif
