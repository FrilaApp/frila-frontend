import FrilaDominio

/// Guarda o `PublicarEscalaViewModel` entre abrir, cancelar e abrir de novo a escala (DINHEIRO: vaga em dobro).
///
/// Cancelar a tela descartava o modelo e, com ele, a `chave` da escala que saiu sem resposta conhecida: abrir de novo e
/// publicar a mesma escala geraria outra chave, e se a primeira tivesse chegado as vagas sairiam em dobro. Enquanto o
/// modelo tiver uma tentativa incerta, a guarda o mantém, com o rascunho e a chave, e a tela reaberta mostra o aviso de
/// que a última tentativa pode ter publicado e reenvia a mesma escala. Sem tentativa incerta (nunca enviada, ou
/// recusada de vez), sair descarta o modelo e a próxima abertura começa limpa; a escala publicada também sai.
///
/// Vive acima da tela, no fluxo do contratante (como a guarda da busca). A guarda é da sessão: não sobrevive ao fechamento
/// do app.
@MainActor
public final class GuardaDaEscala {
    private var modelo: PublicarEscalaViewModel?

    public init() {}

    /// O modelo guardado, ou um novo (que passa a ser o guardado). Chamar de novo devolve o mesmo.
    public func obter(criar: () -> PublicarEscalaViewModel) -> PublicarEscalaViewModel {
        if let modelo { return modelo }
        let novo = criar()
        modelo = novo
        return novo
    }

    /// A pessoa saiu da tela (cancelou ou concluiu). Fica guardado só o que ainda tem tentativa incerta.
    public func aoSair() {
        guard let modelo else { return }
        if modelo.resultado != nil || modelo.tentativaIncerta == nil { self.modelo = nil }
    }

    /// Há uma escala que pode ter sido publicada e ainda não foi resolvida.
    public var temTentativaIncerta: Bool { modelo?.tentativaIncerta != nil }
}
