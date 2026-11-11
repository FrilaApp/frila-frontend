import SwiftUI

/// O interruptor do app: o trilho ligado usa uma cor própria, e não o `tint` global.
/// O `tint` global é a cor primária, que é branca no escuro, e o botão do interruptor também é
/// branco: no escuro, o interruptor ligado ficava todo branco, sem mostrar o estado (V6 da
/// conferência visual da 1.1). Por isso cada tema usa a sua cor:
/// - claro: `FrilaCor.selecao` (a tinta, #111111), exatamente como era antes; o claro não muda;
/// - escuro: `FrilaCor.acao` (#F46700), porque a cor de seleção inverte para branco no escuro e
///   sumiria atrás do botão branco, enquanto a cor de ação é a mesma nos dois temas e aceita o
///   branco por cima.
public struct EstiloDoInterruptor: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        InterruptorComCor(configuration: configuration)
    }
}

/// Lê o esquema de cores aqui, numa `View`, e não no `ToggleStyle`, que não recebe o ambiente.
private struct InterruptorComCor: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        // `Toggle(configuration)` desenha o estilo de baixo (o interruptor do sistema), só com outra cor.
        Toggle(configuration).tint(esquema == .dark ? FrilaCor.acao : FrilaCor.selecao)
    }
}

public extension ToggleStyle where Self == EstiloDoInterruptor {
    /// O interruptor do Frila. Vale para todo `Toggle` do app (aplicado na raiz, em `FrilaApp`).
    static var frila: EstiloDoInterruptor { EstiloDoInterruptor() }
}
