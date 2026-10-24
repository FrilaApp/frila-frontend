import SwiftUI

/// Data model representing a freelance contract brief / opportunity in Frila
public struct FrilaOpportunityItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let client: String
    public let title: String
    public let year: String
    public let scope: String
    public let location: String
    public let duration: String
    public let seniority: String
    public let rateHourly: Int
    public let totalBudget: Int
    public let escrowVerified: Bool
    public let tags: [String]
    public let imageUrl: String
    
    // Propriedades do Modo de Turno / Form Canônico (Freela da vida real)
    public let role: String
    public let shiftDate: String
    public let shiftHours: String
    public let startTime: String
    public let endTime: String
    public let address: String
    public let distanceText: String
    public let payPerPosition: Int
    public let positionsTotal: Int
    public let positionsOpen: Int
    public let mealIncluded: Bool
    public let transportIncluded: Bool
    public let bringOwnMaterial: Bool
    public let dressCode: String
    public let contactPerson: String
    public let reputationCount: String
    public let reputationLabel: String
    public let urgencyText: String
    public let isSinglePayment: Bool
    public let paymentUnitLabel: String
    public let roleIsCustom: Bool
    
    public init(
        id: String,
        client: String,
        title: String,
        year: String = "2026",
        scope: String,
        location: String = "Remoto",
        duration: String = "3 Meses",
        seniority: String = "Qualquer Experiência",
        rateHourly: Int = 20,
        totalBudget: Int = 140,
        escrowVerified: Bool = true,
        tags: [String] = ["Pagamento Garantido", "Sem Desconto de Taxa"],
        imageUrl: String = "https://images.unsplash.com/photo-1554118811-1e0d58224f24",
        role: String = "",
        shiftDate: String = "Sex, 25/09",
        shiftHours: String = "",
        startTime: String = "18:00",
        endTime: String = "02:00",
        address: String = "",
        distanceText: String = "a 3,2 km",
        payPerPosition: Int = 140,
        positionsTotal: Int = 2,
        positionsOpen: Int = 1,
        mealIncluded: Bool = true,
        transportIncluded: Bool = false,
        bringOwnMaterial: Bool = false,
        dressCode: String = "camisa preta",
        contactPerson: String = "Renata, no balcão",
        reputationCount: String = "18 de 19",
        reputationLabel: String = "trabalhariam lá de novo",
        urgencyText: String = "quem aceitar primeiro fica com a vaga",
        isSinglePayment: Bool = true,
        paymentUnitLabel: String = "por turno",
        roleIsCustom: Bool = false
    ) {
        self.id = id
        self.client = client
        self.title = title
        self.year = year
        self.scope = scope
        self.location = location
        self.duration = duration
        self.seniority = seniority
        self.rateHourly = rateHourly
        self.totalBudget = totalBudget
        self.escrowVerified = escrowVerified
        self.tags = tags
        self.imageUrl = imageUrl
        self.role = role.isEmpty ? title : role
        self.shiftDate = shiftDate
        self.shiftHours = shiftHours.isEmpty
            ? ((!startTime.isEmpty && !endTime.isEmpty) ? "\(startTime) às \(endTime)" : "")
            : shiftHours
        self.startTime = startTime
        self.endTime = endTime
        self.address = address.isEmpty ? location : address
        self.distanceText = distanceText
        self.payPerPosition = payPerPosition
        self.positionsTotal = positionsTotal
        self.positionsOpen = positionsOpen
        self.mealIncluded = mealIncluded
        self.transportIncluded = transportIncluded
        self.bringOwnMaterial = bringOwnMaterial
        self.dressCode = dressCode
        self.contactPerson = contactPerson
        self.reputationCount = reputationCount
        self.reputationLabel = reputationLabel
        self.urgencyText = urgencyText
        self.isSinglePayment = isSinglePayment
        self.paymentUnitLabel = paymentUnitLabel
        self.roleIsCustom = roleIsCustom
    }
}

extension FrilaOpportunityItem {
    /// Museum placard title, "Title, Year". Plain String rendered verbatim (no italic parsing).
    public var placardTitle: String {
        "\(title), \(year)"
    }
}

// MARK: - Card Press Feedback Button Style
/// Tactile card feedback for clickable and navigable cards.
/// Delivers subtle compression (scale 0.985), interpolating spring physics,
/// sensory haptic feedback (.impact(weight: .light)), and respects accessibilityReduceMotion.
public struct FrilaCardPressButtonStyle: ButtonStyle {
    public let reduceMotion: Bool
    
    public init(reduceMotion: Bool = false) {
        self.reduceMotion = reduceMotion
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.985 : 1.0))
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension View {
    /// Applies tactile card tap feedback (scale 0.985 with spring physics) when pressed.
    func frilaCardTapFeedback(reduceMotion: Bool = false) -> some View {
        buttonStyle(FrilaCardPressButtonStyle(reduceMotion: reduceMotion))
    }
}

// MARK: - CANONICAL COMPONENT: FrilaOpportunityCard
/// The definitive, curated Opportunity Card for the Frila Marketplace.
/// Unifies Museum Placard layout in the default Swiss paradigm, Tactile physics,
/// Liquid Glass surface capability, and shared-element expansion support via `@Namespace`.
public struct FrilaOpportunityCard: View {
    public let item: FrilaOpportunityItem
    public let isDark: Bool
    public let isGlass: Bool
    public let shadow: FrilaShadowElevation
    public let namespace: Namespace.ID?
    public let onTap: (() -> Void)?
    public let onApply: () -> Void
    public let onSave: () -> Void
    public let onSelect: (() -> Void)?
    
    @State private var isSaved: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let typography = FrilaTypography()

    public init(
        item: FrilaOpportunityItem,
        isDark: Bool = false,
        isGlass: Bool = false,
        shadow: FrilaShadowElevation = .subtle,
        onTap: (() -> Void)? = nil,
        onApply: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isDark = isDark
        self.isGlass = isGlass
        self.shadow = shadow
        self.namespace = nil
        self.onTap = onTap
        self.onApply = onApply
        self.onSave = onSave
        self.onSelect = onTap
    }

    public init(
        item: FrilaOpportunityItem,
        isDark: Bool = false,
        isGlass: Bool = false,
        shadow: FrilaShadowElevation = .subtle,
        namespace: Namespace.ID,
        onTap: (() -> Void)? = nil,
        onApply: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onSelect: (() -> Void)? = nil
    ) {
        self.item = item
        self.isDark = isDark
        self.isGlass = isGlass
        self.shadow = shadow
        self.namespace = namespace
        self.onTap = onTap ?? onSelect
        self.onApply = onApply
        self.onSave = onSave
        self.onSelect = onSelect ?? onTap
    }
    
    public var body: some View {
        if let tapAction = (onTap ?? onSelect) {
            Button(action: tapAction) {
                cardContent
            }
            .buttonStyle(FrilaCardPressButtonStyle(reduceMotion: reduceMotion))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
        } else {
            cardContent
                .frame(maxWidth: .infinity)
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space16) {
            // Media Frame with Concentric Inner Radius & 44pt Hitbox Action
            mediaFrameView

            // Museum Placard Typography Stack
            placardTitleView

            // 3-Column Archival Spec Grid (better-layout: aligned to shared edges)
            FrilaOpportunitySpecGrid(item: item, typography: typography, isDark: isDark)

            // Valuation & Primary CTA Row
            HStack(alignment: .center) {
                priceTagView

                Spacer()
                
                Button(action: onApply) {
                    HStack(spacing: 6) {
                        Text("Candidatar-se", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.button)
                        Image(systemName: "arrow.right")
                            .font(FrilaTypography.captionBold)
                    }
                }
                .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
                .accessibilityLabel(String(localized: "Candidatar-se à oportunidade de \(item.client)", table: "Estudio", bundle: bundleApresentacao))
            }
        }
        .padding(FrilaGeometry.space20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isGlass {
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                    .fill(FrilaColor.dynamicCanvas(isDark: isDark))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                .stroke(
                    isGlass ? Color.white.opacity(0.3) : FrilaColor.dynamicHairline(isDark: isDark),
                    lineWidth: 1
                )
        }
        .frilaShadow(shadow, isDark: isDark)
        .shadow(
            color: (isGlass && shadow == .none) ? Color.black.opacity(isDark ? 0.35 : 0.08) : Color.clear,
            radius: 12,
            x: 0,
            y: 4
        )
        .matchedContainer(namespace: namespace, id: "card_container_\(item.id)")
    }

    @ViewBuilder
    private var mediaFrameView: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(
                cornerRadius: FrilaGeometry.concentricInnerRadius(outerRadius: FrilaGeometry.radiusCard, padding: 4),
                style: .continuous
            )
            .fill(Color.gray.opacity(isDark ? 0.22 : 0.12))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                Image(systemName: "photo.artframe")
                    .font(FrilaTypography.display)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
            }
            
            // Save Button with Guaranteed 44x44pt Hitbox (Apple HIG & better-accessibility)
            Button(action: {
                withAnimation(FrilaMovimento.animacao(.spring(response: 0.28, dampingFraction: 0.6), reduzir: FrilaMovimentoReduzido.ativo)) {
                    isSaved.toggle()
                }
                onSave()
            }) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(FrilaTypography.bodyBold)
                    .foregroundColor(isSaved ? FrilaColor.dynamicBrandAccent(isDark: isDark) : FrilaColor.dynamicTextPrimary(isDark: isDark))
                    .symbolEffect(.bounce, value: isSaved)
                    .scaleEffect(isSaved && !reduceMotion ? 1.08 : 1.0)
                    .animation(FrilaMovimento.animacao(.spring(response: 0.25, dampingFraction: 0.55), reduzir: FrilaMovimentoReduzido.ativo), value: isSaved)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(10)
            .frilaHitbox()
            .accessibilityLabel(isSaved ? String(localized: "Remover dos salvos", table: "Estudio", bundle: bundleApresentacao) : String(localized: "Salvar oportunidade", table: "Estudio", bundle: bundleApresentacao))
            .accessibilityHint(String(localized: "Salva este contrato no catálogo pessoal", table: "Estudio", bundle: bundleApresentacao))
        }
        .matchedElement(namespace: namespace, id: "card_image_\(item.id)")
    }

    @ViewBuilder
    private var placardTitleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: FrilaGeometry.space8) {
                    Text(verbatim: item.client.uppercased())
                        .frilaType(typography.clientEntitySpec)
                        .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))

                    if item.roleIsCustom {
                        FrilaCustomRoleChip(isDark: isDark)
                    }
                }

                VStack(alignment: .leading, spacing: FrilaGeometry.space4) {
                    Text(verbatim: item.client.uppercased())
                        .frilaType(typography.clientEntitySpec)
                        .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))

                    if item.roleIsCustom {
                        FrilaCustomRoleChip(isDark: isDark)
                    }
                }
            }

            Text(verbatim: item.placardTitle)
                .frilaType(typography.placardTitleSpec)
                .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .matchedElement(namespace: namespace, id: "card_title_\(item.id)")
    }

    @ViewBuilder
    private var priceTagView: some View {
        FrilaPriceTag(amount: item.rateHourly, estimate: item.totalBudget, paradigm: typography.paradigm, isDark: isDark)
            .matchedElement(namespace: namespace, id: "card_price_\(item.id)")
    }
}

// MARK: - Internal Shared Placard Parts

/// Archival 3-column spec grid (DISCIPLINE / TIMELINE / SENIORITY) shared by the card and detail views.
struct FrilaOpportunitySpecGrid: View {
    let item: FrilaOpportunityItem
    let typography: FrilaTypography
    let isDark: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FrilaGeometry.space12) {
            column(label: "DISCIPLINA", value: item.scope)
                .frame(maxWidth: .infinity, alignment: .leading)
            column(label: "PRAZO", value: item.duration)
            column(label: "EXPERIÊNCIA", value: item.seniority)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Divider().background(FrilaColor.dynamicHairline(isDark: isDark))
        }
        .overlay(alignment: .bottom) {
            Divider().background(FrilaColor.dynamicHairline(isDark: isDark))
        }
    }

    private func column(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: label)
                .frilaType(typography.microLabelSpec)
                .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                .lineLimit(1)
            Text(verbatim: value)
                .font(FrilaTypography.captionMedium)
                .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detailed Placard Presentation (Expanded State)

/// Curatorial expanded placard view used in shared-element transitions with `FrilaOpportunityCard`.
public struct FrilaOpportunityPlacardDetail: View {
    public let item: FrilaOpportunityItem
    public let isDark: Bool
    public let namespace: Namespace.ID
    public let onDismiss: () -> Void
    public let onApply: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let typography = FrilaTypography()

    public init(
        item: FrilaOpportunityItem,
        isDark: Bool = false,
        namespace: Namespace.ID,
        onDismiss: @escaping () -> Void,
        onApply: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isDark = isDark
        self.namespace = namespace
        self.onDismiss = onDismiss
        self.onApply = onApply
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Expanded Media Frame with Matched Geometry
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusSheet, style: .continuous)
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

                // Close Button (HIG 44pt Touch Hitbox)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(FrilaFonteDoSistema.fonte(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(FrilaGeometry.space16)
                .frilaHitbox()
                .accessibilityLabel(String(localized: "Fechar detalhes do placard", table: "Estudio", bundle: bundleApresentacao))
            }
            .matchedGeometryEffect(id: "card_image_\(item.id)", in: namespace)

            // Placard Body Details
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaGeometry.space20) {
                    // Placard Title Stack with Matched Geometry
                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: FrilaGeometry.space8) {
                                Text(verbatim: item.client.uppercased())
                                    .frilaType(typography.clientEntitySpec)
                                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))

                                if item.roleIsCustom {
                                    FrilaCustomRoleChip(isDark: isDark)
                                }
                            }

                            VStack(alignment: .leading, spacing: FrilaGeometry.space4) {
                                Text(verbatim: item.client.uppercased())
                                    .frilaType(typography.clientEntitySpec)
                                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))

                                if item.roleIsCustom {
                                    FrilaCustomRoleChip(isDark: isDark)
                                }
                            }
                        }

                        Text(verbatim: item.placardTitle)
                            .frilaType(typography.displayHeadlineSpec)
                            .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .matchedGeometryEffect(id: "card_title_\(item.id)", in: namespace)

                    // 3-Column Archival Spec Grid
                    FrilaOpportunitySpecGrid(item: item, typography: typography, isDark: isDark)

                    // Archival Description Monograph
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ESPECIFICAÇÃO DO CONTRATO // REGISTRO DE ARQUIVO", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.microBold)
                            .foregroundColor(FrilaColor.primary600)
                            .tracking(FrilaTypography.trackingMicro)

                        Text("Contrato curado de alta complexidade técnica e design institucional. Requer proficiência sênior em sistemas escaláveis, conformidade estrita com tokens tipográficos e renderização de alta fidelidade.", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.body)
                            .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                            .lineSpacing(4)
                    }
                    .padding(FrilaGeometry.space16)
                    .background(FrilaColor.dynamicSurfaceSubtle(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                            .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                    }

                    // Tech Stack Tags Suite
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMPETÊNCIAS VERIFICADAS", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.microBold)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                            .tracking(FrilaTypography.trackingMicro)

                        HStack(spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(verbatim: tag)
                                    .font(FrilaTypography.mono(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(FrilaColor.dynamicSurfaceInput(isDark: isDark))
                                    .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule().stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
                                    }
                            }
                        }
                    }

                    // Bottom Floating Action Bar with Price Tag
                    HStack(alignment: .center) {
                        FrilaPriceTag(
                            amount: item.rateHourly,
                            estimate: item.totalBudget,
                            paradigm: typography.paradigm,
                            isDark: isDark
                        )
                        .matchedGeometryEffect(id: "card_price_\(item.id)", in: namespace)

                        Spacer()

                        Button(action: onApply) {
                            HStack(spacing: 8) {
                                Text("Enviar Proposta", tableName: "Estudio", bundle: bundleApresentacao)
                                    .font(FrilaTypography.button)
                                Image(systemName: "arrow.up.right")
                                    .font(FrilaFonteDoSistema.fonte(size: 13, weight: .bold))
                            }
                        }
                        .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
                    }
                    .padding(.top, 10)
                }
                .padding(FrilaGeometry.space20)
            }
        }
        .background(FrilaColor.dynamicCanvas(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusSheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusSheet, style: .continuous)
                .stroke(FrilaColor.dynamicHairline(isDark: isDark), lineWidth: 1)
        }
        .matchedGeometryEffect(id: "card_container_\(item.id)", in: namespace)
        .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.16), radius: 24, x: 0, y: 12)
    }
}

// MARK: - Staggered Entrance Animation ViewModifier

/// Staggered feed entrance animation with 0.04s delay per card, smooth spring physics,
/// and an accessible fallback for reduceMotion.
public struct FrilaFeedStaggerModifier: ViewModifier {
    public let index: Int
    public let delayPerItem: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAppeared: Bool = false

    public init(index: Int, delayPerItem: Double = 0.04) {
        self.index = index
        self.delayPerItem = delayPerItem
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isAppeared ? 0 : 18))
            .scaleEffect(reduceMotion ? 1 : (isAppeared ? 1 : 0.96))
            .onAppear {
                if reduceMotion {
                    isAppeared = true
                } else {
                    withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25)
                        .delay(Double(index) * delayPerItem), reduzir: FrilaMovimentoReduzido.ativo)) {
                        isAppeared = true
                    }
                }
            }
    }
}

public extension View {
    /// Applies the Frila feed staggered entrance animation with 0.04s delay per card.
    func frilaFeedStagger(index: Int, delayPerItem: Double = 0.04) -> some View {
        modifier(FrilaFeedStaggerModifier(index: index, delayPerItem: delayPerItem))
    }
}

// MARK: - Showcase Feed with Shared-Element Card Expansion

/// An interactive showcase feed displaying multiple opportunity cards with
/// staggered entrance and smooth `@Namespace` expansion into detailed placards.
public struct FrilaOpportunityShowcaseFeed: View {
    public let items: [FrilaOpportunityItem]
    public let isDark: Bool
    @Namespace private var feedNamespace
    @State private var expandedItem: FrilaOpportunityItem? = nil

    public init(items: [FrilaOpportunityItem] = [], isDark: Bool = false) {
        self.items = items
        self.isDark = isDark
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: FrilaGeometry.space16) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if expandedItem?.id != item.id {
                            FrilaOpportunityCard(
                                item: item,
                                isDark: isDark,
                                isGlass: false,
                                namespace: feedNamespace,
                                onApply: {},
                                onSave: {},
                                onSelect: {
                                    withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                                        expandedItem = item
                                    }
                                }
                            )
                            .frilaFeedStagger(index: index)
                        } else {
                            // Ghost placeholder to preserve scroll position during expansion
                            Color.clear
                                .frame(height: 380)
                        }
                    }
                }
                .padding(.horizontal, FrilaGeometry.space16)
            }

            // Expanded Overlay Detail Presentation
            if let selected = expandedItem {
                Color.black.opacity(isDark ? 0.70 : 0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                            expandedItem = nil
                        }
                    }

                FrilaOpportunityPlacardDetail(
                    item: selected,
                    isDark: isDark,
                    namespace: feedNamespace,
                    onDismiss: {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo)) {
                            expandedItem = nil
                        }
                    }
                )
                .padding(.horizontal, FrilaGeometry.space16)
                .padding(.vertical, FrilaGeometry.space24)
                .transition(.identity)
                .zIndex(100)
            }
        }
    }
}

// MARK: - Internal Matched Geometry View Helpers

private extension View {
    @ViewBuilder
    func matchedContainer(namespace: Namespace.ID?, id: String) -> some View {
        if let namespace = namespace {
            self.matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func matchedElement(namespace: Namespace.ID?, id: String) -> some View {
        if let namespace = namespace {
            self.matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Preview
