import SwiftUI

/// Canonical Opportunity Detail View for Frila.
/// Full-screen destination view pushed onto `NavigationStack` when an opportunity card is selected.
/// Transposição integral da linguagem Editorial & Deck com fundo drywall,
/// Dado em Destaque (FrilaLPEStatCard), Ciclo de Vida (FrilaLPEFlowStepper),
/// Escopo Técnico (FrilaLPENumberedList .card) e Competências em FrilaLPEEditorialTag.
public struct FrilaLPEOpportunityDetailView: View {
    public let item: FrilaLPEOpportunityItem
    public let isDark: Bool
    public let showsNavigationTitle: Bool
    public let onApply: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let typography = FrilaLPETypography()

    public init(
        item: FrilaLPEOpportunityItem,
        isDark: Bool = false,
        showsNavigationTitle: Bool = true,
        onApply: (() -> Void)? = nil
    ) {
        self.item = item
        self.isDark = isDark
        self.showsNavigationTitle = showsNavigationTitle
        self.onApply = onApply
    }

    public var body: some View {
        let content = ScrollView {
            if item.isSinglePayment || !item.shiftHours.isEmpty {
                shiftOpportunityContent
                    .padding(FrilaLPEGeometry.space20)
            } else {
                archivalOpportunityContent
                    .padding(FrilaLPEGeometry.space20)
            }
        }
        .background(FrilaLPEColor.dynamicCanvas(isDark: isDark))

        if showsNavigationTitle {
            content
                .navigationTitle(item.isSinglePayment ? (item.title.isEmpty ? String(localized: "Vaga", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : item.title) : (item.client.isEmpty ? String(localized: "Oportunidade", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : item.client))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        } else {
            content
        }
    }

    // MARK: - Layout Canônico de Turno / Vaga (Screenshot 3)
    @ViewBuilder
    private var shiftOpportunityContent: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space16) {
            // Header: Título da Função e Subtítulo
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: item.role.isEmpty ? (item.title.isEmpty ? "Vaga a definir" : item.title) : item.role)
                    .font(FrilaLPETypography.bricolage(size: 28, weight: .bold))
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))

                if item.roleIsCustom {
                    FrilaLPECustomRoleChip(isDark: isDark)
                }

                headerSubtitleView
            }
            .accessibilityElement(children: .combine)

            // Card 1: Quando, Horário, Valor e Posições (2x2 Grid)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quando", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.shiftDate.isEmpty ? "A definir" : item.shiftDate)
                            .font(FrilaLPETypography.captionBold)
                            .foregroundColor(item.shiftDate.isEmpty ? FrilaLPEColor.dynamicTextMuted(isDark: isDark) : FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Horário", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.shiftHours.isEmpty ? "A definir" : item.shiftHours)
                            .font(FrilaLPETypography.captionBold)
                            .foregroundColor(item.shiftHours.isEmpty ? FrilaLPEColor.dynamicTextMuted(isDark: isDark) : FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Valor", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.payPerPosition > 0 ? "\(FrilaLPEMoney.total(item.payPerPosition)) \(item.paymentUnitLabel)" : "A definir")
                            .font(FrilaLPETypography.captionBold)
                            .foregroundColor(item.payPerPosition > 0 ? FrilaLPEColor.dynamicTextPrimary(isDark: isDark) : FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Posições", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: positionsLabel)
                            .font(FrilaLPETypography.captionBold)
                            .foregroundColor(item.positionsTotal > 0 ? FrilaLPEColor.dynamicTextPrimary(isDark: isDark) : FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("O valor é integral: o Frila não desconta taxa do turno.", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.caption)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
            }
            .padding(FrilaLPEGeometry.space16)
            .background(FrilaLPEColor.dynamicSurfaceSubtle(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                    .stroke(FrilaLPEColor.dynamicHairline(isDark: isDark), lineWidth: 1)
            }

            // Card 2: O QUE ESTÁ INCLUSO
            VStack(alignment: .leading, spacing: 10) {
                Text("O QUE ESTÁ INCLUSO", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.microBold)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .tracking(FrilaLPETypography.trackingMicro)

                inclusaoRow(label: "Refeição", value: item.mealIncluded ? "sim" : "não")
                inclusaoRow(label: "Transporte", value: item.transportIncluded ? "sim" : "não")
                inclusaoRow(label: "Material próprio", value: item.bringOwnMaterial ? "sim" : "não")

                let trimmedDress = item.dressCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedDress.isEmpty {
                    inclusaoRow(label: "Traje", value: trimmedDress)
                }

                let trimmedContact = item.contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedContact.isEmpty {
                    inclusaoRow(label: "Quem recebe você", value: trimmedContact)
                }
            }
            .padding(FrilaLPEGeometry.space16)
            .background(FrilaLPEColor.dynamicSurfaceSubtle(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                    .stroke(FrilaLPEColor.dynamicHairline(isDark: isDark), lineWidth: 1)
            }

            // Card 3 & 4: Métricas de Reputação e Urgência
            metricsSectionView

            // Aviso de Privacidade & Contato
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(FrilaLPEFonteDoSistema.fonte(size: 15, weight: .medium))
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .padding(.top, 2)

                Text("Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(item.client.isEmpty ? "contratante" : item.client) para combinar o turno.", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.caption)
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .lineSpacing(3)
            }
            .padding(FrilaLPEGeometry.space14)
            .background(FrilaLPEColor.dynamicSurfaceSubtle(isDark: isDark).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))

            // Botão Principal de Candidatura (100% Capsule)
            Button(action: {
                if let onApply = onApply {
                    onApply()
                } else {
                    dismiss()
                }
            }) {
                Text("Candidatar-me", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: FrilaLPEGeometry.buttonHeightProminent)
            }
            .buttonStyle(FrilaLPEPillButtonStyle(variant: .primary, isDark: isDark))
            .accessibilityLabel(item.client.isEmpty ? String(localized: "Candidatar-me para a vaga", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "Candidatar-me para a vaga de \(item.role) no \(item.client)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))

            // Ações Secundárias no Rodapé
            HStack(spacing: 24) {
                Button(String(localized: "Denunciar", table: "FrilaLPEEstudio", bundle: bundleApresentacao)) {}
                    .font(FrilaLPETypography.captionMedium)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .underline()

                Button(String(localized: "Bloquear", table: "FrilaLPEEstudio", bundle: bundleApresentacao)) {}
                    .font(FrilaLPETypography.captionMedium)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .underline()
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var headerSubtitleSegments: [(text: String, isPrimary: Bool)] {
        let trimmedClient = item.client.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = item.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDistance = item.distanceText.trimmingCharacters(in: .whitespacesAndNewlines)

        var segments: [(text: String, isPrimary: Bool)] = []
        if !trimmedClient.isEmpty {
            segments.append((text: trimmedClient, isPrimary: true))
        }
        if !trimmedAddress.isEmpty {
            segments.append((text: trimmedAddress, isPrimary: false))
        }
        if !trimmedDistance.isEmpty {
            segments.append((text: trimmedDistance, isPrimary: false))
        }
        return segments
    }

    @ViewBuilder
    private var headerSubtitleView: some View {
        let segments = headerSubtitleSegments
        if segments.isEmpty {
            Text("Local a definir", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.caption)
                .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
        } else {
            HStack(spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text(",", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    }
                    Text(verbatim: segment.text)
                        .font(segment.isPrimary ? FrilaLPETypography.captionMedium : FrilaLPETypography.caption)
                        .foregroundColor(segment.isPrimary ? FrilaLPEColor.dynamicTextPrimary(isDark: isDark) : FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                }
            }
        }
    }

    private var positionsLabel: String {
        if item.positionsTotal <= 0 {
            return "A definir"
        } else if item.positionsTotal == 1 {
            return "1 vaga"
        } else {
            return "\(item.positionsOpen) aberta\(item.positionsOpen == 1 ? "" : "s") de \(item.positionsTotal)"
        }
    }

    @ViewBuilder
    private var metricsSectionView: some View {
        let trimmedReputationCount = item.reputationCount.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrgencyText = item.urgencyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReputation = !trimmedReputationCount.isEmpty
        let hasUrgency = !trimmedUrgencyText.isEmpty

        if hasReputation || hasUrgency {
            HStack(spacing: FrilaLPEGeometry.space12) {
                if hasReputation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: trimmedReputationCount)
                            .font(FrilaLPETypography.bricolage(size: 24, weight: .bold))
                            .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                        Text(verbatim: item.reputationLabel.isEmpty ? "avaliação positiva" : item.reputationLabel)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FrilaLPEGeometry.space16)
                    .background(FrilaLPEColor.dynamicSurfaceSubtle(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                            .stroke(FrilaLPEColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                    }
                }

                if hasUrgency {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Urgência", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.bricolage(size: 24, weight: .bold))
                            .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                        Text(verbatim: trimmedUrgencyText)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FrilaLPEGeometry.space16)
                    .background(FrilaLPEColor.dynamicSurfaceSubtle(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                            .stroke(FrilaLPEColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                    }
                }
            }
        }
    }

    private func inclusaoRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.body)
                .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
            Text(verbatim: value)
                .font(FrilaLPETypography.bodyBold)
                .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
            Spacer()
        }
    }

    // MARK: - Layout de Portfólio / Acervo (Archival)
    @ViewBuilder
    private var archivalOpportunityContent: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space20) {
            mediaFrameView
            titleStackView
            FrilaLPEOpportunitySpecGrid(item: item, typography: typography, isDark: isDark)
            guaranteeStatCardView
            contractLifecycleView
            technicalScopeView
            competenciesView
            actionSectionView
        }
    }

    @ViewBuilder
    private var mediaFrameView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FrilaLPEColor.primary900.opacity(0.85),
                            FrilaLPEColor.dynamicCanvas(isDark: true)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16/10, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo.artframe")
                        .font(FrilaLPEFonteDoSistema.fonte(size: 56, weight: .ultraLight))
                        .foregroundColor(Color.white.opacity(0.35))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .stroke(FrilaLPEColor.dynamicMediaOutline(isDark: isDark), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Imagem de apresentação da oportunidade para \(item.client)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
    }

    @ViewBuilder
    private var titleStackView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VAGA DISPONÍVEL // FRILA BRASIL", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.mono(size: 11, weight: .bold))
                .foregroundColor(isDark ? FrilaLPEColor.primary400 : FrilaLPEColor.primary700)
                .tracking(FrilaLPETypography.trackingMicro)

            Text(verbatim: item.placardTitle)
                .font(FrilaLPETypography.bricolage(size: 26, weight: .bold))
                .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: item.client)
                .font(FrilaLPETypography.bodyBold)
                .foregroundColor(FrilaLPEColor.dynamicInkSecondary(isDark: isDark))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var guaranteeStatCardView: some View {
        FrilaLPEStatCard(
            content: .metric(
                number: FrilaLPEMoney.total(item.totalBudget),
                label: "100% do valor garantido e liberado sem desconto de taxa para o profissional.",
                source: "Garantia de Pagamento Integral Frila",
                isMonumental: true
            ),
            isDark: isDark
        )
    }

    @ViewBuilder
    private var contractLifecycleView: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space10) {
            Text("ETAPAS DA OPORTUNIDADE", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.microBold)
                .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaLPETypography.trackingMicro)

            FrilaLPEFlowStepper(
                steps: [
                    FrilaLPEFlowStepItem(
                        stepNumber: "01",
                        title: "Alinhamento",
                        subtitle: "Combinação de horário e detalhes da função",
                        isHot: false,
                        isCompleted: true
                    ),
                    FrilaLPEFlowStepItem(
                        stepNumber: "02",
                        title: "Atuação",
                        subtitle: "Realização do turno ou entrega acordada",
                        isHot: true,
                        isCompleted: false
                    ),
                    FrilaLPEFlowStepItem(
                        stepNumber: "03",
                        title: "Pagamento",
                        subtitle: "Liberação do valor integral sem desconto",
                        isHot: false,
                        isCompleted: false
                    )
                ],
                isDark: isDark
            )
        }
    }

    @ViewBuilder
    private var technicalScopeView: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space10) {
            Text("DETALHES E ATIVIDADES", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.microBold)
                .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaLPETypography.trackingMicro)

            FrilaLPENumberedList(
                items: [
                    FrilaLPENumberedListItem(
                        index: "01",
                        title: "Função e Local",
                        description: "\(item.title), em regime \(item.location)."
                    ),
                    FrilaLPENumberedListItem(
                        index: "02",
                        title: "Duração",
                        description: "Vigência de \(item.duration)."
                    ),
                    FrilaLPENumberedListItem(
                        index: "03",
                        title: "Pagamento Garantido",
                        description: "Valor integral de \(FrilaLPEMoney.total(item.totalBudget)), sem taxas descontadas do profissional."
                    )
                ],
                style: .card,
                isDark: isDark
            )
        }
    }

    @ViewBuilder
    private var competenciesView: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space10) {
            Text("TAGS E REQUISITOS", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.microBold)
                .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaLPETypography.trackingMicro)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaLPEGeometry.space8) {
                    ForEach(item.tags, id: \.self) { tag in
                        FrilaLPEEditorialTag(tag, isDark: isDark)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionSectionView: some View {
        HStack(alignment: .center) {
            FrilaLPEPriceTag(
                amount: item.rateHourly,
                estimate: item.totalBudget,
                paradigm: typography.paradigm,
                isDark: isDark
            )

            Spacer()

            Button(action: {
                if let onApply = onApply {
                    onApply()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 8) {
                    Text("Candidatar-me", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                        .font(FrilaLPETypography.button)
                    Image(systemName: "arrow.up.right")
                        .font(FrilaLPEFonteDoSistema.fonte(size: 13, weight: .bold))
                }
            }
            .buttonStyle(FrilaLPEPillButtonStyle(variant: .primary, isDark: isDark))
            .accessibilityLabel(String(localized: "Candidatar-me à vaga de \(item.client)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
        }
        .padding(.top, 10)
    }
}
