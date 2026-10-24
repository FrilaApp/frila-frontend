import SwiftUI

/// Frila Design System - Liquid Glass Shaders & Specular Surfaces
/// Implements Apple iOS 26+ Liquid Glass specifications with specular edge light reflection.
public struct FrilaGlassModifier: ViewModifier {
    public enum Tier {
        case regular
        case prominent
        case subtle
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    public let tier: Tier
    public let cornerRadius: CGFloat
    public let isInteractive: Bool
    
    private var isDark: Bool {
        colorScheme == .dark
    }
    
    public init(
        tier: Tier = .regular,
        cornerRadius: CGFloat = FrilaGeometry.radiusCard,
        isInteractive: Bool = false
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                glassBackground
            }
            .overlay {
                specularHighlightOverlay
            }
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        switch tier {
        case .regular:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        case .prominent:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(FrilaColor.dynamicBrandAccent(isDark: isDark).opacity(0.92))
                .background(.ultraThinMaterial)
        case .subtle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        }
    }
    
    private var specularHighlightOverlay: some View {
        let topOpacity = tier == .prominent ? (isDark ? 0.45 : 0.40) : (isDark ? 0.35 : 0.65)
        let bottomColor = isDark
            ? Color.white.opacity(tier == .prominent ? 0.12 : 0.06)
            : Color.black.opacity(tier == .prominent ? 0.20 : 0.08)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(topOpacity),
                        bottomColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }
}

public extension View {
    /// Applies the Frila Liquid Glass treatment with specular edge lighting
    func frilaLiquidGlass(
        tier: FrilaGlassModifier.Tier = .regular,
        cornerRadius: CGFloat = FrilaGeometry.radiusCard,
        isInteractive: Bool = false
    ) -> some View {
        modifier(FrilaGlassModifier(tier: tier, cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}
