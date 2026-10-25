import SwiftUI

/// Banner de notificação push no estilo iOS nativo (Screenshot 2).
/// Utilizado para exibir a candidatos como uma nova vaga aparece na tela de bloqueio do celular.
public struct FrilaShiftNotificationBanner: View {
    public let appTitle: String
    public let timeAgo: String
    public let title: String
    public let subtitle: String
    public let isDark: Bool
    public let forceLockScreenTheme: Bool
    public let action: (() -> Void)?

    public init(
        appTitle: String = "FRILA",
        timeAgo: String = "agora",
        title: String,
        subtitle: String,
        isDark: Bool = false,
        forceLockScreenTheme: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.appTitle = appTitle
        self.timeAgo = timeAgo
        self.title = title
        self.subtitle = subtitle
        self.isDark = isDark
        self.forceLockScreenTheme = forceLockScreenTheme
        self.action = action
    }

    private var bannerBackground: Color {
        if forceLockScreenTheme {
            return FrilaColor.bannerTelaDeBloqueioFundo
        } else {
            return FrilaColor.dynamicSurfaceSubtle(isDark: isDark)
        }
    }

    private var textPrimary: Color {
        if forceLockScreenTheme {
            return FrilaColor.bannerTelaDeBloqueioTexto
        } else {
            return FrilaColor.dynamicTextPrimary(isDark: isDark)
        }
    }

    private var textMuted: Color {
        if forceLockScreenTheme {
            return FrilaColor.bannerTelaDeBloqueioTextoApagado
        } else {
            return FrilaColor.dynamicTextMuted(isDark: isDark)
        }
    }

    public var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Top Row: App Label & Timestamp
                HStack {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(FrilaColor.primary500)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text("F", tableName: "Estudio", bundle: bundleApresentacao)
                                    .font(FrilaFonteDoSistema.fonte(size: 9, weight: .black))
                                    .foregroundColor(.white)
                                    .accessibilityHidden(true)
                            }

                        Text(verbatim: appTitle.uppercased())
                            .font(FrilaTypography.microBold)
                            .tracking(FrilaTypography.trackingMicro)
                            .foregroundColor(textMuted)
                    }

                    Spacer()

                    Text(verbatim: timeAgo)
                        .font(FrilaTypography.caption)
                        .foregroundColor(textMuted)
                }

                // Título da Vaga / Alerta
                Text(verbatim: title)
                    .font(FrilaTypography.bodyBold)
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Subtítulo / Estabelecimento, Bairro, Remuneração e Distância
                Text(verbatim: subtitle)
                    .font(FrilaTypography.caption)
                    .foregroundColor(textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, FrilaGeometry.space16)
            .padding(.vertical, FrilaGeometry.space14)
            .background(bannerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(forceLockScreenTheme ? 0.06 : (isDark ? 0.15 : 0.08)), lineWidth: 0.5)
            }
        }
        .buttonStyle(FrilaHapticBounceButtonStyle(scale: 0.98))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(appTitle), \(title), \(subtitle), \(timeAgo). Toque para ver detalhes.", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityAddTraits(.isButton)
    }
}
