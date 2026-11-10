import SwiftUI

/// O interruptor do app: o trilho ligado usa a cor de ação, e não o `tint` global.
/// O `tint` global é a cor primária, que é branca no escuro, e o botão do interruptor também é
/// branco: no escuro, o interruptor ligado ficava todo branco, sem mostrar o estado (V6 da
/// conferência visual da 1.1). O trilho precisa de uma cor que seja a mesma nos dois temas e
/// aceite o branco por cima. Na pele nova (1.2) a cor de seleção passou a ser a tinta, que
/// inverte para branco no escuro; a cor de ação (#F46700) é a que cumpre as duas condições.
public struct EstiloDoInterruptor: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        // `Toggle(configuration)` desenha o estilo de baixo (o interruptor do sistema), só com outra cor.
        Toggle(configuration).tint(FrilaCor.acao)
    }
}

public extension ToggleStyle where Self == EstiloDoInterruptor {
    /// O interruptor do Frila. Vale para todo `Toggle` do app (aplicado na raiz, em `FrilaApp`).
    static var frila: EstiloDoInterruptor { EstiloDoInterruptor() }
}
