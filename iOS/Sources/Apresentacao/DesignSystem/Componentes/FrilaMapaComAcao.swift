import SwiftUI

/// Prévia decorativa e ação de mapa sob um único contorno. O botão é uma exceção
/// à cápsula padrão: o topo reto se une à prévia e só o contorno externo arredonda.
public struct FrilaMapaComAcao: View {
    public let abrirMapa: () -> Void

    public init(abrirMapa: @escaping () -> Void) {
        self.abrirMapa = abrirMapa
    }

    public var body: some View {
        VStack(spacing: 0) {
            PreviaMapaGenerica()

            Button(action: abrirMapa) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "map")
                        .font(FrilaTipo.nota)
                        .accessibilityHidden(true)
                    Text("Abrir no mapa", bundle: bundleApresentacao)
                        .font(FrilaTipo.botaoPadrao)
                }
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .padding(.vertical, FrilaEspaco.pequeno)
                .foregroundStyle(FrilaColor.mapActionForeground)
                .background(FrilaColor.mapActionBackground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.tatil(scale: 1))
            .accessibilityIdentifier("abrir-no-mapa")
        }
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

/// Desenho neutro, sem coordenadas nem precisão geográfica sugerida.
private struct PreviaMapaGenerica: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(FrilaCor.controle)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w, y: h * 0.24))

                    path.move(to: CGPoint(x: w * 0.22, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.52, y: h))

                    path.move(to: CGPoint(x: w * 0.54, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h))

                    path.move(to: CGPoint(x: 0, y: h * 0.44))
                    path.addLine(to: CGPoint(x: w, y: h * 0.52))
                }
                .stroke(FrilaCor.divisoria, lineWidth: 2)

                let ponto = CGPoint(x: w * 0.48, y: h * 0.42)
                Circle()
                    .fill(FrilaCor.marca.opacity(0.18))
                    .frame(width: 20, height: 20)
                    .position(ponto)

                Circle()
                    .fill(FrilaCor.marca)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(FrilaCor.fundo, lineWidth: 1.5))
                    .position(ponto)
            }
        }
        .frame(height: 72)
        .accessibilityHidden(true)
    }
}
