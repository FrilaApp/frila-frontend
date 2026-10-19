import SwiftUI

public typealias SearchCapsule = FrilaSearchCapsule

/// Estilo de interação tátil para os segmentos da cápsula de busca.
/// Fornece compressão tátil sutil, realce translúcido de seleção e feedback háptico.
public struct SearchCapsuleZoneButtonStyle: ButtonStyle {
    public let cornerRadius: CGFloat
    public let isCapsule: Bool

    @Environment(\.accessibilityReduceMotion) private var envReduceMotion

    public init(cornerRadius: CGFloat = 10, isCapsule: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isCapsule = isCapsule
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = envReduceMotion
        configuration.label
            .background {
                Group {
                    if isCapsule {
                        Capsule()
                            .fill(FrilaCor.controle)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(FrilaCor.controle)
                    }
                }
                .padding(.vertical, FrilaEspaco.minimo)
                .padding(.horizontal, FrilaEspaco.fio)
                .opacity(configuration.isPressed ? 0.85 : 0.0)
            }
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .animation(
                FrilaMovimento.animacao(FrilaMovimento.molaTatil, reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension ButtonStyle where Self == SearchCapsuleZoneButtonStyle {
    static func searchZone(cornerRadius: CGFloat = 10) -> SearchCapsuleZoneButtonStyle {
        SearchCapsuleZoneButtonStyle(cornerRadius: cornerRadius, isCapsule: false)
    }

    static var searchTrigger: SearchCapsuleZoneButtonStyle {
        SearchCapsuleZoneButtonStyle(isCapsule: true)
    }
}

/// Cápsula canônica de busca e descoberta rápida do Frila (FrilaSearchCapsule).
/// Arquitetura em 3 zonas interativas (Área, Contrato, Orçamento) com gatilho de busca,
/// alvos de toque mínimos de 44 pt e adaptação completa a Dynamic Type e modo escuro.
public struct FrilaSearchCapsule: View {
    public let isDark: Bool
    public let isGlass: Bool
    public let activeCount: Int
    public let craftQuery: String
    public let termsQuery: String
    public let budgetQuery: String
    public let onSelectZone: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let rotuloArea = "ÁREA"
    private let rotuloContrato = "CONTRATO"
    private let rotuloOrcamento = "ORÇAMENTO"
    private let rotuloKeycap = "⌘K"
    private let a11yArea = "Filtro de Área"
    private let a11yContrato = "Filtro de Contrato"
    private let a11yOrcamento = "Filtro de Orçamento"
    private let a11yBuscar = "Buscar ou pressionar Command K"
    private let hintArea = "Toque para filtrar por especialidade e competências"
    private let hintContrato = "Toque para filtrar por duração e regime de trabalho"
    private let hintOrcamento = "Toque para abrir o histograma de remuneração"

    public init(
        isDark: Bool = false,
        isGlass: Bool = true,
        activeCount: Int = 38,
        craftQuery: String = "Design Tech",
        termsQuery: String = "Retainer",
        budgetQuery: String = "R$ 120–R$ 160/h",
        onSelectZone: @escaping (Int) -> Void = { _ in }
    ) {
        self.isDark = isDark
        self.isGlass = isGlass
        self.activeCount = activeCount
        self.craftQuery = craftQuery
        self.termsQuery = termsQuery
        self.budgetQuery = budgetQuery
        self.onSelectZone = onSelectZone
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityStackedZones
            } else {
                ViewThatFits(in: .horizontal) {
                    zones(showsKeycap: true)
                    zones(showsKeycap: false)
                    compactZones
                    superCompactZones
                }
            }
        }
    }

    // MARK: - Layout Regular / Wide

    private func zones(showsKeycap: Bool) -> some View {
        HStack(spacing: 0) {
            // Zona 1: Área / Craft
            Button(action: { onSelectZone(0) }) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "sparkles")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.marca)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: rotuloArea)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .tracking(0.8)
                            .lineLimit(1)
                        Text(verbatim: craftQuery)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, FrilaEspaco.faixa)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .accessibilityLabel(Text(verbatim: "\(a11yArea): \(craftQuery)"))
            .accessibilityHint(Text(verbatim: hintArea))

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(width: 1, height: 22)

            // Zona 2: Contrato / Terms
            Button(action: { onSelectZone(1) }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: rotuloContrato)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .tracking(0.8)
                            .lineLimit(1)
                        Text(verbatim: termsQuery)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .accessibilityLabel(Text(verbatim: "\(a11yContrato): \(termsQuery)"))
            .accessibilityHint(Text(verbatim: hintContrato))

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(width: 1, height: 22)

            // Zona 3: Orçamento / Budget
            Button(action: { onSelectZone(2) }) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.sucesso)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: rotuloOrcamento)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .tracking(0.8)
                            .lineLimit(1)
                        Text(verbatim: budgetQuery)
                            .font(FrilaTipo.meta.weight(.semibold).monospacedDigit())
                            .foregroundStyle(FrilaCor.texto)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .layoutPriority(1)
            .accessibilityLabel(Text(verbatim: "\(a11yOrcamento): \(budgetQuery)"))
            .accessibilityHint(Text(verbatim: hintOrcamento))

            Spacer(minLength: FrilaEspaco.pequeno)

            // Gatilho de busca
            Button(action: { onSelectZone(3) }) {
                HStack(spacing: 6) {
                    if showsKeycap {
                        Text(verbatim: rotuloKeycap)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Image(systemName: "magnifyingglass")
                        .font(FrilaTipo.meta.weight(.bold))
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                        .frame(width: 36, height: 36)
                        .background(FrilaCor.marca, in: Circle())
                }
                .padding(.trailing, FrilaEspaco.pequeno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchTrigger)
            .accessibilityLabel(Text(verbatim: a11yBuscar))
        }
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .background { capsuleBackground }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        }
        .elevacaoFrila(.sutil)
    }

    // MARK: - Layout Compacto

    private var compactZones: some View {
        HStack(spacing: 0) {
            Button(action: { onSelectZone(0) }) {
                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "sparkles")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.marca)
                    Text(verbatim: craftQuery)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .lineLimit(1)
                }
                .padding(.horizontal, FrilaEspaco.pequeno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.pequeno))
            .accessibilityLabel(Text(verbatim: "\(a11yArea): \(craftQuery)"))

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(width: 1, height: 20)

            Button(action: { onSelectZone(1) }) {
                Text(verbatim: termsQuery)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(1)
                    .padding(.horizontal, FrilaEspaco.pequeno)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.pequeno))
            .accessibilityLabel(Text(verbatim: "\(a11yContrato): \(termsQuery)"))

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(width: 1, height: 20)

            Button(action: { onSelectZone(2) }) {
                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "dollarsign")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.sucesso)
                    Text(verbatim: budgetQuery)
                        .font(FrilaTipo.meta.weight(.semibold).monospacedDigit())
                        .foregroundStyle(FrilaCor.texto)
                        .lineLimit(1)
                }
                .padding(.horizontal, FrilaEspaco.pequeno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.pequeno))
            .layoutPriority(1)
            .accessibilityLabel(Text(verbatim: "\(a11yOrcamento): \(budgetQuery)"))

            Spacer(minLength: 0)

            Button(action: { onSelectZone(3) }) {
                Image(systemName: "magnifyingglass")
                    .font(FrilaTipo.meta.weight(.bold))
                    .foregroundStyle(FrilaCor.sobrePrimaria)
                    .frame(width: 32, height: 32)
                    .background(FrilaCor.marca, in: Circle())
                    .padding(.trailing, 6)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.searchTrigger)
            .accessibilityLabel(Text(verbatim: a11yBuscar))
        }
        .frame(minHeight: 48)
        .background { capsuleBackground }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        }
        .elevacaoFrila(.sutil)
    }

    // MARK: - Layout Supercompacto

    private var superCompactZones: some View {
        HStack(spacing: 6) {
            Button(action: { onSelectZone(0) }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.marca)
                    Text(verbatim: "\(craftQuery), \(budgetQuery)")
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .lineLimit(1)
                }
                .padding(.leading, FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.pequeno))
            .accessibilityLabel(Text(verbatim: "\(craftQuery), \(budgetQuery)"))

            Spacer(minLength: 0)

            Button(action: { onSelectZone(2) }) {
                Image(systemName: "slider.horizontal.3")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 32, height: 32)
                    .background(FrilaCor.controle, in: Circle())
                    .padding(.trailing, 6)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.searchTrigger)
            .accessibilityLabel(Text(verbatim: a11yOrcamento))
        }
        .frame(minHeight: FrilaMetrica.alvoMinimo)
        .background { capsuleBackground }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        }
        .elevacaoFrila(.sutil)
    }

    // MARK: - Layout Adaptável em Acessibilidade (AX5)

    private var accessibilityStackedZones: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Button(action: { onSelectZone(0) }) {
                HStack(spacing: FrilaEspaco.medio) {
                    Image(systemName: "sparkles")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.marca)
                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: rotuloArea)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: craftQuery)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                    }
                    Spacer()
                }
                .padding(FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .accessibilityLabel(Text(verbatim: "\(a11yArea): \(craftQuery)"))

            Divider().background(FrilaCor.divisoria)

            Button(action: { onSelectZone(1) }) {
                HStack(spacing: FrilaEspaco.medio) {
                    Image(systemName: "clock")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: rotuloContrato)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: termsQuery)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                    }
                    Spacer()
                }
                .padding(FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .accessibilityLabel(Text(verbatim: "\(a11yContrato): \(termsQuery)"))

            Divider().background(FrilaCor.divisoria)

            Button(action: { onSelectZone(2) }) {
                HStack(spacing: FrilaEspaco.medio) {
                    Image(systemName: "dollarsign")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.sucesso)
                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: rotuloOrcamento)
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: budgetQuery)
                            .font(FrilaTipo.corpo.weight(.semibold).monospacedDigit())
                            .foregroundStyle(FrilaCor.texto)
                    }
                    Spacer()
                }
                .padding(FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.searchZone(cornerRadius: FrilaRaio.medio))
            .accessibilityLabel(Text(verbatim: "\(a11yOrcamento): \(budgetQuery)"))

            Button(action: { onSelectZone(3) }) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "magnifyingglass")
                        .font(FrilaTipo.botao)
                    Text(verbatim: a11yBuscar)
                        .font(FrilaTipo.botao)
                }
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.marca, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.tatil)
        }
        .padding(FrilaEspaco.medio)
        .background {
            RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                .fill(isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(FrilaCor.superficie))
        }
        .overlay {
            RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        }
        .elevacaoFrila(.sutil)
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        if isGlass {
            Capsule()
                .fill(.ultraThinMaterial)
        } else {
            Capsule()
                .fill(FrilaCor.superficie)
        }
    }
}

#Preview("SearchCapsule - Tamanho padrão") {
    VStack(spacing: FrilaEspaco.grande) {
        FrilaSearchCapsule(isGlass: true)
        FrilaSearchCapsule(isDark: true, isGlass: false)
    }
    .padding(FrilaEspaco.grande)
    .background(FrilaCor.fundo)
}

#Preview("SearchCapsule - Acessibilidade AX5") {
    VStack(spacing: FrilaEspaco.grande) {
        FrilaSearchCapsule(isGlass: true)
    }
    .padding(FrilaEspaco.grande)
    .background(FrilaCor.fundo)
    .environment(\.dynamicTypeSize, .accessibility5)
}
