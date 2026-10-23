import SwiftUI

/// Frila Design System - Curatorial Notification HUD / Toast (Wave 3 Motion)
/// Implements a floating Liquid Glass HUD with concentric geometry,
/// asymmetric spring entrance, vertical swipe-to-dismiss, and press-and-hold pause.
public enum FrilaLPEToastStyle: Sendable, Hashable {
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
            return isDark ? FrilaLPEColor.primary400 : FrilaLPEColor.primary500
        case .success:
            return FrilaLPEColor.dynamicVerified(isDark: isDark)
        case .bookmark:
            return isDark ? FrilaLPEColor.primary400 : FrilaLPEColor.primary500
        case .warning:
            return FrilaLPEColor.dynamicWarningText(isDark: isDark)
        case .error:
            return FrilaLPEColor.dynamicError(isDark: isDark)
        }
    }

    public func iconBackgroundColor(isDark: Bool) -> Color {
        switch self {
        case .standard, .bookmark:
            return isDark ? FrilaLPEColor.primary500.opacity(0.18) : FrilaLPEColor.primary50
        case .success:
            return FrilaLPEColor.dynamicVerifiedBg(isDark: isDark)
        case .warning:
            return FrilaLPEColor.dynamicWarningBg(isDark: isDark)
        case .error:
            return FrilaLPEColor.dynamicErrorBg(isDark: isDark)
        }
    }
}

/// Identifiable item model for dynamic toast presentation
public struct FrilaLPEToastItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let style: FrilaLPEToastStyle
    public let duration: Double

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: FrilaLPEToastStyle = .success,
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
public struct FrilaLPEToastView: View {
    public let item: FrilaLPEToastItem
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
        FrilaLPEGeometry.concentricInnerRadius(outerRadius: outerRadius, padding: iconPadding)
    }

    public init(
        item: FrilaLPEToastItem,
        isDark: Bool = false,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isDark = isDark
        self.onDismiss = onDismiss
        self._remainingTime = State(initialValue: item.duration)
    }

    public var body: some View {
        HStack(spacing: FrilaLPEGeometry.space12) {
            // Curatorial Leading SF Symbol (concentric geometry)
            ZStack {
                Circle()
                    .fill(item.style.iconBackgroundColor(isDark: isDark))
                    .frame(width: 32, height: 32)

                Image(systemName: item.systemImage)
                    .font(FrilaLPEFonteDoSistema.fonte(size: 15, weight: .bold))
                    .foregroundColor(item.style.accentColor(isDark: isDark))
            }
            .accessibilityHidden(true)

            // Message Stack (No italic, upright museum placard typography)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.title)
                    .font(FrilaLPETypography.captionBold)
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .lineLimit(1)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(FrilaLPETypography.caption)
                        .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            // Manual Dismiss Handle / Button (44pt hitbox compliant)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(FrilaLPEFonteDoSistema.fonte(size: 12, weight: .bold))
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .padding(8)
                    .background(FrilaLPEColor.dynamicBorder(isDark: isDark).opacity(0.3), in: Circle())
            }
            .buttonStyle(.plain)
            .frilaLPEHitbox(minSize: FrilaLPEGeometry.hitboxMinimum)
            .accessibilityLabel(String(localized: "Fechar notificação", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
        }
        .padding(.horizontal, FrilaLPEGeometry.space16)
        .padding(.vertical, FrilaLPEGeometry.space12)
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
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo), value: isPressing)
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
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                            dragOffsetY = -160
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo)) {
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

public struct FrilaLPEToastModifier: ViewModifier {
    @Binding public var item: FrilaLPEToastItem?
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
                FrilaLPEToastView(
                    item: currentItem,
                    isDark: effectiveDark,
                    onDismiss: {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                            item = nil
                        }
                    }
                )
                .padding(.horizontal, FrilaLPEGeometry.space16)
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
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo), value: item)
    }
}

public extension View {
    /// Presents a floating Curatorial Liquid Glass Toast HUD driven by an optional item binding.
    func frilaLPEToast(item: Binding<FrilaLPEToastItem?>, isDark: Bool? = nil) -> some View {
        modifier(FrilaLPEToastModifier(item: item, isDark: isDark))
    }

    /// Presents a floating Curatorial Liquid Glass Toast HUD driven by a Boolean binding.
    func frilaLPEToast(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: FrilaLPEToastStyle = .success,
        duration: Double = 3.5,
        isDark: Bool? = nil
    ) -> some View {
        let itemBinding = Binding<FrilaLPEToastItem?>(
            get: {
                if isPresented.wrappedValue {
                    return FrilaLPEToastItem(
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
        return modifier(FrilaLPEToastModifier(item: itemBinding, isDark: isDark))
    }
}

// MARK: - Previews
