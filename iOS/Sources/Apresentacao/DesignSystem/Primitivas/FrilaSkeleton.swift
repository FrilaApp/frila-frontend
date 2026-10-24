import SwiftUI

/// Frila Design System - Skeleton & Shimmer Molecular Primitives
/// Governed by Museum Wall Achromatic discipline and iOS 26+ Liquid Glass specular physics.
/// Strictly enforces concentric geometry, 100% round pill buttons, and accessibilityReduceMotion compliance.

/// Geometrical shape primitives authorized for skeleton bones in Frila
public enum FrilaSkeletonShape: Sendable, Equatable {
    case capsule
    case roundedRect(cornerRadius: CGFloat)
    case concentric(outerRadius: CGFloat, padding: CGFloat)
    case circle
}

/// Molecular structural bone view for skeleton screens
public struct FrilaSkeletonBone: View {
    public let shape: FrilaSkeletonShape
    public let isDark: Bool
    public let width: CGFloat?
    public let height: CGFloat?
    public let shouldShimmer: Bool
    
    public init(
        shape: FrilaSkeletonShape = .capsule,
        isDark: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        shouldShimmer: Bool = true
    ) {
        self.shape = shape
        self.isDark = isDark
        self.width = width
        self.height = height
        self.shouldShimmer = shouldShimmer
    }
    
    public var body: some View {
        resolvedView
            .frame(width: width, height: height)
            .frilaShimmer(isDark: isDark, isActive: shouldShimmer)
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var resolvedView: some View {
        let fill = FrilaColor.dynamicSkeletonBase(isDark: isDark)
        switch shape {
        case .capsule:
            Capsule().fill(fill)
        case .roundedRect(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        case .concentric(let outerRadius, let padding):
            RoundedRectangle(
                cornerRadius: FrilaGeometry.concentricInnerRadius(outerRadius: outerRadius, padding: padding),
                style: .continuous
            ).fill(fill)
        case .circle:
            Circle().fill(fill)
        }
    }
    
    // MARK: - Convenience Static Builders
    
    /// 100% round pill bone (Rule G6: Capsule 9999px)
    public static func pill(
        width: CGFloat? = nil,
        height: CGFloat,
        isDark: Bool = false,
        shouldShimmer: Bool = true
    ) -> FrilaSkeletonBone {
        FrilaSkeletonBone(shape: .capsule, isDark: isDark, width: width, height: height, shouldShimmer: shouldShimmer)
    }
    
    /// Concentric rounded rectangle bone matching parent container (Ro = Ri + P)
    public static func concentric(
        outerRadius: CGFloat,
        padding: CGFloat,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        isDark: Bool = false,
        shouldShimmer: Bool = true
    ) -> FrilaSkeletonBone {
        FrilaSkeletonBone(
            shape: .concentric(outerRadius: outerRadius, padding: padding),
            isDark: isDark,
            width: width,
            height: height,
            shouldShimmer: shouldShimmer
        )
    }
    
    /// Circular bone for avatars and icon placeholders
    public static func circle(
        diameter: CGFloat,
        isDark: Bool = false,
        shouldShimmer: Bool = true
    ) -> FrilaSkeletonBone {
        FrilaSkeletonBone(shape: .circle, isDark: isDark, width: diameter, height: diameter, shouldShimmer: shouldShimmer)
    }
}

/// Polarized specular shimmer modifier adhering to Museum Placard calmness and OLED anti-glare protection
public struct FrilaShimmerModifier: ViewModifier {
    public let isDark: Bool
    public let isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.2
    
    public init(isDark: Bool = false, isActive: Bool = true) {
        self.isDark = isDark
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        if !isActive || reduceMotion {
            // When reduced motion is requested or inactive, remain calm and static without animation
            content
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        let size = geo.size
                        let gradient = LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.35),
                                .init(color: specularHighlightColor, location: 0.50),
                                .init(color: .clear, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: UnitPoint(x: -0.3, y: -0.1),
                            endPoint: UnitPoint(x: 1.3, y: 1.1)
                        )
                        
                        Rectangle()
                            .fill(gradient)
                            .scaleEffect(x: 2.2, y: 2.2)
                            .offset(x: phase * size.width)
                            .blendMode(isDark ? .plusLighter : .sourceAtop)
                    }
                    .mask(content)
                }
                .onAppear {
                    guard !reduceMotion && isActive else { return }
                    withAnimation(FrilaMovimento.animacao(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.8)
                        .repeatForever(autoreverses: false), reduzir: FrilaMovimentoReduzido.ativo)) {
                        phase = 2.2
                    }
                }
        }
    }
    
    private var specularHighlightColor: Color {
        // Fresnel polarized reflection: pure alpha highlight without synthetic color tinting
        // Dark Mode: 9% white opacity (Y = 0.0285 < 0.0500 OLED anti-glare ceiling)
        // Light Mode: 42% white opacity (silky museum drywall sheen)
        isDark ? Color.white.opacity(0.09) : Color.white.opacity(0.42)
    }
}

public extension View {
    /// Applies curatorial polarized specular shimmer to any view
    func frilaShimmer(isDark: Bool = false, isActive: Bool = true) -> some View {
        modifier(FrilaShimmerModifier(isDark: isDark, isActive: isActive))
    }
    
    /// Semantic alias for skeleton shimmer
    func frilaSkeletonShimmer(isDark: Bool = false) -> some View {
        modifier(FrilaShimmerModifier(isDark: isDark, isActive: true))
    }
}
