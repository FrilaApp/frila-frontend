import SwiftUI

/// Canonical Opportunity Detail View for Frila.
/// Full-screen destination view pushed onto `NavigationStack` when an opportunity card is selected.
/// Transposição integral da linguagem Editorial & Deck com fundo drywall,
/// Dado em Destaque (FrilaStatCard), Ciclo de Vida (FrilaFlowStepper),
/// Escopo Técnico (FrilaNumberedList .card) e Competências em FrilaEditorialTag.
public struct FrilaOpportunityDetailView: View {
    public let item: FrilaOpportunityItem
    public let isDark: Bool
    public let showsNavigationTitle: Bool
    /// Enxerto: na prévia de quem publica, o botão principal diz "Publicar vaga" em vez de "Candidatar-me".
    public let isPublisherPreview: Bool
    public let onApply: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let typography = FrilaTypography()

    public init(
        item: FrilaOpportunityItem,
        isDark: Bool = false,
        showsNavigationTitle: Bool = true,
        isPublisherPreview: Bool = false,
        onApply: (() -> Void)? = nil
    ) {
        self.item = item
        self.isDark = isDark
        self.showsNavigationTitle = showsNavigationTitle
        self.isPublisherPreview = isPublisherPreview
        self.onApply = onApply
    }

    public var body: some View {
        let content = ScrollView {
            if item.isSinglePayment || !item.shiftHours.isEmpty {
                shiftOpportunityContent
                    .padding(FrilaGeometry.space20)
            } else {
                archivalOpportunityContent
                    .padding(FrilaGeometry.space20)
            }
        }
        .background(FrilaColor.dynamicCanvas(isDark: isDark))

        if showsNavigationTitle {
            content
                .navigationTitle(item.isSinglePayment ? (item.title.isEmpty ? String(localized: "Vaga", table: "Estudio", bundle: bundleApresentacao) : item.title) : (item.client.isEmpty ? String(localized: "Oportunidade", table: "Estudio", bundle: bundleApresentacao) : item.client))
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
        VStack(alignment: .leading, spacing: FrilaGeometry.space16) {
            // Header: Título da Função e Subtítulo
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: item.role.isEmpty ? (item.title.isEmpty ? "Vaga a definir" : item.title) : item.role)
                    .font(FrilaTypography.bricolage(size: 28, weight: .bold))
                    .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))

                if item.roleIsCustom {
                    FrilaCustomRoleChip(isDark: isDark)
                }

                headerSubtitleView
            }
            .accessibilityElement(children: .combine)

            // Card 1: Quando, Horário, Valor e Posições (2x2 Grid)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quando", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.shiftDate.isEmpty ? "A definir" : item.shiftDate)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(item.shiftDate.isEmpty ? FrilaColor.dynamicTextMuted(isDark: isDark) : FrilaColor.dynamicTextPrimary(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Horário", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.shiftHours.isEmpty ? "A definir" : item.shiftHours)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(item.shiftHours.isEmpty ? FrilaColor.dynamicTextMuted(isDark: isDark) : FrilaColor.dynamicTextPrimary(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Valor", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: item.payPerPosition > 0 ? "\(FrilaMoney.total(item.payPerPosition)) \(item.paymentUnitLabel)" : "A definir")
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(item.payPerPosition > 0 ? FrilaColor.dynamicTextPrimary(isDark: isDark) : FrilaColor.dynamicTextMuted(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Posições", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        Text(verbatim: positionsLabel)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(item.positionsTotal > 0 ? FrilaColor.dynamicTextPrimary(isDark: isDark) : FrilaColor.dynamicTextMuted(isDark: isDark))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("O valor é integral: o Frila não desconta taxa do turno.", tableName: "Estudio", bundle: bundleApresentacao)
                    .font(FrilaTypography.caption)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
            }
            .padding(FrilaGeometry.space16)
            .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                    .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
            }

            // Card 2: O QUE ESTÁ INCLUSO
            VStack(alignment: .leading, spacing: 10) {
                Text("O QUE ESTÁ INCLUSO", tableName: "Estudio", bundle: bundleApresentacao)
                    .font(FrilaTypography.microBold)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .tracking(FrilaTypography.trackingMicro)

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
            .padding(FrilaGeometry.space16)
            .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                    .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
            }

            // Card 3 & 4: Métricas de Reputação e Urgência
            metricsSectionView

            // Aviso de Privacidade & Contato
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(FrilaFonteDoSistema.fonte(size: 15, weight: .medium))
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .padding(.top, 2)

                Text("Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(item.client.isEmpty ? "contratante" : item.client) para combinar o turno.", tableName: "Estudio", bundle: bundleApresentacao)
                    .font(FrilaTypography.caption)
                    .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                    .lineSpacing(3)
            }
            .padding(FrilaGeometry.space14)
            .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))

            // Botão Principal de Candidatura (100% Capsule)
            Button(action: {
                if let onApply = onApply {
                    onApply()
                } else {
                    dismiss()
                }
            }) {
                Text(verbatim: applyTitle)
                    .font(FrilaTypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: FrilaGeometry.buttonHeightProminent)
            }
            .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
            .accessibilityLabel(isPublisherPreview ? publishAccessibilityLabel : item.client.isEmpty ? String(localized: "Candidatar-me para a vaga", table: "Estudio", bundle: bundleApresentacao) : String(localized: "Candidatar-me para a vaga de \(item.role) no \(item.client)", table: "Estudio", bundle: bundleApresentacao))

            // Ações Secundárias no Rodapé
            HStack(spacing: 24) {
                Button(String(localized: "Denunciar", table: "Estudio", bundle: bundleApresentacao)) {}
                    .font(FrilaTypography.captionMedium)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .underline()

                Button(String(localized: "Bloquear", table: "Estudio", bundle: bundleApresentacao)) {}
                    .font(FrilaTypography.captionMedium)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
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
            Text("Local a definir", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.caption)
                .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
        } else {
            HStack(spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text(",", tableName: "Estudio", bundle: bundleApresentacao)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    }
                    Text(verbatim: segment.text)
                        .font(segment.isPrimary ? FrilaTypography.captionMedium : FrilaTypography.caption)
                        .foregroundColor(segment.isPrimary ? FrilaColor.dynamicTextPrimary(isDark: isDark) : FrilaColor.dynamicTextMuted(isDark: isDark))
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
            HStack(spacing: FrilaGeometry.space12) {
                if hasReputation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: trimmedReputationCount)
                            .font(FrilaTypography.bricolage(size: 24, weight: .bold))
                            .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        Text(verbatim: item.reputationLabel.isEmpty ? "avaliação positiva" : item.reputationLabel)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FrilaGeometry.space16)
                    .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                            .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                    }
                }

                if hasUrgency {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Urgência", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.bricolage(size: 24, weight: .bold))
                            .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        Text(verbatim: trimmedUrgencyText)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FrilaGeometry.space16)
                    .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                            .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                    }
                }
            }
        }
    }

    private func inclusaoRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.body)
                .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
            Text(verbatim: value)
                .font(FrilaTypography.bodyBold)
                .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
            Spacer()
        }
    }

    // MARK: - Layout de Portfólio / Acervo (Archival)
    @ViewBuilder
    private var archivalOpportunityContent: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space20) {
            mediaFrameView
            titleStackView
            FrilaOpportunitySpecGrid(item: item, typography: typography, isDark: isDark)
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
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FrilaColor.primary900.opacity(0.85),
                            FrilaColor.dynamicCanvas(isDark: true)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16/10, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo.artframe")
                        .font(FrilaFonteDoSistema.fonte(size: 56, weight: .ultraLight))
                        .foregroundColor(Color.white.opacity(0.35))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                .stroke(FrilaColor.dynamicMediaOutline(isDark: isDark), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Imagem de apresentação da oportunidade para \(item.client)", table: "Estudio", bundle: bundleApresentacao))
    }

    @ViewBuilder
    private var titleStackView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VAGA DISPONÍVEL // FRILA BRASIL", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.mono(size: 11, weight: .bold))
                .foregroundColor(isDark ? FrilaColor.primary400 : FrilaColor.primary700)
                .tracking(FrilaTypography.trackingMicro)

            Text(verbatim: item.placardTitle)
                .font(FrilaTypography.bricolage(size: 26, weight: .bold))
                .foregroundColor(FrilaColor.dynamicInk(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: item.client)
                .font(FrilaTypography.bodyBold)
                .foregroundColor(FrilaColor.dynamicInkSecondary(isDark: isDark))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var guaranteeStatCardView: some View {
        FrilaStatCard(
            content: .metric(
                number: FrilaMoney.total(item.totalBudget),
                label: "100% do valor garantido e liberado sem desconto de taxa para o profissional.",
                source: "Garantia de Pagamento Integral Frila",
                isMonumental: true
            ),
            isDark: isDark
        )
    }

    @ViewBuilder
    private var contractLifecycleView: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space10) {
            Text("ETAPAS DA OPORTUNIDADE", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.microBold)
                .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaTypography.trackingMicro)

            FrilaFlowStepper(
                steps: [
                    FrilaFlowStepItem(
                        stepNumber: "01",
                        title: "Alinhamento",
                        subtitle: "Combinação de horário e detalhes da função",
                        isHot: false,
                        isCompleted: true
                    ),
                    FrilaFlowStepItem(
                        stepNumber: "02",
                        title: "Atuação",
                        subtitle: "Realização do turno ou entrega acordada",
                        isHot: true,
                        isCompleted: false
                    ),
                    FrilaFlowStepItem(
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
        VStack(alignment: .leading, spacing: FrilaGeometry.space10) {
            Text("DETALHES E ATIVIDADES", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.microBold)
                .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaTypography.trackingMicro)

            FrilaNumberedList(
                items: [
                    FrilaNumberedListItem(
                        index: "01",
                        title: "Função e Local",
                        description: "\(item.title), em regime \(item.location)."
                    ),
                    FrilaNumberedListItem(
                        index: "02",
                        title: "Duração",
                        description: "Vigência de \(item.duration)."
                    ),
                    FrilaNumberedListItem(
                        index: "03",
                        title: "Pagamento Garantido",
                        description: "Valor integral de \(FrilaMoney.total(item.totalBudget)), sem taxas descontadas do profissional."
                    )
                ],
                style: .card,
                isDark: isDark
            )
        }
    }

    @ViewBuilder
    private var competenciesView: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space10) {
            Text("TAGS E REQUISITOS", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.microBold)
                .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                .tracking(FrilaTypography.trackingMicro)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaGeometry.space8) {
                    ForEach(item.tags, id: \.self) { tag in
                        FrilaEditorialTag(tag, isDark: isDark)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionSectionView: some View {
        HStack(alignment: .center) {
            FrilaPriceTag(
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
                    Text(verbatim: applyTitle)
                        .font(FrilaTypography.button)
                    Image(systemName: "arrow.up.right")
                        .font(FrilaFonteDoSistema.fonte(size: 13, weight: .bold))
                }
            }
            .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
            .accessibilityLabel(isPublisherPreview ? publishAccessibilityLabel : String(localized: "Candidatar-me à vaga de \(item.client)", table: "Estudio", bundle: bundleApresentacao))
        }
        .padding(.top, 10)
    }

    private var applyTitle: String {
        isPublisherPreview
            ? String(localized: "Publicar vaga", table: "Estudio", bundle: bundleApresentacao)
            : String(localized: "Candidatar-me", table: "Estudio", bundle: bundleApresentacao)
    }

    private var publishAccessibilityLabel: String {
        String(localized: "Publicar vaga de \(item.role)", table: "Estudio", bundle: bundleApresentacao)
    }
}
