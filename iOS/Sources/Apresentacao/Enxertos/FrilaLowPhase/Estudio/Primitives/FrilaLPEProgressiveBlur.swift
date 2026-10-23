import SwiftUI

/// Frila Design System - Progressive Blur
/// Desfoque progressivo para o conteúdo que rola por trás de uma barra fixa (ex.: cabeçalho do FrilaLPEFlowStepper).
/// Atrás da barra o desfoque fica no máximo, para que o texto dela continue legível; depois dela, ao longo de
/// `fadeLength`, o conteúdo recupera nitidez e contraste de forma gradual, sem linha divisória nem sombra.
public struct FrilaLPEProgressiveBlur: View, Sendable {
    public enum Edge: Sendable {
        case top
        case bottom
    }

    public let edge: Edge
    public let isDark: Bool
    public let fadeLength: CGFloat

    /// Opacidade do véu de papel na zona de força máxima: o conteúdo atrás vira textura, nunca compete com o texto da barra.
    public static func veilOpacity(isDark: Bool) -> Double {
        isDark ? 0.9 : 0.88
    }

    /// Véu de canvas opaco na zona sólida e material que se apaga antes do véu na dissolução.
    /// No escuro o material é mais claro que o papel: com véu parcial, a faixa do cabeçalho fica um tom
    /// acima da página e a borda desenha uma linha clara sobre papel vazio. Opaco, o cabeçalho tem o
    /// tom exato da página e a dissolução nunca clareia o fundo.
    public let opaqueVeil: Bool
    /// Opacidade do material na dissolução (0...1). Sobre papel vazio o material não tem o que desfocar
    /// e só clareia a faixa; quem usa pode apagá-lo quando nada passa por trás.
    public let materialOpacity: Double

    public init(
        edge: Edge = .top,
        isDark: Bool = false,
        fadeLength: CGFloat = FrilaLPEGeometry.space24,
        opaqueVeil: Bool = false,
        materialOpacity: Double = 1
    ) {
        self.edge = edge
        self.isDark = isDark
        self.fadeLength = fadeLength
        self.opaqueVeil = opaqueVeil
        self.materialOpacity = min(max(materialOpacity, 0), 1)
    }

    private var solidVeilOpacity: Double {
        opaqueVeil ? 1 : Self.veilOpacity(isDark: isDark)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if edge == .top {
                solidLayers
                fadeLayers.frame(height: fadeLength)
            } else {
                fadeLayers.frame(height: fadeLength)
                solidLayers
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Zona de força máxima sem máscara: evita um passe offscreen na GPU onde a opacidade é uniforme.
    private var solidLayers: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            // Véu de canvas: devolve o contraste da barra sem virar uma faixa sólida.
            Rectangle()
                .fill(FrilaLPEColor.dynamicCanvas(isDark: isDark).opacity(solidVeilOpacity))
        }
    }

    private var fadeLayers: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(opaqueVeil ? materialFadeMask : fadeMask(1))
                .opacity(materialOpacity)

            Rectangle()
                .fill(FrilaLPEColor.dynamicCanvas(isDark: isDark))
                .mask(fadeMask(solidVeilOpacity))
        }
    }

    /// Curva com saída suave: cai rápido logo após a barra e se dissolve devagar, evitando borda perceptível.
    /// Material que cai mais depressa que o véu: a sobra de claridade (material × véu ausente) fica abaixo de 15%.
    private var materialFadeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black.opacity(0.3), location: 0.35),
                .init(color: .black.opacity(0.05), location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
    }

    private func fadeMask(_ opacity: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(opacity), location: 0),
                .init(color: .black.opacity(opacity * 0.55), location: 0.35),
                .init(color: .black.opacity(opacity * 0.18), location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
    }
}

/// Fixa `header` na borda superior de uma ScrollView e aplica o desfoque progressivo ao conteúdo que passa por trás dele.
/// Camada própria `FrilaLPEProgressiveBlur` com força máxima atrás do cabeçalho e dissolução ao longo de `fadeTail` abaixo dele,
/// sobre material do sistema (seguro com TextField). `fadeTail` soma ao inset superior: não repita esse respiro no conteúdo.
/// iOS 26+: soma o efeito de borda suave nativo via barra de área segura. Versões anteriores: inset de área segura.
public struct FrilaLPEProgressiveBlurHeaderModifier<Header: View>: ViewModifier {
    public let isDark: Bool
    public let fadeTail: CGFloat
    /// Quanto da dissolução sobe para dentro do cabeçalho. Com texto de apoio no rodapé do cabeçalho, o conteúdo
    /// continua visível atrás dele e a máscara termina mais cedo.
    public let fadeInset: CGFloat
    /// Intensidade do desfoque (0...1). Em repouso, sem conteúdo por baixo, o material deixa a faixa
    /// do cabeçalho um tom acima do papel e o rabo desenha um degradê solto; com 0 o cabeçalho fica
    /// no mesmo papel da página e o desfoque surge conforme o conteúdo passa por baixo.
    public let strength: CGFloat
    /// iOS 26: soma a borda suave nativa. Desligue quando o conteúdo encaixa rente ao cabeçalho:
    /// a borda nativa esmaece a primeira linha abaixo dele e o desfoque próprio já cobre o papel.
    public let systemEdgeEffect: Bool
    /// Dissolução que pende abaixo da borda do cabeçalho, desenhada sobre o conteúdo sem somar ao inset.
    /// Alonga a transição sem afastar o conteúdo; quem usa controla o comprimento (ex.: zero quando o
    /// repouso encaixa uma linha de texto rente ao cabeçalho, para não velá-la).
    public let overhang: CGFloat
    /// Véu opaco na zona sólida (ver `FrilaLPEProgressiveBlur.opaqueVeil`).
    public let opaqueVeil: Bool
    /// Opacidade do material na dissolução (ver `FrilaLPEProgressiveBlur.materialOpacity`).
    public let materialOpacity: Double
    public let header: Header

    public init(
        isDark: Bool,
        fadeTail: CGFloat = FrilaLPEGeometry.space24,
        fadeInset: CGFloat = 0,
        strength: CGFloat = 1,
        systemEdgeEffect: Bool = true,
        overhang: CGFloat = 0,
        opaqueVeil: Bool = false,
        materialOpacity: Double = 1,
        header: Header
    ) {
        self.isDark = isDark
        self.fadeTail = fadeTail
        self.fadeInset = fadeInset
        self.strength = min(max(strength, 0), 1)
        self.systemEdgeEffect = systemEdgeEffect
        self.overhang = max(overhang, 0)
        self.opaqueVeil = opaqueVeil
        self.materialOpacity = materialOpacity
        self.header = header
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .safeAreaBar(edge: .top, spacing: 0) { blurredHeader }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectHidden(!systemEdgeEffect, for: .top)
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) { blurredHeader }
        }
    }

    /// O rabo de dissolução entra no inset da rolagem: em repouso o conteúdo começa abaixo dele e nunca fica velado.
    /// O `overhang` estende a mesma dissolução para baixo da borda (padding negativo), fora do inset.
    private var blurredHeader: some View {
        header
            .padding(.bottom, fadeTail)
            .background(alignment: .top) {
                FrilaLPEProgressiveBlur(edge: .top, isDark: isDark, fadeLength: fadeInset + fadeTail + overhang, opaqueVeil: opaqueVeil, materialOpacity: materialOpacity)
                    .padding(.bottom, -overhang)
                    .opacity(strength)
                    .ignoresSafeArea(edges: .top)
            }
    }
}

public extension View {
    /// Fixa um cabeçalho sobre a rolagem com desfoque progressivo no conteúdo que passa por trás dele.
    func frilaLPEProgressiveBlurHeader<Header: View>(
        isDark: Bool,
        fadeTail: CGFloat = FrilaLPEGeometry.space24,
        fadeInset: CGFloat = 0,
        strength: CGFloat = 1,
        systemEdgeEffect: Bool = true,
        overhang: CGFloat = 0,
        opaqueVeil: Bool = false,
        materialOpacity: Double = 1,
        @ViewBuilder header: () -> Header
    ) -> some View {
        modifier(FrilaLPEProgressiveBlurHeaderModifier(
            isDark: isDark,
            fadeTail: fadeTail,
            fadeInset: fadeInset,
            strength: strength,
            systemEdgeEffect: systemEdgeEffect,
            overhang: overhang,
            opaqueVeil: opaqueVeil,
            materialOpacity: materialOpacity,
            header: header()
        ))
    }
}

public extension FrilaLPEProgressiveBlur {
    /// Distância de rolagem em que o desfoque vai de ausente a pleno.
    static let emergenceDistance: CGFloat = FrilaLPEGeometry.space24

    /// Intensidade do desfoque para um deslocamento de rolagem (medido a partir da borda do cabeçalho),
    /// quantizada em passos de 0,05 para não reavaliar a tela a cada quadro.
    static func strength(forScrollOffset offset: CGFloat) -> CGFloat {
        let raw = min(max(offset / emergenceDistance, 0), 1)
        return (raw * 20).rounded() / 20
    }

    /// Fração do `overhang` a usar: zero com o repouso numa âncora (linha rente ao cabeçalho) e plena
    /// a partir de `emergenceDistance` de distância da âncora mais próxima. Quantizada em 0,05.
    static func overhangFraction(offset: CGFloat, anchors: [CGFloat]) -> CGFloat {
        guard let nearest = anchors.map({ abs(offset - $0) }).min() else { return 1 }
        let raw = min(max(nearest / emergenceDistance, 0), 1)
        return (raw * 20).rounded() / 20
    }
}
