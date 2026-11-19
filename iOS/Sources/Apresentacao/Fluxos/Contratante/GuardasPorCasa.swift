import Foundation
import FrilaDominio

/// As guardas de dinheiro do fluxo do contratante (a da escala de evento e a da busca de profissionais), uma de cada por casa.
///
/// Trocar de casa recria Minhas vagas (`.id`), e com ela tudo o que a tela guarda. A guarda de uma tentativa incerta (a chave
/// da escala, o envio da busca) não pode ir junto: casa A com a escala sem resposta, trocar para a casa B e voltar para A
/// publicaria de novo com chave nova, e se a primeira tivesse chegado as vagas sairiam em dobro. Por isso as guardas moram
/// aqui, acima da tela, indexadas pelo `estabelecimento_id`: trocar de casa não apaga a guarda da outra.
///
/// Quem as tem é o modelo do fluxo do contratante, que é da sessão: sair da conta, a sessão vencer ou entrar com outra conta
/// tira o fluxo da tela, e as guardas vão junto com a casa escolhida (`FluxoDoContratanteViewModel.encerrarSessao`).
@MainActor
public final class GuardasPorCasa {
    private var escalas: [UUID: GuardaDaEscala] = [:]
    private var buscas: [UUID: GuardaDaBuscaDeProfissionais] = [:]

    public init() {}

    /// A guarda da escala da casa: sempre a mesma enquanto a sessão durar.
    public func escala(de casa: UUID) -> GuardaDaEscala {
        if let guarda = escalas[casa] { return guarda }
        let nova = GuardaDaEscala()
        escalas[casa] = nova
        return nova
    }

    /// A guarda da busca da casa: sempre a mesma enquanto a sessão durar. `criar` só roda na primeira vez.
    public func busca(de casa: UUID, criar: @escaping () -> BuscaDeProfissionaisViewModel) -> GuardaDaBuscaDeProfissionais {
        if let guarda = buscas[casa] { return guarda }
        let nova = GuardaDaBuscaDeProfissionais(criar: criar)
        buscas[casa] = nova
        return nova
    }

    /// Não há guarda nenhuma (o teste de sessão confere que `apagarTudo` as leva todas).
    public var vazia: Bool { escalas.isEmpty && buscas.isEmpty }

    /// Sair da conta ou entrar com outra: nenhuma chave de uma sessão vale na seguinte.
    public func apagarTudo() {
        escalas.removeAll()
        buscas.removeAll()
    }
}
