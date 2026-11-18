import SwiftUI

// Como a tela de entrada diz à abertura onde o rótulo "Frila" pousa (D-DS-21).
//
// 1. A tela marca o rótulo com `.destinoDoRotuloDaAbertura()`: o quadro dele, no espaço global, sobe pela
//    `DestinoDoRotuloDaAbertura` (quem monta a raiz lê com `.onPreferenceChange`).
// 2. A raiz passa esse quadro a `AberturaAnimada(destinoDoRotulo:)` e, enquanto a abertura cobre, põe
//    `.environment(\.aberturaCobrindo, true)`: o rótulo da tela fica invisível (quem o mostra é a abertura) e
//    reaparece quando `aoTerminar` desliga o ambiente, no mesmo lugar onde o rótulo da abertura pousou.

/// O quadro, no espaço global da tela, do primeiro rótulo marcado como destino. `nil` sem destino (a abertura
/// faz então a saída simples).
public struct DestinoDoRotuloDaAbertura: PreferenceKey {
    public static let defaultValue: CGRect? = nil

    public static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

private struct AberturaCobrindoChave: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Verdadeiro enquanto a abertura cobre o app: o rótulo de destino espera, escondido, e a arte da entrada
    /// espera para entrar.
    var aberturaCobrindo: Bool {
        get { self[AberturaCobrindoChave.self] }
        set { self[AberturaCobrindoChave.self] = newValue }
    }
}

public extension View {
    /// Marca este rótulo como o lugar onde o rótulo da abertura pousa, e o esconde enquanto a abertura cobre.
    /// `ativo` falso (a tela não está à frente, como a entrada sob a do código) não marca nada: a abertura sai
    /// como antes, sem voar para uma tela escondida.
    func destinoDoRotuloDaAbertura(ativo: Bool = true) -> some View {
        modifier(DestinoDoRotulo(ativo: ativo))
    }
}

private struct DestinoDoRotulo: ViewModifier {
    let ativo: Bool
    @Environment(\.aberturaCobrindo) private var cobrindo

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometria in
                    Color.clear.preference(key: DestinoDoRotuloDaAbertura.self,
                                           value: ativo ? geometria.frame(in: .global) : nil)
                }
            }
            .opacity(ativo && cobrindo ? 0 : 1)
    }
}
