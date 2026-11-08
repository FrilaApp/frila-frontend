import SwiftUI

/// O interruptor do app: o trilho ligado usa a cor de seleção, e não o `tint` global.
/// O `tint` global é a cor primária, que é branca no escuro, e o botão do interruptor também é
/// branco: no escuro, o interruptor ligado ficava todo branco, sem mostrar o estado (V6 da
/// conferência visual da 1.1). A cor de seleção é a mesma nos dois temas e foi feita para ter o
/// branco por cima.
public struct EstiloDoInterruptor: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        // `Toggle(configuration)` desenha o estilo de baixo (o interruptor do sistema), só com outra cor.
        Toggle(configuration).tint(FrilaCor.selecao)
    }
}

public extension ToggleStyle where Self == EstiloDoInterruptor {
    /// O interruptor do Frila. Vale para todo `Toggle` do app (aplicado na raiz, em `FrilaApp`).
    static var frila: EstiloDoInterruptor { EstiloDoInterruptor() }
}
