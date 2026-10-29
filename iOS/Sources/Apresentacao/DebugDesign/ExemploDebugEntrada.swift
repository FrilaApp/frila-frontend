#if FRILA_DESIGN
import SwiftUI

private struct ExemploDebugEntrada: ViewModifier {
    @State private var variante: String?
    private let registro = RegistroDebugDesign(
        id: "entrada",
        titulo: "Entrada",
        tituloRaiz: "normal",
        prefixoExibicao: "EXEMPLO",
        variantes: ["marcador"],
        decisoes: ["EXEMPLO — decisão demonstrativa, sem conteúdo de produto."]
    )

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if variante == "marcador" {
                    Text(verbatim: [registro.prefixoExibicao, variante].compactMap { $0 }.joined(separator: " — "))
                        .padding(8)
                        .background(FrilaCor.superficie, in: Capsule())
                        .padding()
                }
            }
            .modifier(RegistroDebugModifier(registro: registro, variante: $variante))
    }
}

extension View {
    func exemploDebugEntrada() -> some View { modifier(ExemploDebugEntrada()) }
}
#endif
