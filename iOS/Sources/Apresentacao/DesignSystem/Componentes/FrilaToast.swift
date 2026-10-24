import SwiftUI

/// Frila Design System - Curatorial Notification HUD / Toast (Wave 3 Motion)
/// Implements a floating Liquid Glass HUD with concentric geometry,
/// asymmetric spring entrance, vertical swipe-to-dismiss, and press-and-hold pause.
public enum FrilaToastStyle: Sendable, Hashable {
    case standard
    case success
    case bookmark
    case warning
    case error

    public var defaultSymbol: String {
        switch self {
        case .standard: return "bell.fill"
        case .success: return "checkmark.circle.fill"
        case .bookmark: return "bookmark.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    public func accentColor(isDark: Bool) -> Color {
        switch self {
        case .standard:
            return isDark ? FrilaColor.primary400 : FrilaColor.primary500
        case .success:
            return FrilaColor.dynamicVerified(isDark: isDark)
        case .bookmark:
            return isDark ? FrilaColor.primary400 : FrilaColor.primary500
        case .warning:
            return FrilaColor.dynamicWarningText(isDark: isDark)
        case .error:
            return FrilaColor.dynamicError(isDark: isDark)
        }
    }

    public func iconBackgroundColor(isDark: Bool) -> Color {
        switch self {
        case .standard, .bookmark:
            return isDark ? FrilaColor.primary500.opacity(0.18) : FrilaColor.primary50
        case .success:
            return FrilaColor.dynamicVerifiedBg(isDark: isDark)
        case .warning:
            return FrilaColor.dynamicWarningBg(isDark: isDark)
        case .error:
            return FrilaColor.dynamicErrorBg(isDark: isDark)
        }
    }
}

/// Identifiable item model for dynamic toast presentation
public struct FrilaToastItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let style: FrilaToastStyle
    public let duration: Double

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: FrilaToastStyle = .success,
        duration: Double = 3.5
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.systemImage = systemImage ?? style.defaultSymbol
        self.duration = duration
    }
}

/// Curatorial Floating Liquid Glass Toast HUD
public struct FrilaToastView: View {
    public let item: FrilaToastItem
    public let isDark: Bool
    public let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffsetY: CGFloat = 0
    @State private var isPressing: Bool = false
    @State private var remainingTime: Double = 3.5
    @State private var isTimerActive: Bool = true

    // Outer radius for concentric geometry
    private let outerRadius: CGFloat = 20
    private let iconPadding: CGFloat = 6
    private var iconRadius: CGFloat {
        FrilaGeometry.concentricInnerRadius(outerRadius: outerRadius, padding: iconPadding)
    }

    public init(
        item: FrilaToastItem,
        isDark: Bool = false,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isDark = isDark
        self.onDismiss = onDismiss
        self._remainingTime = State(initialValue: item.duration)
    }

    public var body: some View {
        HStack(spacing: FrilaGeometry.space12) {
            // Curatorial Leading SF Symbol (concentric geometry)
            ZStack {
                Circle()
                    .fill(item.style.iconBackgroundColor(isDark: isDark))
                    .frame(width: 32, height: 32)

                Image(systemName: item.systemImage)
                    .font(FrilaFonteDoSistema.fonte(size: 15, weight: .bold))
                    .foregroundColor(item.style.accentColor(isDark: isDark))
            }
            .accessibilityHidden(true)

            // Message Stack (No italic, upright museum placard typography)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.title)
                    .font(FrilaTypography.captionBold)
                    .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                    .lineLimit(1)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(FrilaTypography.caption)
                        .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            // Manual Dismiss Handle / Button (44pt hitbox compliant)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(FrilaFonteDoSistema.fonte(size: 12, weight: .bold))
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .padding(8)
                    .background(FrilaColor.dynamicBorder(isDark: isDark).opacity(0.3), in: Circle())
            }
            .buttonStyle(.plain)
            .frilaHitbox(minSize: FrilaGeometry.hitboxMinimum)
            .accessibilityLabel(String(localized: "Fechar notificação", table: "Estudio", bundle: bundleApresentacao))
        }
        .padding(.horizontal, FrilaGeometry.space16)
        .padding(.vertical, FrilaGeometry.space12)
        .background {
            // Liquid Glass base
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .overlay {
            // Specular highlight stroke
            specularStroke
        }
        .shadow(
            color: Color.black.opacity(isDark ? 0.40 : 0.12),
            radius: 16,
            x: 0,
            y: 8
        )
        .offset(y: dragOffsetY)
        .scaleEffect(isPressing ? 0.98 : 1.0)
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo), value: isPressing)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isPressing = true
                    isTimerActive = false // Pause auto-dismiss timer on touch / press
                    let translation = value.translation.height
                    if translation < 0 {
                        // Direct tracking on upward swipe
                        dragOffsetY = translation
                    } else {
                        // Elastic resistance when dragging downward
                        dragOffsetY = pow(translation, 0.72) * 1.6
                    }
                }
                .onEnded { value in
                    isPressing = false
                    isTimerActive = true // Resume timer on release
                    // Momentum and threshold evaluation: flick or drag past -32pt
                    let verticalTranslation = value.translation.height
                    let verticalVelocity = value.predictedEndTranslation.height - verticalTranslation
                    if verticalTranslation < -32 || verticalVelocity < -120 {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                            dragOffsetY = -160
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                            dragOffsetY = 0
                        }
                    }
                }
        )
        .task(id: item.id) {
            // Countdown loop that respects press-and-hold pause
            while remainingTime > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s tick
                if isTimerActive {
                    remainingTime -= 0.1
                }
            }
            onDismiss()
        }
    }

    private var specularStroke: some View {
        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDark ? 0.35 : 0.65),
                        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }
}

// MARK: - View Modifier for Easy Toast Attachment

public struct FrilaToastModifier: ViewModifier {
    @Binding public var item: FrilaToastItem?
    public let isDark: Bool?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hapticTrigger: UUID? = nil

    private var effectiveDark: Bool {
        isDark ?? (colorScheme == .dark)
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let currentItem = item {
                FrilaToastView(
                    item: currentItem,
                    isDark: effectiveDark,
                    onDismiss: {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                            item = nil
                        }
                    }
                )
                .padding(.horizontal, FrilaGeometry.space16)
                .padding(.top, 10)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .scale(scale: 0.92)
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.96)
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .top))
                        )
                )
                .zIndex(9999)
                .onAppear {
                    hapticTrigger = currentItem.id
                }
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo), value: item)
    }
}

public extension View {
    /// Presents a floating Curatorial Liquid Glass Toast HUD driven by an optional item binding.
    func frilaToast(item: Binding<FrilaToastItem?>, isDark: Bool? = nil) -> some View {
        modifier(FrilaToastModifier(item: item, isDark: isDark))
    }

    /// Presents a floating Curatorial Liquid Glass Toast HUD driven by a Boolean binding.
    func frilaToast(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: FrilaToastStyle = .success,
        duration: Double = 3.5,
        isDark: Bool? = nil
    ) -> some View {
        let itemBinding = Binding<FrilaToastItem?>(
            get: {
                if isPresented.wrappedValue {
                    return FrilaToastItem(
                        title: title,
                        subtitle: subtitle,
                        systemImage: systemImage,
                        style: style,
                        duration: duration
                    )
                }
                return nil
            },
            set: { newValue in
                isPresented.wrappedValue = (newValue != nil)
            }
        )
        return modifier(FrilaToastModifier(item: itemBinding, isDark: isDark))
    }
}

// MARK: - Previews
