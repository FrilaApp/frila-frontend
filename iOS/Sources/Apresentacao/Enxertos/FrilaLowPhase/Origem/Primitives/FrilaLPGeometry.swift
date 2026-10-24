import SwiftUI

/// Frila Design System - Spatial Geometry, Radii & Touch Standards (Genie Benchmark)
public enum FrilaLPGeometry {
    // MARK: - Corner Radii
    
    /// Full capsule for buttons, search pills, and badges
    public static let radiusPill: CGFloat = 9999
    
    /// Bottom sheet modal radius
    public static let radiusSheet: CGFloat = 24
    
    /// Media container & card radius
    public static let radiusCard: CGFloat = 16
    
    /// Input field & stepper radius
    public static let radiusInput: CGFloat = 14
    
    /// Nested interior badges
    public static let radiusNested: CGFloat = 8
    
    // MARK: - Human Interface Hitbox Standard
    
    /// Apple HIG strict minimum interactive target (44x44pt)
    public static let hitboxMinimum: CGFloat = 44
    
    // MARK: - Button Heights
    
    /// Compact button visual height (32pt), with 44pt touch hitbox extension
    public static let buttonHeightCompact: CGFloat = 32
    
    /// Standard button interactive height (44pt)
    public static let buttonHeightStandard: CGFloat = 44
    
    /// Prominent hero button interactive height (52pt)
    public static let buttonHeightProminent: CGFloat = 52
    
    // MARK: - Spacing System (4pt / 8pt Fluid Grid with Optical Steps)
    public static let space2: CGFloat = 2
    public static let space4: CGFloat = 4
    public static let space6: CGFloat = 6
    public static let space8: CGFloat = 8
    public static let space10: CGFloat = 10
    public static let space12: CGFloat = 12
    public static let space14: CGFloat = 14
    public static let space16: CGFloat = 16
    public static let space20: CGFloat = 20
    public static let space24: CGFloat = 24
    public static let space32: CGFloat = 32
    public static let space48: CGFloat = 48

    // MARK: - Passive Status Chip (Genie "Sent" Pattern)
    // Non-interactive, so it is exempt from the 44pt hitbox rule.
    public static let chipHeight: CGFloat = 28
    public static let chipPaddingHorizontal: CGFloat = space12
    /// Gap between an optional SF Symbol and the chip label.
    public static let chipIconSpacing: CGFloat = space4

    // MARK: - Price Tag
    /// Gap between a price and its muted unit ("R$ 160" + "/h"), aligned on the first baseline.
    public static let priceUnitSpacing: CGFloat = space2
    /// Gap between the price line and its estimate line.
    public static let priceEstimateSpacing: CGFloat = space2

    // MARK: - Concentric Radius Rule
    /// Calculates optimal nested interior radius: R_inner = max(0, R_outer - Padding)
    public static func concentricInnerRadius(outerRadius: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, outerRadius - padding)
    }

    /// Calculates optimal outer container radius: R_outer = R_inner + Padding
    public static func concentricOuterRadius(innerRadius: CGFloat, padding: CGFloat) -> CGFloat {
        innerRadius + padding
    }

    // MARK: - Editorial Geometry Tokens
    /// Canonical corner radius for editorial cards (.card: 28px)
    public static let radiusCardEditorial: CGFloat = 28

    /// Canonical height of the editorial flow stepper indicator bar (6pt)
    public static let flowStepBarHeight: CGFloat = 6

    // MARK: - Toque Fora (Outside Tap Dismissal)
    /// Limiar máximo de deslocamento para reconhecimento de toque fora (10 pt).
    /// Movimento superior a este valor caracteriza arrasto ou rolagem e cancela o fechamento (M20 / SPEC 2.2).
    public static let outsideTapMaxMovement: CGFloat = 10
}

// MARK: - Touch Hitbox Modifier
public struct FrilaLPMinimumHitboxModifier: ViewModifier {
    public let minSize: CGFloat
    
    public init(minSize: CGFloat = FrilaLPGeometry.hitboxMinimum) {
        self.minSize = minSize
    }
    
    public func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

public extension View {
    /// Enforces HIG 44x44pt minimum touch hitbox on interactive controls
    func frilaLPHitbox(minSize: CGFloat = FrilaLPGeometry.hitboxMinimum) -> some View {
        modifier(FrilaLPMinimumHitboxModifier(minSize: minSize))
    }
}
