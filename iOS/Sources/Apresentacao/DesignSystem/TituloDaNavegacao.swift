import SwiftUI

private struct TituloGrandeForaDeAX: ViewModifier {
    @Environment(\.dynamicTypeSize) private var tamanho

    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(tamanho.isAccessibilitySize ? .inline : .large)
    }
}

public extension View {
    /// Título grande no tamanho padrão e título na barra nos tamanhos de acessibilidade. O título
    /// grande não quebra linha: em AX3 saía cortado ("Apresentação…", "Equipe de confi…", V19 da
    /// conferência visual da 1.1). Na barra, o sistema limita o tamanho e mostra o título inteiro
    /// no visualizador de conteúdo grande ao tocar e segurar.
    func tituloGrandeForaDeAX() -> some View { modifier(TituloGrandeForaDeAX()) }
}
