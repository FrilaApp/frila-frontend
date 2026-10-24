import SwiftUI

// MARK: - Rótulo acima do campo

/// Rótulo de campo no padrão "rótulo acima", usado em todos os formulários de entrada.
public struct FrilaLPFieldLabel: View {
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(verbatim: title)
            .font(FrilaLPTypography.Native.fieldLabel)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Título de seção em caixa alta, como "FUNÇÕES".
public struct FrilaLPSectionOverline: View {
    @Environment(\.colorScheme) private var colorScheme
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(verbatim: title.uppercased())
            .font(FrilaLPTypography.Native.overline)
            .tracking(FrilaLPTypography.trackingMicro)
            .foregroundStyle(FrilaLPColor.dynamicSecondaryText(isDark: colorScheme == .dark))
            .padding(.horizontal, FrilaLPGeometry.space16)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Campo contornado

/// Caixa branca de 52 pt com contorno fino, base de todos os campos do formulário.
public struct FrilaLPOutlinedField<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let isFocused: Bool
    public let horizontalPadding: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(
        isFocused: Bool = false,
        horizontalPadding: CGFloat = FrilaLPGeometry.space16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isFocused = isFocused
        self.horizontalPadding = horizontalPadding
        self.content = content
    }

    private var isDark: Bool { colorScheme == .dark }

    public var body: some View {
        HStack(spacing: FrilaLPGeometry.space12) {
            content()
        }
        .font(FrilaLPTypography.Native.fieldValue)
        .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: FrilaLPGeometry.fieldHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FrilaLPGeometry.radiusInput, style: .continuous)
                .fill(FrilaLPColor.dynamicGroupedSurface(isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FrilaLPGeometry.radiusInput, style: .continuous)
                .strokeBorder(
                    isFocused ? FrilaLPColor.dynamicSelectionFill(isDark: isDark) : FrilaLPColor.dynamicBorder(isDark: isDark),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: isFocused)
    }
}

/// Campo de escolha que abre um menu nativo: valor à esquerda, ícone opcional e chevron à direita.
public struct FrilaLPMenuField<MenuContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    public let value: String
    public let leadingSystemImage: String?
    public let accessibilityTitle: String
    @ViewBuilder public let menuContent: () -> MenuContent

    public init(
        value: String,
        leadingSystemImage: String? = nil,
        accessibilityTitle: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.value = value
        self.leadingSystemImage = leadingSystemImage
        self.accessibilityTitle = accessibilityTitle
        self.menuContent = menuContent
    }

    public var body: some View {
        Menu {
            menuContent()
        } label: {
            FrilaLPOutlinedField {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .foregroundStyle(FrilaLPColor.dynamicSecondaryText(isDark: colorScheme == .dark))
                        .accessibilityHidden(true)
                }
                Text(verbatim: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FrilaLPColor.dynamicSecondaryText(isDark: colorScheme == .dark))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FrilaLPHapticBounceButtonStyle(scale: 0.98))
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(value)
    }
}

// MARK: - Contador de posições

/// Contador com menos e mais dentro do campo contornado. Algarismos tabulares, toque de 44 pt.
public struct FrilaLPQuantityStepper: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var value: Int
    public let range: ClosedRange<Int>
    public let accessibilityTitle: String

    public init(value: Binding<Int>, range: ClosedRange<Int>, accessibilityTitle: String) {
        self._value = value
        self.range = range
        self.accessibilityTitle = accessibilityTitle
    }

    private var isDark: Bool { colorScheme == .dark }

    public var body: some View {
        FrilaLPOutlinedField(horizontalPadding: FrilaLPGeometry.space4) {
            stepButton(systemImage: "minus", enabled: value > range.lowerBound) { change(by: -1) }
            Text(verbatim: "\(value)")
                .font(FrilaLPTypography.Native.tickerCount)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
                .frame(maxWidth: .infinity)
            stepButton(systemImage: "plus", enabled: value < range.upperBound) { change(by: 1) }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(Text(verbatim: "\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: 1)
            case .decrement: change(by: -1)
            @unknown default: break
            }
        }
    }

    private func change(by delta: Int) {
        let next = min(max(value + delta, range.lowerBound), range.upperBound)
        guard next != value else { return }
        withAnimation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion)) {
            value = next
        }
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: FrilaLPGeometry.stepperButtonSize, height: FrilaLPGeometry.stepperButtonSize)
                .background(Circle().fill(FrilaLPColor.dynamicControlFill(isDark: isDark)))
                .frame(width: FrilaLPGeometry.hitboxMinimum, height: FrilaLPGeometry.hitboxMinimum)
                .contentShape(Circle())
        }
        .buttonStyle(FrilaLPHapticBounceButtonStyle(scale: 0.9))
        .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }
}

// MARK: - Campo de valor em reais

/// Digitação estilo caixa eletrônico: cada dígito entra pela direita nos centavos.
/// "R$" fica em cinza, fora do texto editável.
public struct FrilaLPCurrencyField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding public var cents: Int
    public let accessibilityTitle: String
    public var fieldID: String?
    @State private var defaultFieldID: String = "currency_\(UUID().uuidString)"
    @FocusState private var isFocused: Bool

    /// Teto de R$ 99.999,99.
    public static let maxDigits = 7

    public init(cents: Binding<Int>, accessibilityTitle: String, fieldID: String? = nil) {
        self._cents = cents
        self.accessibilityTitle = accessibilityTitle
        self.fieldID = fieldID
    }

    public func fieldID(_ id: String) -> FrilaLPCurrencyField {
        var copy = self
        copy.fieldID = id
        return copy
    }

    private var effectiveFieldID: String {
        fieldID ?? defaultFieldID
    }

    private var digits: Binding<String> {
        Binding(
            get: { FrilaLPMoney.fieldDigits(cents: cents) },
            set: { cents = Self.cents(fromTyped: $0, previous: cents) }
        )
    }

    /// Converte o texto digitado em centavos, ignorando tudo que não é dígito.
    public static func cents(fromTyped text: String, previous: Int) -> Int {
        let onlyDigits = text.filter(\.isASCIIDigit)
        guard onlyDigits.count <= maxDigits else { return previous }
        return Int(onlyDigits) ?? 0
    }

    public var body: some View {
        FrilaLPOutlinedField(isFocused: isFocused) {
            Text("R$", bundle: bundleApresentacao)
                .foregroundStyle(FrilaLPColor.dynamicSecondaryText(isDark: colorScheme == .dark))
                .accessibilityHidden(true)
            TextField(String(localized: "0,00", bundle: bundleApresentacao), text: digits)
                .focused($isFocused)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .accessibilityLabel(accessibilityTitle)
                .accessibilityValue(FrilaLPMoney.spoken(cents: cents))
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .frilaLPFormField(id: effectiveFieldID, isFocused: isFocused, onDismiss: { isFocused = false })
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

// MARK: - Chip de escolha

/// Aparência do chip de escolha: 32 pt visuais, cápsula, seleção em preenchimento escuro.
public struct FrilaLPChoiceChipLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    public let title: String
    public let isSelected: Bool
    public let leadingSystemImage: String?
    public let trailingSystemImage: String?

    public init(_ title: String, isSelected: Bool, leadingSystemImage: String? = nil, trailingSystemImage: String? = nil) {
        self.title = title
        self.isSelected = isSelected
        self.leadingSystemImage = leadingSystemImage
        self.trailingSystemImage = trailingSystemImage
    }

    private var isDark: Bool { colorScheme == .dark }

    public var body: some View {
        HStack(spacing: FrilaLPGeometry.space6) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage)
                    .font(.footnote.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .font(FrilaLPTypography.Native.chip)
                .lineLimit(1)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(isSelected ? FrilaLPColor.dynamicOnSelection(isDark: isDark) : FrilaLPColor.dynamicTextPrimary(isDark: isDark))
        .padding(.horizontal, FrilaLPGeometry.space14)
        .frame(minHeight: FrilaLPGeometry.choiceChipHeight)
        .background(
            Capsule().fill(isSelected ? FrilaLPColor.dynamicSelectionFill(isDark: isDark) : FrilaLPColor.dynamicGroupedSurface(isDark: isDark))
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.clear : FrilaLPColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        )
        // 32 pt visuais + 6 pt acima e abaixo = 44 pt de toque.
        .padding(.vertical, (FrilaLPGeometry.hitboxMinimum - FrilaLPGeometry.choiceChipHeight) / 2)
        .contentShape(Rectangle())
    }
}

/// Chip de escolha tocável, com o salto tátil dos chips do sistema.
public struct FrilaLPChoiceChip: View {
    public let title: String
    public let isSelected: Bool
    public let leadingSystemImage: String?
    public let action: () -> Void

    public init(_ title: String, isSelected: Bool, leadingSystemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.leadingSystemImage = leadingSystemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            FrilaLPChoiceChipLabel(title, isSelected: isSelected, leadingSystemImage: leadingSystemImage)
        }
        .buttonStyle(FrilaLPChipBounceButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Previews
