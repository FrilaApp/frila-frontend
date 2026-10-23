import SwiftUI

/// Frila Design System - FrilaLPEEditorialTag
/// Tag editorial no padrão canônico Frila com geometria 100% Capsule (cornerRadius max),
/// borda refinada de 1pt em cor de sinal (#EA5A36), fundo tingido (#FFDDD2 / opaco no dark)
/// e tipografia curatorial. Utilizado para metadados curados, protocolos e tags técnicas.
public struct FrilaLPEEditorialTag: View {
    public let text: String
    public let isDark: Bool
    public let textColor: Color?

    public init(
        _ text: String,
        isDark: Bool = false,
        textColor: Color? = nil
    ) {
        self.text = text
        self.isDark = isDark
        self.textColor = textColor
    }

    public init(
        text: String,
        isDark: Bool = false,
        textColor: Color? = nil
    ) {
        self.text = text
        self.isDark = isDark
        self.textColor = textColor
    }

    private var resolvedTextColor: Color {
        textColor ?? (isDark ? FrilaLPEColor.primary400 : FrilaLPEColor.primary700)
    }

    private var backgroundColor: Color {
        isDark ? FrilaLPEColor.primary500.opacity(0.18) : FrilaLPEColor.primary100
    }

    private var borderColor: Color {
        FrilaLPEColor.dynamicBrandAccent(isDark: isDark)
    }

    public var body: some View {
        Text(verbatim: text.uppercased())
            .font(FrilaLPETypography.mono(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .bold))
            .tracking(FrilaLPETypography.trackingMicro)
            .foregroundColor(resolvedTextColor)
            .padding(.horizontal, FrilaLPEGeometry.chipPaddingHorizontal)
            .frame(height: FrilaLPEGeometry.chipHeight)
            .background(backgroundColor, in: Capsule())
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isStaticText)
    }
}
