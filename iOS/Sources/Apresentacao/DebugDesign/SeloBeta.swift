#if FRILA_BETA
import SwiftUI

/// Selo discreto que avisa qual build é este: só existe no esquema Frila-Beta, nunca no Prod.
/// Cinco toques seguidos nele ligam ou desligam o modo de design (`ControleModoDesign`), para quem
/// testa no aparelho do TestFlight sem Xcode. Para o testador comum é só um aviso.
struct SeloBeta: View {
    static let texto = "BETA · servidor de teste"
    static let toquesParaAlternar = 5
    static let janelaEntreToques: TimeInterval = 1.5

    @State private var toques = 0
    @State private var ultimoToque: Date?

    var body: some View {
        Text(verbatim: Self.texto)
            .font(FrilaTipo.nota)
            .foregroundStyle(FrilaCor.textoSecundario)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { registrarToque() }
            .accessibilityIdentifier("selo-beta")
    }

    private func registrarToque(agora: Date = .now) {
        if let ultimoToque, agora.timeIntervalSince(ultimoToque) > Self.janelaEntreToques {
            toques = 0
        }
        ultimoToque = agora
        toques += 1
        if toques >= Self.toquesParaAlternar {
            toques = 0
            ControleModoDesign.compartilhado.alternar()
        }
    }
}
#endif
