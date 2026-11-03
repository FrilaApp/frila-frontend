import SwiftUI
import PhotosUI

// MARK: - Curatorial Preset Artwork Model
public struct FrilaCuratorialPresetArtwork: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let craftTheme: String
    public let imageUrl: String

    public init(id: String, name: String, craftTheme: String, imageUrl: String) {
        self.id = id
        self.name = name
        self.craftTheme = craftTheme
        self.imageUrl = imageUrl
    }
}
// MARK: - App Persona Mode (Talento vs Estúdio)
public enum FrilaAppPersonaMode: String, CaseIterable, Identifiable, Sendable {
    case talent = "Talento"
    case studio = "Estúdio"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .talent: return "person.crop.circle"
        case .studio: return "building.2.crop.circle"
        }
    }
}

// MARK: - Opportunity Creation Draft Model (Freela do Mundo Real)
public struct FrilaJobCreationDraft: Identifiable, Hashable, Sendable {
    public var id: String
    public var client: String
    public var craft: String
    public var seniority: String
    public var tags: [String]
    public var protocolType: String
    public var duration: String
    public var location: String
    public var rateHourly: Int
    public var totalBudget: Int
    public var title: String
    public var scopeDescription: String
    public var imageUrl: String

    // Propriedades do Modo de Form Canônico (Screenshot 1 & 3)
    public var role: String
    public var roleOrigin: FrilaRoleOrigin
    public var shiftDate: String
    public var startTime: String
    public var endTime: String
    public var address: String
    public var addressNote: String
    public var payPerPosition: Int
    public var positionsCount: Int
    public var positionsOpen: Int
    public var mealIncluded: Bool
    public var transportIncluded: Bool
    public var bringOwnMaterial: Bool
    public var dressCode: String
    public var contactPerson: String
    public var distanceText: String
    public var reputationScore: String
    public var reputationLabel: String
    public var urgencyNote: String
    public var paymentType: String

    public init(
        id: String = UUID().uuidString,
        client: String = "Contratante Frila",
        craft: String = "Atendimento & Balcão",
        seniority: String = "Qualquer Experiência",
        tags: [String] = ["Atendimento ao Cliente", "Pontualidade"],
        protocolType: String = "Projeto Fechado",
        duration: String = "1 Mês",
        location: String = "Presencial (São Paulo, SP)",
        rateHourly: Int = 35,
        totalBudget: Int = 5600,
        title: String = "",
        scopeDescription: String = "",
        imageUrl: String = "https://images.unsplash.com/photo-1554118811-1e0d58224f24",
        role: String = "",
        roleOrigin: FrilaRoleOrigin = .catalog,
        shiftDate: String = "Sex, 25/09",
        startTime: String = "18:00",
        endTime: String = "02:00",
        address: String = "CLN 408, Bloco B, Asa Norte",
        addressNote: String = "Vem do cadastro do estabelecimento; dá para trocar.",
        payPerPosition: Int = 140,
        positionsCount: Int = 2,
        positionsOpen: Int = 1,
        mealIncluded: Bool = true,
        transportIncluded: Bool = false,
        bringOwnMaterial: Bool = false,
        dressCode: String = "camisa preta",
        contactPerson: String = "Renata, no balcão",
        distanceText: String = "a 3,2 km",
        reputationScore: String = "18 de 19",
        reputationLabel: String = "trabalhariam lá de novo",
        urgencyNote: String = "quem aceitar primeiro fica com a vaga",
        paymentType: String = "Pagamento Único (por turno)"
    ) {
        self.id = id
        self.client = client
        self.craft = craft
        self.seniority = seniority
        self.tags = tags
        self.protocolType = protocolType
        self.duration = duration
        self.location = location
        self.rateHourly = rateHourly
        self.totalBudget = totalBudget
        self.title = title
        self.scopeDescription = scopeDescription
        self.imageUrl = imageUrl
        self.role = role
        self.roleOrigin = roleOrigin
        self.shiftDate = shiftDate
        self.startTime = startTime
        self.endTime = endTime
        self.address = address
        self.addressNote = addressNote
        self.payPerPosition = payPerPosition
        self.positionsCount = positionsCount
        self.positionsOpen = positionsOpen
        self.mealIncluded = mealIncluded
        self.transportIncluded = transportIncluded
        self.bringOwnMaterial = bringOwnMaterial
        self.dressCode = dressCode
        self.contactPerson = contactPerson
        self.distanceText = distanceText
        self.reputationScore = reputationScore
        self.reputationLabel = reputationLabel
        self.urgencyNote = urgencyNote
        self.paymentType = paymentType
    }

    /// Gera o FrilaOpportunityItem final pronto para o catálogo do Frila
    public func toOpportunityItem() -> FrilaOpportunityItem {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCraft = craft.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalTitle: String
        if !trimmedTitle.isEmpty {
            finalTitle = trimmedTitle
        } else if !trimmedRole.isEmpty {
            finalTitle = trimmedRole
        } else if !trimmedCraft.isEmpty {
            finalTitle = !seniority.isEmpty ? "\(trimmedCraft), \(seniority)" : trimmedCraft
        } else {
            finalTitle = "Vaga a definir"
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAddress = !trimmedAddress.isEmpty ? trimmedAddress : location
        let finalHours: String
        if !startTime.isEmpty && !endTime.isEmpty {
            finalHours = "\(startTime) às \(endTime)"
        } else if !startTime.isEmpty {
            finalHours = "A partir de \(startTime)"
        } else {
            finalHours = duration
        }
        let finalBudget = totalBudget > 0 ? totalBudget : (payPerPosition * max(1, positionsCount))

        let finalScope: String
        if !trimmedCraft.isEmpty && !protocolType.isEmpty {
            finalScope = "\(trimmedCraft) & \(protocolType)"
        } else if !trimmedCraft.isEmpty {
            finalScope = trimmedCraft
        } else if !protocolType.isEmpty {
            finalScope = protocolType
        } else {
            finalScope = ""
        }

        let finalTags: [String]
        if !tags.isEmpty {
            finalTags = tags
        } else if !trimmedCraft.isEmpty {
            finalTags = [trimmedCraft, "Geral"]
        } else {
            finalTags = []
        }

        let isSingle = paymentType.isEmpty || paymentType.contains("Único") || paymentType.contains("Turno") || paymentType.contains("Diária")

        return FrilaOpportunityItem(
            id: id,
            client: client,
            title: finalTitle,
            year: "2026",
            scope: finalScope,
            location: finalAddress,
            duration: duration,
            seniority: seniority,
            rateHourly: rateHourly,
            totalBudget: finalBudget,
            escrowVerified: true,
            tags: finalTags,
            imageUrl: imageUrl,
            role: finalTitle,
            shiftDate: shiftDate,
            shiftHours: finalHours,
            startTime: startTime,
            endTime: endTime,
            address: finalAddress,
            distanceText: distanceText,
            payPerPosition: payPerPosition,
            positionsTotal: positionsCount,
            positionsOpen: positionsOpen,
            mealIncluded: mealIncluded,
            transportIncluded: transportIncluded,
            bringOwnMaterial: bringOwnMaterial,
            dressCode: dressCode,
            contactPerson: contactPerson,
            reputationCount: reputationScore,
            reputationLabel: reputationLabel,
            urgencyText: urgencyNote,
            isSinglePayment: isSingle,
            paymentUnitLabel: isSingle ? "por turno" : "/h",
            roleIsCustom: roleOrigin == .custom
        )
    }
}

// MARK: - Curatorial Studio Component
// MARK: - Enxerto: o que o app acrescenta ao estúdio

/// Resultado da publicação real pelo app. `.queued` é a publicação sem rede: ficou na fila do
/// aparelho, o aviso do formulário explica e não há celebração nem alerta.
public enum FrilaPublishOutcome: Equatable, Sendable {
    case published
    case queued
    case failed(String)
}

/// Pontos em que o app entra no estúdio sem mudar o desenho da origem: aviso no topo do formulário
/// (fila, erro, pendência), complemento no fim de uma seção (modo da vaga), campos travados enquanto há
/// publicação pendente, rótulos do botão de publicar e do fechar, e o botão de perfil do primeiro
/// acesso. Tudo opcional: sem ganchos, o estúdio é o da origem.
struct FrilaStudioHostHooks {
    var banner: (() -> AnyView?)?
    var sectionFooter: ((FrilaJobFormSection) -> AnyView?)?
    var fieldsLocked: (() -> Bool)?
    var publishLabel: (() -> String?)?
    var closeLabel: (() -> String?)?
    var showsClose: Bool
    var trailingToolbar: (() -> AnyView?)?
    var onDraftChange: ((FrilaJobCreationDraft) -> Void)?

    init(
        banner: (() -> AnyView?)? = nil,
        sectionFooter: ((FrilaJobFormSection) -> AnyView?)? = nil,
        fieldsLocked: (() -> Bool)? = nil,
        publishLabel: (() -> String?)? = nil,
        closeLabel: (() -> String?)? = nil,
        showsClose: Bool = true,
        trailingToolbar: (() -> AnyView?)? = nil,
        onDraftChange: ((FrilaJobCreationDraft) -> Void)? = nil
    ) {
        self.banner = banner
        self.sectionFooter = sectionFooter
        self.fieldsLocked = fieldsLocked
        self.publishLabel = publishLabel
        self.closeLabel = closeLabel
        self.showsClose = showsClose
        self.trailingToolbar = trailingToolbar
        self.onDraftChange = onDraftChange
    }
}

public struct FrilaJobCreationStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let isDark: Bool
    @State public var draft: FrilaJobCreationDraft
    public let onPublish: (FrilaOpportunityItem) -> Void
    public let onSaveDraft: ((FrilaJobCreationDraft) -> Void)?
    public let onDismiss: () -> Void
    public let pickerGroupStyle: FrilaPickerGroupStyle
    public let shiftNavigationStyle: FrilaJobShiftNavigationStyle

    @State private var showingCelebrationSheet: Bool = false
    // Enxerto: publicação real pelo app (nil mantém o comportamento da origem, só a celebração)
    private let publicar: ((FrilaJobCreationDraft) async -> FrilaPublishOutcome)?
    private let hooks: FrilaStudioHostHooks
    @State private var enviando = false
    @State private var erroDaPublicacao: String?
    @State private var showingPreviewSheet: Bool
    @State private var publishedItem: FrilaOpportunityItem? = nil
    @State private var keyboardObserver = FrilaKeyboardObserver()
    @State private var isEditingField: Bool = false

    // Formulário contínuo: seção visível (1-based para o stepper), topo medido de cada seção
    // e trava da detecção durante a rolagem programática do toque nas barras
    @State private var activeSection: Int = 1
    @State private var sectionTops: [FrilaJobFormSection: CGFloat] = [:]
    @State private var isJumpingToSection: Bool = false
    @State private var missingTapTrigger: Int = 0
    @State private var editingShift: FrilaJobShiftField?
    /// Verdadeiro após tentar publicar com obrigatório faltando: marca os campos vazios do turno.
    @State private var showsMissingFields = false
    // Área visível entre o cabeçalho fixo e o dock, e altura da última seção: definem a folga do fim
    @State private var formViewportHeight: CGFloat = 0
    @State private var stableFormViewportHeight: CGFloat = 0
    @State private var lastSectionHeight: CGFloat = 0
    // Desfoque do cabeçalho: ausente em repouso, surge quando o conteúdo passa por baixo
    @State private var headerBlurStrength: CGFloat = 0
    // Fração da dissolução que pende abaixo do cabeçalho: zero com uma dica encaixada rente a ele
    @State private var headerOverhangFraction: CGFloat = 0

    // Custom Tag input state
    @State private var customTagInput: String = ""

    // Photo Picker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    // Master Curatorial Presets
    public static let presetArtworks: [FrilaCuratorialPresetArtwork] = [
        FrilaCuratorialPresetArtwork(
            id: "preset-01",
            name: "Balcão & Atendimento Comercial",
            craftTheme: "Atendimento & Balcão",
            imageUrl: "https://images.unsplash.com/photo-1554118811-1e0d58224f24"
        ),
        FrilaCuratorialPresetArtwork(
            id: "preset-02",
            name: "Clínica & Espaço Terapêutico",
            craftTheme: "Saúde & Terapias",
            imageUrl: "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d"
        ),
        FrilaCuratorialPresetArtwork(
            id: "preset-03",
            name: "Cafeteria Especial & Gastronomia",
            craftTheme: "Gastronomia & Café",
            imageUrl: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb"
        ),
        FrilaCuratorialPresetArtwork(
            id: "preset-04",
            name: "Estúdio Visual & Criação",
            craftTheme: "Design & Criação",
            imageUrl: "https://images.unsplash.com/photo-1507238691740-187a5b1d37b8"
        ),
        FrilaCuratorialPresetArtwork(
            id: "preset-05",
            name: "Engenharia de Software & Dados",
            craftTheme: "Tecnologia & Software",
            imageUrl: "https://images.unsplash.com/photo-1550745165-9bc0b252726f"
        ),
        FrilaCuratorialPresetArtwork(
            id: "preset-06",
            name: "Educação & Apoio ao Desenvolvimento",
            craftTheme: "Educação & Apoio",
            imageUrl: "https://images.unsplash.com/photo-1497633762265-9d179a990aa6"
        )
    ]

    // Setores / Áreas de Atuação Universais
    public static let availableCrafts: [String] = [
        "Atendimento & Balcão",
        "Gastronomia & Café",
        "Eventos & Promoção",
        "Varejo & Caixa",
        "Serviços Operacionais",
        "Saúde & Terapias",
        "Design & Criação",
        "Tecnologia & Software"
    ]

    // Níveis de Experiência Universais
    public static let availableSeniorities: [String] = [
        "Qualquer Experiência",
        "Iniciante / Prático",
        "Intermediário",
        "Especialista"
    ]

    // Habilidades & Requisitos Sugeridos Universais
    public static let availableTags: [String] = [
        "Atendimento ao Cliente",
        "Pontualidade",
        "Trabalho em Equipe",
        "Agilidade de Balcão",
        "Comunicação Clara",
        "Fechamento de Caixa",
        "Disponibilidade Noturna",
        "Experiência com Bandeja",
        "Preparo de Café",
        "Organização"
    ]

    // Modalidades de Trabalho / Contratação
    public static let availableProtocols: [(name: String, subtitle: String, duration: String, icon: String)] = [
        ("Diária ou Turno", "Pagamento único por dia, turno ou evento avulso", "Por turno", "calendar.badge.clock"),
        ("Serviço Fechado", "Valor fixo acordado para a entrega completa", "Por serviço", "checkmark.seal.fill"),
        ("Semanal ou Recorrente", "Escala semanal contínua com pagamento combinado", "Semanal", "arrow.clockwise.circle"),
        ("Por Hora", "Remuneração flexível baseada nas horas trabalhadas", "Horas", "clock.fill")
    ]

    public static let availableDurations: [String] = [
        "Por Diária / Turno",
        "1 Semana",
        "1 Mês",
        "Contínuo / Recorrente"
    ]

    public static let availableLocations: [String] = [
        "CLN 408, Bloco B, Asa Norte",
        "CLS 204, Bloco A, Asa Sul",
        "Setor Hoteleiro Norte, Brasília",
        "Pinheiros, São Paulo, SP",
        "Ipanema, Rio de Janeiro, RJ",
        "Savassi, Belo Horizonte, MG",
        "Presencial (Local Físico)",
        "Remoto"
    ]

    init(
        isDark: Bool = false,
        initialDraft: FrilaJobCreationDraft = .blank,
        startsWithPreview: Bool = false,
        pickerGroupStyle: FrilaPickerGroupStyle = .neutral,
        shiftNavigationStyle: FrilaJobShiftNavigationStyle = .overviewList,
        onPublish: @escaping (FrilaOpportunityItem) -> Void,
        onSaveDraft: ((FrilaJobCreationDraft) -> Void)? = nil,
        onDismiss: @escaping () -> Void,
        publicar: ((FrilaJobCreationDraft) async -> FrilaPublishOutcome)? = nil,
        hooks: FrilaStudioHostHooks = FrilaStudioHostHooks()
    ) {
        self.publicar = publicar
        self.hooks = hooks
        self.isDark = isDark
        // O total é derivado de valor e vagas: recalcula para não herdar um total inconsistente
        var resolvedDraft = initialDraft
        resolvedDraft.recalculateTotalBudget()
        self._draft = State(initialValue: resolvedDraft)
        self._showingPreviewSheet = State(initialValue: startsWithPreview)
        self.onPublish = onPublish
        self.onSaveDraft = onSaveDraft
        self.onDismiss = onDismiss
        self.pickerGroupStyle = pickerGroupStyle
        self.shiftNavigationStyle = shiftNavigationStyle
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FrilaColor.dynamicCanvas(isDark: isDark)
                    .ignoresSafeArea()

                continuousFormView
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                // Enxerto: no primeiro acesso do app não há para onde voltar e o X não aparece.
                if hooks.showsClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: handleClose) {
                            Image(systemName: "xmark")
                                .font(FrilaFonteDoSistema.fonte(size: 13, weight: .bold))
                                .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                                .frame(width: 30, height: 30)
                                .contentShape(Circle())
                        }
                        .disabled(enviando)
                        .accessibilityLabel(hooks.closeLabel?() ?? String(localized: "Fechar estúdio de criação", table: "Estudio", bundle: bundleApresentacao))
                        .accessibilityIdentifier("cancelar-publicacao")
                    }
                }
                if let trailing = hooks.trailingToolbar?() {
                    ToolbarItem(placement: .topBarTrailing) { trailing }
                }

                // Título com a posição da etapa como subtítulo, no padrão de barra de navegação iOS.
                // A barra segmentada abaixo já mostra o progresso; o número só confirma onde se está.
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Publicar vaga", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        Text("\(activeSection) de \(FrilaJobFormSection.allCases.count)", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                            .contentTransition(reduceMotion ? .identity : .numericText(value: Double(activeSection)))
                            .animation(FrilaMovimento.animacao(FrilaMotion.disclosureCollapse, reduzir: reduceMotion), value: activeSection)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "Publicar vaga, etapa \(activeSection) de \(FrilaJobFormSection.allCases.count)", table: "Estudio", bundle: bundleApresentacao))
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        // Seletor de data e horários: camada do formulário sobre a pilha inteira (cobre também a barra superior)
        .overlay { FrilaJobShiftOverlay(editing: $editingShift, draft: $draft, isDark: isDark, navigationStyle: shiftNavigationStyle) }
        .sheet(isPresented: $showingCelebrationSheet) {
            if let published = publishedItem {
                FrilaJobCelebrationSheet(
                    isDark: isDark,
                    item: published,
                    onViewDetail: {
                        showingCelebrationSheet = false
                        dismiss()
                        onPublish(published)
                    },
                    onFinish: {
                        showingCelebrationSheet = false
                        dismiss()
                        onPublish(published)
                    }
                )
            }
        }
        .sheet(isPresented: $showingPreviewSheet) {
            NavigationStack {
                FrilaOpportunityDetailView(
                    item: draft.toOpportunityItem(),
                    isDark: isDark,
                    showsNavigationTitle: true,
                    isPublisherPreview: true,
                    onApply: {
                        showingPreviewSheet = false
                        publishOpportunity()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Fechar", table: "Estudio", bundle: bundleApresentacao)) {
                            showingPreviewSheet = false
                        }
                    }
                }
            }
        }
        .frilaKeyboardDismissScope(observer: keyboardObserver)
        .onChange(of: draft) { _, novo in hooks.onDraftChange?(novo) }
        .alert(
            String(localized: "Não deu para publicar", table: "Estudio", bundle: bundleApresentacao),
            isPresented: Binding(get: { erroDaPublicacao != nil }, set: { if !$0 { erroDaPublicacao = nil } })
        ) {
            Button(String(localized: "OK", table: "Estudio", bundle: bundleApresentacao), role: .cancel) {}
        } message: {
            Text(verbatim: erroDaPublicacao ?? "")
        }
    }

    private func handleClose() {
        if !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSaveDraft?(draft)
        }
        onDismiss()
    }

    private func publishOpportunity() {
        guard let publicar else {
            publishedItem = draft.toOpportunityItem()
            showingCelebrationSheet = true
            return
        }
        guard !enviando else { return }
        enviando = true
        let enviado = draft
        Task {
            let resultado = await publicar(enviado)
            enviando = false
            switch resultado {
            case .published:
                publishedItem = enviado.toOpportunityItem()
                showingCelebrationSheet = true
            case .queued:
                // Sem rede: a publicação continua na fila; o aviso do topo (gancho do app) explica.
                break
            case .failed(let erro):
                erroDaPublicacao = erro
            }
        }
    }

    private var fieldsLocked: Bool { hooks.fieldsLocked?() ?? false }

    // MARK: - FORMULÁRIO CONTÍNUO (cabeçalho de etapas guiado pela rolagem)
    private static let formSectionSteps = FrilaJobFormSection.allCases.map(\.stepItem)
    private static let formContentSpace = "job-form-content"
    /// Linha de leitura logo abaixo do cabeçalho: a seção cujo topo passa dela vira a ativa.
    /// Fica dentro da folga do snap, então todo repouso encaixado já mostra a pergunta certa.
    private static let sectionProbe: CGFloat = 24
    /// Folga entre o cabeçalho fixo e a dica da seção encaixada; o rabo do desfoque já dá o respiro.
    private static let sectionSnapInset: CGFloat = 0
    /// Pedaço do bloco seguinte que aparece embaixo da seção encaixada: avisa que há mais etapas.
    private static let sectionPeek: CGFloat = FrilaGeometry.space48
    /// Opacidade e escala das etapas que não são a atual.
    private static let inactiveSectionOpacity: Double = 0.4
    private static let inactiveSectionScale: CGFloat = 0.985
    /// Dissolução máxima abaixo da borda do cabeçalho, no miolo das seções.
    private static let headerOverhang: CGFloat = FrilaGeometry.space32

    private var continuousFormView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FrilaGeometry.space32) {
                    // Enxerto: avisos do app (publicação na fila, erro, pendência) acima da primeira etapa
                    if let banner = hooks.banner?() {
                        banner
                    }

                    ForEach(FrilaJobFormSection.allCases) { section in
                        let isActive = activeSection == section.rawValue + 1
                        formSectionContent(section)
                        // Cada etapa é um bloco quase do tamanho da área visível, com o topo da
                        // seguinte à mostra. Seção mais alta que isso cresce e rola por dentro.
                        .frame(
                            maxWidth: .infinity,
                            minHeight: Self.sectionBlockHeight(viewport: stableFormViewportHeight > 0 ? stableFormViewportHeight : formViewportHeight),
                            alignment: .top
                        )
                        .padding(.bottom, FrilaGeometry.space16)
                        .overlay(alignment: .bottom) {
                            if section != FrilaJobFormSection.allCases.last {
                                Rectangle()
                                    .fill(FrilaColor.dynamicFormCardBorder(isDark: isDark))
                                    .frame(height: 1)
                            }
                        }
                        .opacity(isActive ? 1 : Self.inactiveSectionOpacity)
                        .scaleEffect(reduceMotion || isActive ? 1 : Self.inactiveSectionScale, anchor: .top)
                        .animation(FrilaMovimento.animacao((isActive ? FrilaMotion.disclosureExpand : FrilaMotion.disclosureCollapse), reduzir: reduceMotion),
                            value: isActive
                        )
                        .id(section)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(Self.formContentSpace))
                        } action: { frame in
                            sectionTops[section] = frame.minY
                            if section == FrilaJobFormSection.allCases.last {
                                lastSectionHeight = frame.height
                            }
                        }
                    }

                    // Folga exata para a última seção encaixar logo abaixo do cabeçalho no fim da rolagem
                    // com reserva completa de rolagem quando o teclado virtual estiver visível (R2 / B1)
                    Spacer()
                        .frame(
                            height: FrilaJobFormSection.trailingSpace(
                                viewport: stableFormViewportHeight > 0 ? stableFormViewportHeight : formViewportHeight,
                                lastSectionHeight: lastSectionHeight,
                                spacing: FrilaGeometry.space32,
                                snapInset: Self.sectionSnapInset
                            ) + (keyboardObserver.isKeyboardVisible ? max(0, formViewportHeight - keyboardObserver.keyboardTop + FrilaGeometry.space16) : 0)
                        )
                }
                .padding(.horizontal, FrilaGeometry.space20)
                .coordinateSpace(name: Self.formContentSpace)
                .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                    value: FrilaJobFormSection.allCases.map { $0.isComplete(draft) }
                )
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .accessibilityIdentifier("publicar-vaga-formulario")
            .scrollTargetBehavior(
                FrilaJobFormSectionPagingBehavior(
                    anchors: FrilaJobFormSection.allCases.compactMap { section in
                        sectionTops[section].map { max(0, $0 - Self.sectionSnapInset) }
                    },
                    isEnabled: !keyboardObserver.isKeyboardVisible && !isEditingField
                )
            )
            .sensoryFeedback(.selection, trigger: activeSection)
            .frilaFieldReveal(
                scrollProxy: scrollProxy,
                keyboardObserver: keyboardObserver,
                isEditingField: $isEditingField
            )
            .modifier(
                FrilaJobFormSectionTrackingModifier(
                    activeSection: $activeSection,
                    viewportHeight: $formViewportHeight,
                    stableViewportHeight: $stableFormViewportHeight,
                    blurStrength: $headerBlurStrength,
                    overhangFraction: $headerOverhangFraction,
                    anchors: FrilaJobFormSection.allCases.compactMap { section in
                        sectionTops[section].map { max(0, $0 - Self.sectionSnapInset) }
                    },
                    sectionTops: sectionTops,
                    probe: Self.sectionProbe,
                    isSuspended: isJumpingToSection || keyboardObserver.isKeyboardVisible || isEditingField
                )
            )
            .frilaProgressiveBlurHeader(
                isDark: isDark,
                fadeTail: 0,
                fadeInset: FrilaGeometry.space8,
                strength: headerBlurStrength,
                systemEdgeEffect: false,
                overhang: Self.headerOverhang * headerOverhangFraction,
                opaqueVeil: true,
                materialOpacity: headerOverhangFraction
            ) {
                continuousFormHeader(scrollProxy: scrollProxy)
                    .padding(.top, FrilaGeometry.space8)
                    .frilaRevealHeader()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !keyboardObserver.isKeyboardVisible {
                    continuousFormDock(scrollProxy: scrollProxy)
                        .frilaRevealBottomBar()
                }
            }
        }
    }

    /// Altura mínima do bloco: área visível menos o respiro da etapa seguinte e o vão entre blocos.
    private static func sectionBlockHeight(viewport: CGFloat) -> CGFloat {
        guard viewport > 0 else { return 0 }
        return max(0, viewport - sectionPeek - FrilaGeometry.space32 - FrilaGeometry.space16)
    }

    @ViewBuilder
    private func formSectionContent(_ section: FrilaJobFormSection) -> some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space20) {
            Group {
                switch section {
                case .vaga: FrilaJobFormVagaSection(draft: $draft, isDark: isDark, groupStyle: pickerGroupStyle)
                case .turno: FrilaJobFormTurnoSection(draft: $draft, editingShift: $editingShift, isDark: isDark, navigationStyle: shiftNavigationStyle, showsMissing: showsMissingFields)
                case .valor: FrilaJobFormValorSection(draft: $draft, isDark: isDark)
                }
            }
            // Enxerto: com publicação pendente na fila, os campos ficam travados até ela concluir
            .disabled(fieldsLocked)

            // Enxerto: complemento do app no fim da etapa (o modo da vaga, no Turno)
            if let footer = hooks.sectionFooter?(section) {
                footer
            }
        }
    }

    /// Barras de preenchimento por seção + cabeçalho com pergunta e texto de apoio fixos.
    /// A altura do cabeçalho reserva o espaço do maior par (pergunta + apoio) para estabilidade total na rolagem.
    private func continuousFormHeader(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: -FrilaGeometry.space4) {
            FrilaFlowStepper(
                currentStep: Binding(get: { activeSection }, set: { _ in }),
                steps: Self.formSectionSteps,
                isDark: isDark,
                showsTextBlock: false,
                sectionProgress: FrilaJobFormSection.allCases.map { $0.progress(draft) },
                onSelectStep: { index in
                    if let section = FrilaJobFormSection(rawValue: index) {
                        jump(to: section, scrollProxy: scrollProxy)
                    }
                }
            )

            FrilaJobFormHeaderQuestion(
                section: FrilaJobFormSection(rawValue: activeSection - 1) ?? .vaga,
                draft: draft,
                isDark: isDark
            )
            .padding(.bottom, FrilaGeometry.space12)
        }
        .padding(.horizontal, FrilaGeometry.space20)
    }

    /// Prévia e Publicar. Com obrigatório faltando, Publicar leva à primeira seção incompleta.
    private func continuousFormDock(scrollProxy: ScrollViewProxy) -> some View {
        let missing = FrilaJobFormSection.firstIncomplete(in: draft)
        return HStack(spacing: FrilaGeometry.space10) {
            Button(action: { showingPreviewSheet = true }) {
                Label(String(localized: "Prévia", table: "Estudio", bundle: bundleApresentacao), systemImage: "eye")
                    .font(FrilaTypography.button)
                    .padding(.horizontal, FrilaGeometry.space20)
                    .frame(height: FrilaGeometry.buttonHeightProminent)
            }
            .buttonStyle(FrilaPillButtonStyle(variant: .outline, isDark: isDark))
            .accessibilityIdentifier("previa-vaga-botao")

            Button(action: {
                if let missing {
                    showsMissingFields = true
                    missingTapTrigger += 1
                    jump(to: missing, scrollProxy: scrollProxy)
                } else {
                    publishOpportunity()
                }
            }) {
                HStack(spacing: FrilaGeometry.space8) {
                    // Enxerto: com publicação pendente, o app diz "Tentar novamente"
                    if let publishLabel = hooks.publishLabel?() {
                        Text(verbatim: publishLabel)
                            .font(FrilaTypography.button)
                    } else {
                        Text("Publicar vaga", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.button)
                    }
                    Image(systemName: "paperplane.fill")
                        .font(FrilaTypography.captionBold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: FrilaGeometry.buttonHeightProminent)
            }
            .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
            .disabled(enviando)
            .opacity(missing == nil && !enviando ? 1 : 0.55)
            .sensoryFeedback(.warning, trigger: missingTapTrigger)
            .accessibilityLabel(hooks.publishLabel?() ?? String(localized: "Publicar vaga de \(draft.role)", table: "Estudio", bundle: bundleApresentacao))
            .accessibilityHint(missing.map { String(localized: "Falta preencher \($0.title). Toque duas vezes para ir até a seção.", table: "Estudio", bundle: bundleApresentacao) } ?? "")
            .accessibilityIdentifier("publicar-vaga-botao")
        }
        .padding(.horizontal, FrilaGeometry.space20)
        .padding(.top, FrilaGeometry.space12)
        .padding(.bottom, FrilaGeometry.space8)
        .background(
            FrilaColor.dynamicCanvas(isDark: isDark)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FrilaColor.dynamicFormCardBorder(isDark: isDark))
                .frame(height: 1)
        }
    }

    /// Rola até a seção com mola e trava a detecção para o cabeçalho não piscar pelas seções intermediárias.
    private func jump(to section: FrilaJobFormSection, scrollProxy: ScrollViewProxy) {
        isJumpingToSection = true
        activeSection = section.rawValue + 1
        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion)) {
            scrollProxy.scrollTo(section, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isJumpingToSection = false
        }
    }
}

// MARK: - Curatorial Celebration Bottom Sheet
public struct FrilaJobCelebrationSheet: View {
    public let isDark: Bool
    public let item: FrilaOpportunityItem
    public let onViewDetail: () -> Void
    public let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isDark: Bool = false,
        item: FrilaOpportunityItem,
        onViewDetail: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.isDark = isDark
        self.item = item
        self.onViewDetail = onViewDetail
        self.onFinish = onFinish
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: FrilaGeometry.space20) {
                // Ícone de Sucesso
                ZStack {
                    Circle()
                        .fill(FrilaColor.dynamicVerifiedBg(isDark: isDark))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.seal.fill")
                        .font(FrilaFonteDoSistema.fonte(size: 36, weight: .medium))
                        .foregroundColor(FrilaColor.dynamicVerified(isDark: isDark))
                }
                .padding(.top, FrilaGeometry.space16)

                VStack(spacing: 6) {
                    Text("Vaga Publicada!", tableName: "Estudio", bundle: bundleApresentacao)
                        .font(FrilaTypography.titleLarge)
                        .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))

                    Text("Sua vaga já está visível para profissionais perto de você no Frila.", tableName: "Estudio", bundle: bundleApresentacao)
                        .font(FrilaTypography.caption)
                        .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Alerta Enviado aos Candidatos (Screenshot 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTIFICAÇÃO ENVIADA AOS PROFISSIONAIS", tableName: "Estudio", bundle: bundleApresentacao)
                        .font(FrilaTypography.microBold)
                        .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        .tracking(FrilaTypography.trackingMicro)

                    FrilaShiftNotificationBanner(
                        appTitle: "FRILA",
                        timeAgo: "agora",
                        // Enxerto: sem "começa em menos de 2 h" nem a distância fixa de 3,2 km da origem; só dados da vaga.
                        title: "\(item.role.isEmpty ? item.title : item.role), \(item.shiftDate), \(item.shiftHours)",
                        subtitle: "\(item.client), \(item.location), \(FrilaMoney.total(item.payPerPosition))",
                        isDark: isDark,
                        forceLockScreenTheme: false,
                        // Enxerto: a origem passava ação vazia; o toque faz o mesmo que "Ver Detalhes da Vaga"
                        action: onViewDetail
                    )
                }
                .padding(.horizontal, FrilaGeometry.space16)

                // Card Resumo da Vaga
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(verbatim: item.client.uppercased())
                            .font(FrilaTypography.microBold)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                        Spacer()
                        FrilaStatusChip("Ativa no Feed", style: .verified, systemImage: "sparkles", isDark: isDark)
                    }

                    Text(verbatim: item.role.isEmpty ? item.title : item.role)
                        .font(FrilaTypography.placard)
                        .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        FrilaPriceTag(texto: "\(FrilaMoney.total(item.payPerPosition)) \(item.paymentUnitLabel)", tamanho: 13, isDark: isDark)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(FrilaColor.dynamicBrandAccent(isDark: isDark))

                        Text(verbatim: item.shiftDate)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))

                        Spacer()

                        Text(verbatim: item.location)
                            .font(FrilaTypography.caption)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    }
                }
                .padding(FrilaGeometry.space16)
                .background(FrilaColor.dynamicFormCardSurface(isDark: isDark))
                .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                        .strokeBorder(FrilaColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
                }
                .frilaFormLift(isDark: isDark)
                .padding(.horizontal, FrilaGeometry.space16)

                // Ações
                VStack(spacing: 12) {
                    Button(action: onViewDetail) {
                        Text("Ver Detalhes da Vaga", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.button)
                            .frame(maxWidth: .infinity)
                            .frame(height: FrilaGeometry.buttonHeightStandard)
                    }
                    .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
                    .accessibilityIdentifier("celebracao-ver-vaga")

                    // Enxerto: sem o botão "Ver Alerta no Lock Screen" (tela de bloqueio fora do escopo).
                    Button(action: onFinish) {
                        Text("Concluir", tableName: "Estudio", bundle: bundleApresentacao)
                            .font(FrilaTypography.captionBold)
                            .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                            .padding(.vertical, 8)
                    }
                    .frilaHitbox()
                    .accessibilityIdentifier("celebracao-concluir")
                }
                .padding(.horizontal, FrilaGeometry.space20)
                .padding(.bottom, FrilaGeometry.space16)
            }
            .padding(.vertical, 8)
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Rastreamento da seção visível no formulário contínuo
private struct FrilaJobFormSectionTrackingModifier: ViewModifier {
    @Binding var activeSection: Int
    /// Altura visível entre o cabeçalho fixo e o dock (container sem os insets).
    @Binding var viewportHeight: CGFloat
    /// Altura pré-edição estabilizada dos blocos (não colapsa com teclado virtual).
    @Binding var stableViewportHeight: CGFloat
    /// Intensidade do desfoque do cabeçalho, de 0 em repouso a 1 após `FrilaProgressiveBlur.emergenceDistance`.
    @Binding var blurStrength: CGFloat
    /// Fração da dissolução abaixo do cabeçalho: 0 com o repouso numa âncora, 1 no miolo da seção.
    @Binding var overhangFraction: CGFloat
    let anchors: [CGFloat]
    let sectionTops: [FrilaJobFormSection: CGFloat]
    let probe: CGFloat
    let isSuspended: Bool

    private struct Position: Equatable {
        var offset: CGFloat
        var atBottom: Bool
        var viewport: CGFloat
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content
                .onScrollGeometryChange(for: Position.self) { geo in
                    // visibleRect inclui a área sob o cabeçalho fixo (inset superior); a linha de leitura
                    // e o snap partem da borda inferior do cabeçalho, então o offset soma o inset
                    let offset = max(0, geo.visibleRect.minY + geo.contentInsets.top)
                    let atBottom = geo.visibleRect.maxY >= geo.contentSize.height + geo.contentInsets.bottom - 8
                    return Position(offset: offset, atBottom: atBottom, viewport: geo.containerSize.height.rounded())
                } action: { _, position in
                    if abs(viewportHeight - position.viewport) >= 1 {
                        viewportHeight = position.viewport
                    }
                    if !isSuspended {
                        if stableViewportHeight == 0 || abs(stableViewportHeight - position.viewport) >= 1 {
                            stableViewportHeight = position.viewport
                        }
                    }
                    let strength = FrilaProgressiveBlur.strength(forScrollOffset: position.offset)
                    if strength != blurStrength {
                        blurStrength = strength
                    }
                    let overhang = FrilaProgressiveBlur.overhangFraction(offset: position.offset, anchors: anchors)
                    if overhang != overhangFraction {
                        overhangFraction = overhang
                    }
                    guard !isSuspended else { return }
                    let current = FrilaJobFormSection(rawValue: activeSection - 1) ?? .vaga
                    let visible = FrilaJobFormSection.visibleSection(
                        current: current,
                        offset: position.offset,
                        tops: sectionTops,
                        probe: probe,
                        atBottom: position.atBottom
                    )
                    if visible != current {
                        activeSection = visible.rawValue + 1
                    }
                }
        } else {
            // iOS 17 / macOS 14: a seção ativa muda apenas pelo toque nas barras; desfoque sempre pleno
            content
                .onAppear {
                    blurStrength = 1
                    overhangFraction = 1
                }
        }
    }
}
