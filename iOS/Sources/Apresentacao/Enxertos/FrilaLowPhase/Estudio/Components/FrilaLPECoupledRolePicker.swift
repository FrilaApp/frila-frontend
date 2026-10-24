import SwiftUI

// MARK: - Eixo do Seletor Acoplado (A/B Layout)

public enum FrilaLPECoupledRolePickerAxis: Sendable {
    /// Colunas lado a lado em proporção 2:3 (Categoria 40% : Função 60%), espaço space8. Padrão do formulário.
    case horizontal
    /// Categoria no topo, Função abaixo, ambas em largura total.
    case vertical
}

// MARK: - Estado Confirmado

/// Aparência do campo depois que o usuário confirma, de propósito, uma categoria ou função.
/// Tocar no campo confirmado reabre a roleta para revisar a escolha. As variantes preenchidas
/// sempre levam um check: a conclusão se lê pela forma, não só pela cor.
public enum FrilaLPEConfirmedFieldStyle: String, CaseIterable, Sendable {
    /// Superfície neutra com borda terracota e texto da marca em negrito.
    case accentBorder
    /// Laranja do app (`dynamicBrandSolidFill`) com tinta escura (`dynamicBrandSolidText`), AA.
    case solid
    /// Tinta (`dynamicTextInk`) com texto do canvas e check laranja, como os selecionados do app.
    case ink

    var emphasis: FrilaLPEFieldEmphasis {
        switch self {
        case .accentBorder: return .accentBorder
        case .solid: return .solid
        case .ink: return .ink
        }
    }
    var isFilled: Bool { self != .accentBorder }
    var showsCheck: Bool { isFilled }

    /// Rótulo curto para o Design Lab.
    public var label: String {
        switch self {
        case .accentBorder: return "Borda"
        case .solid: return "Laranja"
        case .ink: return "Tinta"
        }
    }
}

// MARK: - Grupo (região comum)

/// Categoria e Função dentro de um único container (lei de região comum da Gestalt): rótulo, chevron e
/// campo de cada uma ficam num corpo só. O campo se separa do grupo por um degrau de tom suave, sem
/// borda nem sombra (design plano); o confirmado é um grafite com texto branco, nunca o preto absoluto.
public enum FrilaLPEPickerGroupStyle: String, CaseIterable, Sendable {
    /// Grafite, neutro frio. Padrão do formulário.
    case neutral
    /// Pedra, neutro quente.
    case stone
    /// Experimental: grupo no laranja de seleção, rótulos brancos, campo na cor da tela.
    case brand

    public var label: String {
        switch self {
        case .neutral: return "Grafite"
        case .stone: return "Pedra"
        case .brand: return "Laranja"
        }
    }

    /// Fundo do grupo. Claro (grafite e pedra): cartão branco elevado (anel e sombra em camadas),
    /// porque cinzas próximos lado a lado liam como protótipo. Escuro: os tons de grupo.
    public func fill(isDark: Bool) -> Color {
        switch self {
        case .neutral: return isDark ? FrilaLPEColor.dynamicGroupGraphite(isDark: true) : FrilaLPEColor.canvasLight
        case .stone: return isDark ? FrilaLPEColor.dynamicGroupStone(isDark: true) : FrilaLPEColor.dynamicGroupStoneField(isDark: false)
        case .brand: return FrilaLPEColor.primarySelection
        }
    }

    public func fieldFill(isDark: Bool) -> Color {
        switch self {
        case .neutral: return isDark ? FrilaLPEColor.dynamicGroupGraphiteField(isDark: true) : FrilaLPEColor.groupFieldLight
        case .stone: return isDark ? FrilaLPEColor.dynamicGroupStoneField(isDark: true) : FrilaLPEColor.dynamicGroupStone(isDark: false)
        case .brand: return FrilaLPEColor.dynamicCanvas(isDark: isDark)
        }
    }

    /// Filete do campo dentro do grupo: só no modo claro dos grupos neutros.
    public func fieldStroke(isDark: Bool) -> Color? {
        (isDark || self == .brand) ? nil : FrilaLPEColor.groupFieldStrokeLight
    }

    /// Elevação do grupo sobre a tela: anel e sombra nos grupos neutros claros; anel no escuro.
    var hasElevation: Bool { self != .brand }

    /// Confirmado. Claro: o laranja de seleção com texto branco (a cor volta para o "feito"). Escuro: grafite.
    public func confirmedFill(isDark: Bool) -> Color {
        switch self {
        case .neutral: return isDark ? FrilaLPEColor.dynamicGroupGraphiteConfirmed(isDark: true) : FrilaLPEColor.primarySelection
        case .stone: return isDark ? FrilaLPEColor.dynamicGroupStoneConfirmed(isDark: true) : FrilaLPEColor.primarySelection
        case .brand: return FrilaLPEColor.dynamicGroupGraphiteConfirmed(isDark: isDark)
        }
    }

    /// Rótulos e chevrons sobre o grupo.
    func labelColor(isDark: Bool) -> Color {
        self == .brand ? FrilaLPEColor.canvasLight : FrilaLPEColor.dynamicTextPrimary(isDark: isDark)
    }

    func chevronColor(isOpen: Bool, isDark: Bool) -> Color {
        if self == .brand { return FrilaLPEColor.canvasLight.opacity(isOpen ? 1 : 0.8) }
        return isOpen ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : FrilaLPEColor.dynamicFormTextMuted(isDark: isDark)
    }
}

// MARK: - Conclusão Unificada do Par de Roletas (M20 / Q1 / Q2)

public struct FrilaLPECoupledPickerConclusionResult: Equatable, Sendable {
    public let resolvedCategory: FrilaLPERoleCategory?
    public let resolvedRole: String
    public let resolvedRoleOrigin: FrilaLPERoleOrigin

    public init(
        resolvedCategory: FrilaLPERoleCategory?,
        resolvedRole: String,
        resolvedRoleOrigin: FrilaLPERoleOrigin
    ) {
        self.resolvedCategory = resolvedCategory
        self.resolvedRole = resolvedRole
        self.resolvedRoleOrigin = resolvedRoleOrigin
    }
}

public enum FrilaLPECoupledPickerConclusion {
    /// Resolve o par de categorias e funções ao fechar (por cabeçalho, item central ou toque fora).
    ///
    /// Decisão do Wizard para R11:
    /// Com "Nova categoria" ou "Nova função" no destino, o PAR inteiro volta ao último par confirmado
    /// (categoria e função juntas), porque a categoria é só filtro e a função é o dado publicado.
    /// Sem par anterior, fica vazio. Reutiliza FrilaLPERoleCouplingRules diretamente.
    public static func resolve(
        categorySnapshot: FrilaLPEWheelSnapshot? = nil,
        roleSnapshot: FrilaLPEWheelSnapshot? = nil,
        categoryItem: FrilaLPEWheelItem? = nil,
        roleItem: FrilaLPEWheelItem? = nil,
        categoryProvenance: FrilaLPESnapshotProvenance? = nil,
        roleProvenance: FrilaLPESnapshotProvenance? = nil,
        lastConfirmedCategory: FrilaLPERoleCategory? = nil,
        lastConfirmedRole: String = "",
        lastConfirmedOrigin: FrilaLPERoleOrigin = .catalog,
        customCategories: [FrilaLPERoleCategory] = [],
        customRolesByCategory: [String: [FrilaLPERole]] = [:]
    ) -> FrilaLPECoupledPickerConclusionResult {
        let catItem = categorySnapshot?.eligibleItem ?? categoryItem
        let rItem = roleSnapshot?.eligibleItem ?? roleItem

        let catProvenance = categoryProvenance ?? categorySnapshot?.provenance ?? (categoryItem != nil ? .explicitInteraction : .visualSuggestion)
        let rProvenance = roleProvenance ?? roleSnapshot?.provenance ?? (roleItem != nil ? .explicitInteraction : .visualSuggestion)

        let isCategoryAction = catItem?.isAction == true
        let isRoleAction = rItem?.isAction == true

        // Decisão do Wizard para R11: se qualquer destino for "Nova...", reverte o par inteiro
        if isCategoryAction || isRoleAction {
            if !lastConfirmedRole.isEmpty {
                return FrilaLPECoupledPickerConclusionResult(
                    resolvedCategory: lastConfirmedCategory,
                    resolvedRole: lastConfirmedRole,
                    resolvedRoleOrigin: lastConfirmedOrigin
                )
            } else {
                return FrilaLPECoupledPickerConclusionResult(
                    resolvedCategory: nil,
                    resolvedRole: "",
                    resolvedRoleOrigin: .catalog
                )
            }
        }

        // 1. Categoria:
        let resolvedCategory: FrilaLPERoleCategory?
        switch catProvenance {
        case .explicitInteraction:
            if let catItem {
                resolvedCategory = FrilaLPECoupledRolePicker.category(withID: catItem.id, customCategories: customCategories)
            } else {
                resolvedCategory = lastConfirmedCategory
            }
        case .confirmed:
            resolvedCategory = lastConfirmedCategory
        case .visualSuggestion:
            resolvedCategory = lastConfirmedCategory
        }

        // 2. Função:
        let resolvedRole: String
        let resolvedOrigin: FrilaLPERoleOrigin

        switch rProvenance {
        case .explicitInteraction:
            if let rItem {
                if !rItem.isSelectable || rItem.isNeutral {
                    resolvedRole = ""
                    resolvedOrigin = .catalog
                } else {
                    let candidateRole = FrilaLPERole(id: rItem.id, name: rItem.title)
                    let isCustom = rItem.isCustom

                    if let cat = resolvedCategory {
                        let customs = customRolesByCategory[cat.id] ?? []
                        let coupled = FrilaLPERoleCouplingRules.resolveRoleOnCategoryChange(
                            currentRole: candidateRole,
                            newCategory: cat,
                            customRolesInCategory: customs
                        )
                        if let coupled {
                            resolvedRole = coupled.name
                            resolvedOrigin = isCustom ? .custom : .catalog
                        } else {
                            resolvedRole = ""
                            resolvedOrigin = .catalog
                        }
                    } else {
                        resolvedRole = candidateRole.name
                        resolvedOrigin = isCustom ? .custom : .catalog
                    }
                }
            } else {
                resolvedRole = lastConfirmedRole
                resolvedOrigin = lastConfirmedOrigin
            }

        case .confirmed, .visualSuggestion:
            // N1: Sugestão visual não vira escolha nem promoção de vazio para função
            if let cat = resolvedCategory, !lastConfirmedRole.isEmpty {
                let currentRoleObj = FrilaLPERoleCatalog.match(lastConfirmedRole) ?? FrilaLPERole(id: lastConfirmedRole, name: lastConfirmedRole)
                let customs = customRolesByCategory[cat.id] ?? []
                let coupled = FrilaLPERoleCouplingRules.resolveRoleOnCategoryChange(
                    currentRole: currentRoleObj,
                    newCategory: cat,
                    customRolesInCategory: customs
                )
                if let coupled {
                    resolvedRole = coupled.name
                    resolvedOrigin = lastConfirmedOrigin
                } else {
                    resolvedRole = ""
                    resolvedOrigin = .catalog
                }
            } else {
                resolvedRole = lastConfirmedRole
                resolvedOrigin = lastConfirmedOrigin
            }
        }

        return FrilaLPECoupledPickerConclusionResult(
            resolvedCategory: resolvedCategory,
            resolvedRole: resolvedRole,
            resolvedRoleOrigin: resolvedOrigin
        )
    }
}

// MARK: - Transição de Categoria no Seletor Acoplado (V3-R11 / W4-1 / W4-R1 / SC-R1)

/// Resultado da transição de categoria ao assentar a roleta no par acoplado.
/// Contém o novo par selecionado.
struct FrilaLPECoupledCategoryTransitionResult: Equatable {
    let selectedCategory: FrilaLPERoleCategory
    let selectedRole: String
    let selectedRoleOrigin: FrilaLPERoleOrigin
}

/// Estado de seleção e do snapshot do último par confirmado no seletor acoplado.
struct FrilaLPECoupledPickerState: Equatable {
    var selectedCategory: FrilaLPERoleCategory? = nil
    var selectedRole: String = ""
    var selectedRoleOrigin: FrilaLPERoleOrigin = .catalog
    var isCategoryExplicit: Bool = false
    var lastConfirmedCategory: FrilaLPERoleCategory? = nil
    var lastConfirmedRole: String = ""
    var lastConfirmedOrigin: FrilaLPERoleOrigin = .catalog

    /// Aplica o resultado da transição de categoria assentada.
    ///
    /// Regra V3-R11 / W4-1 / SC-R1:
    /// A categoria é apenas filtro: assentar a categoria atualiza a seleção e marca a categoria
    /// como explícita, mas NUNCA sobrescreve o snapshot do último par confirmado
    /// (`lastConfirmedCategory`, `lastConfirmedRole`, `lastConfirmedOrigin`).
    mutating func apply(categoryTransition transition: FrilaLPECoupledCategoryTransitionResult) {
        selectedCategory = transition.selectedCategory
        selectedRole = transition.selectedRole
        selectedRoleOrigin = transition.selectedRoleOrigin
        isCategoryExplicit = true
    }
}

enum FrilaLPECoupledCategoryTransition {
    /// Calcula o novo estado do par após a roleta de categoria assentar.
    ///
    /// Regra V3-R11 / W4-1:
    /// A categoria é apenas filtro: girar a categoria NÃO atualiza o snapshot do par.
    /// O snapshot muda só quando a função (o par) é confirmada, ou com escolha explícita de vazio.
    static func resolve(
        item: FrilaLPEWheelItem,
        selectedRole: String,
        selectedRoleOrigin: FrilaLPERoleOrigin = .catalog,
        customCategories: [FrilaLPERoleCategory] = [],
        customRolesByCategory: [String: [FrilaLPERole]] = [:]
    ) -> FrilaLPECoupledCategoryTransitionResult? {
        if item.isAction { return nil }

        guard let newCategory = FrilaLPECoupledRolePicker.category(withID: item.id, customCategories: customCategories) else {
            return nil
        }

        let previousRole = FrilaLPERoleCatalog.match(selectedRole) ?? (!selectedRole.isEmpty ? FrilaLPERole(id: selectedRole, name: selectedRole) : nil)
        let customs = customRolesByCategory[newCategory.id] ?? []
        let resolved = FrilaLPERoleCouplingRules.resolveRoleOnCategoryChange(
            currentRole: previousRole,
            newCategory: newCategory,
            customRolesInCategory: customs
        )

        let newSelectedRole: String
        let newSelectedRoleOrigin: FrilaLPERoleOrigin
        if let resolved {
            newSelectedRole = resolved.name
            newSelectedRoleOrigin = selectedRoleOrigin
        } else {
            newSelectedRole = ""
            newSelectedRoleOrigin = .catalog
        }

        // A categoria é só filtro: girar a categoria NÃO atualiza o snapshot do par (V3-R11 / W4-1).
        // O snapshot muda só quando a função (o par) é confirmada, ou com escolha explícita de vazio.
        return FrilaLPECoupledCategoryTransitionResult(
            selectedCategory: newCategory,
            selectedRole: newSelectedRole,
            selectedRoleOrigin: newSelectedRoleOrigin
        )
    }
}

// MARK: - Componente Canônico: FrilaLPECoupledRolePicker

/// Seletor acoplado de Função em duas roletas inline (Categoria e Função).
/// Substitui as pílulas provisórias de seleção e cumpre os 6 pilares anti-slop do Frila.
public struct FrilaLPECoupledRolePicker: View {
    public let axis: FrilaLPECoupledRolePickerAxis
    @Binding public var selectedRole: String
    @Binding public var selectedRoleOrigin: FrilaLPERoleOrigin
    public let isDark: Bool
    public let onSelectionChanged: (() -> Void)?
    public let confirmedStyle: FrilaLPEConfirmedFieldStyle
    /// Nil: seções soltas. Com estilo: as duas seções num grupo, campos como recorte.
    public let groupStyle: FrilaLPEPickerGroupStyle?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.frilaLPEOutsideTapCoordinator) private var outsideTapCoordinator
    public static let defaultOutsideTapAnchorID = "frila_coupled_role_picker"
    public static let defaultCategoryAnchorID = "frila_coupled_category"
    public static let defaultRoleAnchorID = "frila_coupled_role"

    @available(*, deprecated, message: "Use pickerInstanceID for instance-scoped anchor IDs")
    public static var outsideTapAnchorID: String { defaultOutsideTapAnchorID }
    @available(*, deprecated, message: "Use pickerInstanceID for instance-scoped anchor IDs")
    public static var categoryAnchorID: String { defaultCategoryAnchorID }
    @available(*, deprecated, message: "Use pickerInstanceID for instance-scoped anchor IDs")
    public static var roleAnchorID: String { defaultRoleAnchorID }

    @State private var defaultPickerInstanceID: String = "coupled_picker_\(UUID().uuidString.prefix(8))"
    private var explicitPickerInstanceID: String? = nil

    public func pickerInstanceID(_ id: String) -> FrilaLPECoupledRolePicker {
        var copy = self
        copy.explicitPickerInstanceID = id
        return copy
    }

    private var effectiveInstanceID: String {
        explicitPickerInstanceID ?? defaultPickerInstanceID
    }

    var outsideTapAnchorID: String { "\(effectiveInstanceID)_picker" }
    var categoryAnchorID: String { "\(effectiveInstanceID)_category" }
    var roleAnchorID: String { "\(effectiveInstanceID)_role" }
    var categoryCustomInputFieldID: String { "\(effectiveInstanceID)_category_custom_input" }
    var roleCustomInputFieldID: String { "\(effectiveInstanceID)_role_custom_input" }

    // MARK: - Estado Interno da Navegação e Acoplamento

    @State public var selectedCategory: FrilaLPERoleCategory? = nil
    /// Verdadeiro quando o usuário confirmou a categoria na roleta. Uma categoria só derivada da função
    /// (pré-seleção ou escolha direta de função) é contexto: não vira estado confirmado.
    @State private var isCategoryExplicit: Bool = false
    /// Sobe quando o usuário fecha uma roleta com um valor escolhido: dispara o pulo do check e o
    /// háptico de sucesso. Só o gesto do usuário conta; uma pré-seleção ao abrir a tela não celebra.
    @State private var confirmTrigger: Int = 0
    /// Sobe quando uma roleta abre: o chevron de recolher no cabeçalho dá um único pulo.
    @State private var collapseCueTrigger: Int = 0
    private var explicitIsCategoryOpen: Binding<Bool>? = nil
    private var explicitIsRoleOpen: Binding<Bool>? = nil
    @State private var internalIsCategoryOpen: Bool
    @State private var internalIsRoleOpen: Bool

    public var isCategoryOpen: Bool {
        get { explicitIsCategoryOpen?.wrappedValue ?? internalIsCategoryOpen }
        nonmutating set {
            if let explicit = explicitIsCategoryOpen {
                explicit.wrappedValue = newValue
            } else {
                internalIsCategoryOpen = newValue
            }
        }
    }

    public var isRoleOpen: Bool {
        get { explicitIsRoleOpen?.wrappedValue ?? internalIsRoleOpen }
        nonmutating set {
            if let explicit = explicitIsRoleOpen {
                explicit.wrappedValue = newValue
            } else {
                internalIsRoleOpen = newValue
            }
        }
    }

    /// Último par confirmado gravado na abertura do par para reversão (Q2 / R11)
    @State private var lastConfirmedCategory: FrilaLPERoleCategory? = nil
    @State private var lastConfirmedRole: String = ""
    @State private var lastConfirmedOrigin: FrilaLPERoleOrigin = .catalog
    /// Controlador do término síncrono de giros ativos nas colunas da roleta (R3)
    @State var spinController = FrilaLPEWheelSpinController()

    /// Snapshots expostos pelas roletas de Categoria e Função para arbitragem de fechamento (M20 / Q1).
    @State private var categorySnapshot: FrilaLPEWheelSnapshot? = nil
    @State private var roleSnapshot: FrilaLPEWheelSnapshot? = nil
    /// Categoria em foco durante o arrasto da roleta de Categoria; a lista de Função a acompanha ao vivo.
    @State private var previewCategoryID: String? = nil
    /// Troca de lista pendente (fricção por velocidade) e o relógio usado para medi-la.
    @State private var pendingPreviewTask: Task<Void, Never>? = nil
    @State private var lastHighlightAt: Date? = nil
    @State private var pendingSince: Date? = nil
    /// Verdadeiro enquanto a troca da lista de Função está adiada o bastante para mostrar o estado aguardando.
    @State private var isRoleListPending: Bool = false

    @State public var customCategories: [FrilaLPERoleCategory] = []
    @State public var customRolesByCategory: [String: [FrilaLPERole]] = [:]

    // Adição de categoria personalizada
    @State public var isAddingCategory: Bool = false
    @State public var categoryInputText: String = ""
    @State public var categoryDuplicateMatch: FrilaLPERole? = nil

    // Adição de função personalizada
    @State public var isAddingRole: Bool = false
    @State public var roleInputText: String = ""
    @State public var roleDuplicateMatch: FrilaLPERole? = nil

    public init(
        axis: FrilaLPECoupledRolePickerAxis = .horizontal,
        selectedRole: Binding<String>,
        selectedRoleOrigin: Binding<FrilaLPERoleOrigin>,
        isCategoryOpen: Binding<Bool>? = nil,
        isRoleOpen: Binding<Bool>? = nil,
        isDark: Bool = false,
        onSelectionChanged: (() -> Void)? = nil,
        confirmedStyle: FrilaLPEConfirmedFieldStyle = .solid,
        groupStyle: FrilaLPEPickerGroupStyle? = nil
    ) {
        self.confirmedStyle = confirmedStyle
        self.groupStyle = groupStyle
        self.axis = axis
        self._selectedRole = selectedRole
        self._selectedRoleOrigin = selectedRoleOrigin
        self.explicitIsCategoryOpen = isCategoryOpen
        self.explicitIsRoleOpen = isRoleOpen
        self._internalIsCategoryOpen = State(initialValue: isCategoryOpen?.wrappedValue ?? false)
        self._internalIsRoleOpen = State(initialValue: isRoleOpen?.wrappedValue ?? false)
        self.isDark = isDark
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        Group {
            switch axis {
            case .horizontal:
                unifiedPicker
                    .frilaLPEOutsideTap(id: outsideTapAnchorID, isOpen: isExpanded) {
                        concludeAndCollapsePair(isOutsideTap: true)
                    }
            case .vertical:
                if let groupStyle {
                    // Região comum: R_grupo = R_campo (14) + respiro (12) = 26
                    VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
                        verticalCategorySection
                        verticalRoleSection
                    }
                    .padding(.horizontal, Self.groupPadding)
                    .padding(.bottom, Self.groupPadding)
                    // O cabeçalho de 44 pt já traz respiro em cima
                    .padding(.top, FrilaLPEGeometry.space4)
                    .background(groupStyle.fill(isDark: isDark), in: RoundedRectangle(cornerRadius: Self.groupRadius, style: .continuous))
                    .modifier(FrilaLPEGroupElevation(isActive: groupStyle.hasElevation, isDark: isDark, cornerRadius: Self.groupRadius))
                } else {
                    VStack(alignment: .leading, spacing: FrilaLPEGeometry.space16) {
                        verticalCategorySection
                        verticalRoleSection
                    }
                }
            }
        }
        .onAppear {
            initializeSelection()
        }
        .onChange(of: isCategoryOpen || isRoleOpen) { _, _ in
            // Pulo depois de a roleta assentar, para o olhar chegar ao cabeçalho com a lista já aberta
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(FrilaLPEMotion.confirmCelebrationDelayMs))
                collapseCueTrigger += 1
            }
        }
        .onChange(of: isRoleOpen) { wasOpen, isOpen in
            if wasOpen && !isOpen && !selectedRole.isEmpty { celebrateConfirmation() }
        }
        .onChange(of: isCategoryOpen) { wasOpen, isOpen in
            if wasOpen && !isOpen && isCategoryExplicit && selectedCategory != nil { celebrateConfirmation() }
        }
        .sensoryFeedback(.success, trigger: confirmTrigger)
    }

    /// Conclusão: espera o campo assentar fechado (o check acabou de entrar) e então pula o check.
    private func celebrateConfirmation() {
        guard showsConfirmedCheck else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(FrilaLPEMotion.confirmCelebrationDelayMs))
            confirmTrigger += 1
        }
    }

    static let groupPadding: CGFloat = FrilaLPEGeometry.space12
    /// Placeholders com exemplos: o rótulo acima já diz o que é; o campo vazio mostra o que cabe nele.
    static let categoryHint = "Bar, cozinha, eventos"
    static let roleHint = "Garçom, barista, cozinheiro"
    /// R_grupo = R_campo (14) + respiro (12) = 26.
    static let groupRadius: CGFloat = FrilaLPEGeometry.concentricOuterRadius(innerRadius: FrilaLPEGeometry.radiusInput, padding: groupPadding)

    /// Chrome do campo: recorte dentro do grupo, ou o campo padrão.
    private var fieldChrome: FrilaLPEFieldChrome {
        guard let groupStyle else { return .standard }
        return .cutout(fill: groupStyle.fieldFill(isDark: isDark), radius: FrilaLPEGeometry.radiusInput, stroke: groupStyle.fieldStroke(isDark: isDark))
    }

    /// Ênfase do campo confirmado: no grupo, a cor que contrasta com ele; solto, a variante escolhida.
    private var confirmedEmphasis: FrilaLPEFieldEmphasis {
        if let groupStyle { return .filled(groupStyle.confirmedFill(isDark: isDark)) }
        return confirmedStyle.emphasis
    }

    private var showsConfirmedCheck: Bool { groupStyle != nil || confirmedStyle.showsCheck }

    // MARK: - Mola de Transição e Invariante de Redução de Movimento

    /// Expansão com leve bounce, recolhimento mais contido: abrir convida, fechar só assenta.
    private func disclosureAnimation(opening: Bool) -> Animation {
        opening ? FrilaLPEMotion.disclosureExpand : FrilaLPEMotion.disclosureCollapse
    }

    // MARK: - Roletas (compartilhadas pelos dois layouts)

    private var categoryWheelView: some View {
        FrilaLPEWheelColumn(
            title: "Categoria",
            items: categoryWheelItems,
            selectedID: selectedCategory?.id,
            isEditingCustom: $isAddingCategory,
            customText: $categoryInputText,
            customPlaceholder: "Nome da categoria",
            duplicateSuggestion: categoryDuplicateMatch,
            isDark: isDark,
            onCommit: { item in
                handleCategoryCommitted(item: item)
            },
            onUseDuplicate: { role in
                handleUseCategoryDuplicate(role: role)
            },
            onSubmitCustom: {
                submitCustomCategory()
            },
            onCancelCustom: {
                cancelCustomCategory()
            }
        )
        .chromeless()
        .leadingAligned(axis == .vertical)
        .spinController(spinController, columnID: "category")
        .initialProvenance(selectedCategory != nil ? .confirmed : .visualSuggestion)
        .customInputFieldID(categoryCustomInputFieldID)
        .onHighlight { item in
            guard item.isSelectable, !item.isAction else { return }
            scheduleCategoryPreview(id: item.id)
        }
        .onSnapshot { snapshot in
            categorySnapshot = snapshot
        }
    }

    private var roleWheelView: some View {
        FrilaLPEWheelColumn(
            title: "Função",
            items: roleWheelItems,
            selectedID: currentRoleWheelSelectedID,
            isEditingCustom: $isAddingRole,
            customText: $roleInputText,
            customPlaceholder: "Nome da função",
            duplicateSuggestion: roleDuplicateMatch,
            isDark: isDark,
            onCommit: { item in
                handleRoleCommitted(item: item)
            },
            onUseDuplicate: { role in
                handleUseRoleDuplicate(role: role)
            },
            onSubmitCustom: {
                submitCustomRole()
            },
            onCancelCustom: {
                cancelCustomRole()
            }
        )
        .chromeless()
        .leadingAligned(axis == .vertical)
        .spinController(spinController, columnID: "role")
        .showsPending(isRoleListPending)
        .initialProvenance(!selectedRole.isEmpty ? .confirmed : .visualSuggestion)
        .customInputFieldID(roleCustomInputFieldID)
        .onSnapshot { snapshot in
            roleSnapshot = snapshot
        }
    }

    // MARK: - Campo Único (layout horizontal)

    /// Largura dos nomes mais longos do catálogo em cada coluna, medida uma vez por cópias ocultas.
    /// A divisão das colunas sai daqui e não muda com a seleção nem ao abrir e fechar: o divisor fica parado.
    @State private var closedIdealWidths: [CGFloat] = [0, 0]

    private var isExpanded: Bool { isCategoryOpen || isRoleOpen }

    private var splitIdeals: [CGFloat] { closedIdealWidths }

    /// Seleção confirmada: campo fechado com a função escolhida (a categoria só filtra, não é publicada).
    /// Ganha o tom da marca.
    private var isConfirmed: Bool { !isExpanded && !selectedRole.isEmpty }

    /// Nomes de referência para a divisão: o mais longo de cada coluna no catálogo.
    private static var longestCategoryName: String { FrilaLPERoleCatalog.categories.map(\.name).max { $0.count < $1.count } ?? "Categoria" }
    private static var longestRoleName: String { FrilaLPERoleCatalog.roles.map(\.name).max { $0.count < $1.count } ?? "Função" }

    /// Um único gesto: tocar em qualquer parte do bloco (títulos, campo ou chevron) expande ou recolhe as duas roletas.
    private func toggleAllWheels() {
        let opening = !isExpanded
        if opening {
            outsideTapCoordinator?.updateAnchorOpen(id: outsideTapAnchorID, isOpen: true)
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
                lastConfirmedCategory = selectedCategory
                lastConfirmedRole = selectedRole
                lastConfirmedOrigin = selectedRoleOrigin
                isCategoryOpen = true
                isRoleOpen = true
            }
        } else {
            concludeAndCollapsePair(isOutsideTap: false)
        }
    }

    // MARK: - Conclusão Unificada do Par (M20 / Q1 / Q2 / R10)

    private func concludeAndCollapsePair(isOutsideTap: Bool) {
        guard isExpanded else { return }

        // R3: Conclusão síncrona do giro sem animação antes de iniciar o recolhimento
        let catConcludedSnapshot = spinController.concludeSpin(columnID: "category")
        let roleConcludedSnapshot = spinController.concludeSpin(columnID: "role")

        if isOutsideTap {
            if isAddingCategory { isAddingCategory = false }
            if isAddingRole { isAddingRole = false }
        }

        cancelPendingPreview()

        let catSnap = catConcludedSnapshot ?? categorySnapshot
        let roleSnap = roleConcludedSnapshot ?? roleSnapshot

        let conclusion = FrilaLPECoupledPickerConclusion.resolve(
            categorySnapshot: catSnap,
            roleSnapshot: roleSnap,
            lastConfirmedCategory: lastConfirmedCategory,
            lastConfirmedRole: lastConfirmedRole,
            lastConfirmedOrigin: lastConfirmedOrigin,
            customCategories: customCategories,
            customRolesByCategory: customRolesByCategory
        )

        // R10: Inicia o ciclo de recolhimento no coordenador antes de escrever o estado fechado
        let catCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: categoryAnchorID) : nil
        let roleCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: roleAnchorID) : nil
        let horizontalCycleID = axis == .horizontal ? outsideTapCoordinator?.beginCollapse(id: outsideTapAnchorID) : nil

        if reduceMotion {
            selectedCategory = conclusion.resolvedCategory
            isCategoryExplicit = conclusion.resolvedCategory != nil && (catSnap?.provenance == .explicitInteraction || (isCategoryExplicit && catSnap?.provenance == .confirmed))
            selectedRole = conclusion.resolvedRole
            selectedRoleOrigin = conclusion.resolvedRoleOrigin

            lastConfirmedCategory = conclusion.resolvedCategory
            lastConfirmedRole = conclusion.resolvedRole
            lastConfirmedOrigin = conclusion.resolvedRoleOrigin

            isCategoryOpen = false
            isRoleOpen = false

            if axis == .vertical {
                outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
            } else {
                outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
            }
        } else {
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: false), reduzir: reduceMotion) ?? .linear(duration: 0), completionCriteria: .logicallyComplete) {
                selectedCategory = conclusion.resolvedCategory
                isCategoryExplicit = conclusion.resolvedCategory != nil && (catSnap?.provenance == .explicitInteraction || (isCategoryExplicit && catSnap?.provenance == .confirmed))
                selectedRole = conclusion.resolvedRole
                selectedRoleOrigin = conclusion.resolvedRoleOrigin

                lastConfirmedCategory = conclusion.resolvedCategory
                lastConfirmedRole = conclusion.resolvedRole
                lastConfirmedOrigin = conclusion.resolvedRoleOrigin

                isCategoryOpen = false
                isRoleOpen = false
            } completion: {
                if axis == .vertical {
                    outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                    outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
                } else {
                    outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
                }
            }
        }

        onSelectionChanged?()
    }

    private var unifiedPicker: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space6) {
            unifiedHeader

            FrilaLPEMorphingFieldContainer(isOpen: isExpanded, isDark: isDark, emphasis: isConfirmed ? confirmedStyle.emphasis : .none) {
                FrilaLPESplitFieldLayout(ideals: splitIdeals) {
                    unifiedColumn(isCategory: true)
                    unifiedColumn(isCategory: false)
                    Rectangle()
                        .fill(FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark))
                        .frame(width: 1)
                        .padding(.vertical, FrilaLPEGeometry.space12)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isExpanded { toggleAllWheels() }
            }
            .accessibilityElement(children: isExpanded ? .contain : .ignore)
            // Enxerto: identificador do formulário antigo do app, para os testes de UI
            .accessibilityIdentifier(isExpanded ? "" : "funcao-vaga-picker")
            .accessibilityLabel(isExpanded ? "" : String(localized: "Categoria \(selectedCategory?.name ?? "não escolhida"), função \(selectedRole.isEmpty ? "não escolhida" : selectedRole)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
            .accessibilityHint(isExpanded ? "" : String(localized: "Toque para escolher", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
            .accessibilityAddTraits(isExpanded ? [] : .isButton)
        }
        .onPreferenceChange(FrilaLPEClosedIdealWidthKey.self) { widths in
            // Com as roletas abertas não há rótulos medindo: mantém a última medição em vez de zerar.
            guard widths.count == 2, widths.allSatisfy({ $0 > 0 }), widths != closedIdealWidths else { return }
            closedIdealWidths = widths
        }
    }

    /// Títulos alinhados às colunas (mesmo layout do campo) e um único chevron: tudo é a mesma área de toque.
    private var unifiedHeader: some View {
        Button(action: toggleAllWheels) {
            ZStack(alignment: .trailing) {
                FrilaLPESplitFieldLayout(ideals: splitIdeals) {
                    headerLabel("Categoria")
                    headerLabel("Função")
                }
                Image(systemName: "chevron.down")
                    .font(FrilaLPEFonteDoSistema.fonte(size: 13, weight: .semibold))
                    .foregroundColor(isExpanded ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .padding(.trailing, FrilaLPEGeometry.space4)
            }
            .padding(.vertical, FrilaLPEGeometry.space8)
            .contentShape(Rectangle())
            .padding(.vertical, -FrilaLPEGeometry.space8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Recolher seleção", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
        // Fechado, o próprio campo é o botão agregado: sem um segundo botão equivalente no VoiceOver
        .accessibilityHidden(!isExpanded)
    }

    private func headerLabel(_ title: String) -> some View {
        Text(verbatim: title)
            .font(FrilaLPETypography.captionBold)
            .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func unifiedColumn(isCategory: Bool) -> some View {
        ZStack(alignment: .top) {
            if isExpanded {
                (isCategory ? AnyView(categoryWheelView) : AnyView(roleWheelView))
                    .transition(.frilaLPEFieldContent)
            } else {
                closedColumnLabel(isCategory: isCategory)
                    .transition(.frilaLPEFieldContent)
            }
        }
    }

    private func closedColumnLabel(isCategory: Bool) -> some View {
        // Função escolhida sem categoria explícita: mostra a categoria de catálogo da função como contexto,
        // para o campo confirmado não exibir um placeholder que parece pendente.
        let inferredCategory = selectedCategory == nil
            ? FrilaLPERoleCatalog.match(selectedRole).flatMap { FrilaLPERoleCatalog.categories(containing: $0).first?.name }
            : nil
        let categoryName = selectedCategory?.name ?? inferredCategory
        let title = isCategory ? (categoryName ?? "Categoria") : (selectedRole.isEmpty ? "Função" : selectedRole)
        let isPlaceholder = isCategory ? categoryName == nil : selectedRole.isEmpty
        let badge: String? = (!isCategory && selectedRoleOrigin == .custom && !selectedRole.isEmpty) ? "Criada por você" : nil
        let index = isCategory ? 0 : 1
        let reference = isCategory ? Self.longestCategoryName : Self.longestRoleName
        return closedLabelContent(title: title, isPlaceholder: isPlaceholder, badge: badge, isCategory: isCategory)
            .padding(.horizontal, FrilaLPEGeometry.space14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FrilaLPEGeometry.buttonHeightProminent)
            .background(
                // Cópia oculta do nome mais longo do catálogo: fixa a divisão, sem seguir a seleção atual.
                // Medida sempre em negrito (estilo de resposta), para a confirmação não mexer na largura.
                closedLabelContent(title: reference, isPlaceholder: false, badge: nil, isCategory: false)
                    .padding(.horizontal, FrilaLPEGeometry.space14)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: FrilaLPEClosedIdealWidthKey.self, value: widthsPreference(index: index, width: proxy.size.width))
                    })
            )
    }

    private func widthsPreference(index: Int, width: CGFloat) -> [CGFloat] {
        var values: [CGFloat] = [0, 0]
        values[index] = width
        return values
    }

    /// Rótulo do campo fechado (layout horizontal); nunca reduz a fonte, só trunca no fim.
    /// Confirmado, a função é a resposta (negrito, cor de confirmação) e a categoria é contexto
    /// (peso regular, cor primária). Mesmo corpo nas duas colunas para a largura medida valer.
    private func closedLabelContent(title: String, isPlaceholder: Bool, badge: String?, isCategory: Bool) -> some View {
        let isAnswer = isConfirmed && !isCategory
        let font: Font = isPlaceholder || (isConfirmed && isCategory) ? FrilaLPETypography.body : FrilaLPETypography.bodyBold
        let color: Color = isPlaceholder
            ? FrilaLPEColor.dynamicFormTextMuted(isDark: isDark)
            : (isAnswer ? confirmedTextColor : FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
        let categoryOnSolid = isConfirmed && isCategory && confirmedStyle.isFilled
        return HStack(spacing: FrilaLPEGeometry.space8) {
            Text(verbatim: title)
                .font(font)
                .foregroundColor(categoryOnSolid ? confirmedTextColor : color)
                .lineLimit(1)
                .truncationMode(.tail)

            if let badge {
                badgeChip(badge, onSolid: isAnswer && (groupStyle != nil || confirmedStyle.isFilled))
            }
        }
    }

    // MARK: - Layout vertical empilhado

    /// Cabeçalho de seção. O próprio rótulo é o botão: fechado, só o nome (o chevron que abre mora no
    /// campo); aberto, o nome ganha um chevron para cima no tom da marca, colado ao texto, que dá um único
    /// pulo ao abrir (SF Symbols) para mostrar o caminho de volta. Sem pílula: forma preenchida dentro do
    /// grupo, que já tem campos preenchidos, empilhava volumes. O cabeçalho tem 44 pt nos dois estados.
    private func stackedHeader(_ title: String, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FrilaLPEGeometry.space4) {
                Text(verbatim: title)
                    .frilaLPEType(FrilaLPEFormType.fieldLabel, dynamic: true)
                    .foregroundColor(groupStyle?.labelColor(isDark: isDark) ?? FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                if isOpen {
                    Image(systemName: "chevron.up")
                        .font(FrilaLPEFonteDoSistema.fonte(size: 11, weight: .bold))
                        .foregroundColor(groupStyle?.chevronColor(isOpen: true, isDark: isDark) ?? FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                        .symbolEffect(.bounce.up, options: .nonRepeating, value: reduceMotion ? 0 : collapseCueTrigger)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .frame(height: FrilaLPEGeometry.hitboxMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // No grupo, o rótulo recua até a coluna do texto do campo (14 pt)
        .padding(.leading, groupStyle == nil ? 0 : FrilaLPEGeometry.space14)
        .accessibilityLabel(isOpen ? String(localized: "Recolher \(title.lowercased())", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "Escolher \(title.lowercased())", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
        .accessibilityHint(isOpen ? String(localized: "Recolhe a lista e libera espaço", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : "")
    }

    /// Categoria de contexto: a escolhida ou, sem escolha, a do catálogo a que a função pertence.
    private var displayedCategoryName: String? {
        selectedCategory?.name
            ?? FrilaLPERoleCatalog.match(selectedRole).flatMap { FrilaLPERoleCatalog.categories(containing: $0).first?.name }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            stackedHeader("Categoria", isOpen: isCategoryOpen, action: toggleCategoryWheel)

            let isConfirmedCategory = !isCategoryOpen && isCategoryExplicit && selectedCategory != nil
            FrilaLPEMorphingFieldContainer(isOpen: isCategoryOpen, isDark: isDark, emphasis: isConfirmedCategory ? confirmedEmphasis : .none, chrome: fieldChrome) {
                ZStack(alignment: .top) {
                    if isCategoryOpen {
                        categoryWheelView
                            .transition(.frilaLPEFieldContent)
                    } else {
                        closedFieldButton(
                            title: displayedCategoryName ?? Self.categoryHint,
                            isPlaceholder: displayedCategoryName == nil,
                            isAnswer: isConfirmedCategory,
                            isContext: !isCategoryExplicit,
                            badge: nil,
                            action: toggleCategoryWheel
                        )
                        .transition(.frilaLPEFieldContent)
                    }
                }
            }
        }
    }

    private var roleSection: some View {
        let isConfirmedRole = !isRoleOpen && !selectedRole.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            stackedHeader("Função", isOpen: isRoleOpen, action: toggleRoleWheel)

            FrilaLPEMorphingFieldContainer(isOpen: isRoleOpen, isDark: isDark, emphasis: isConfirmedRole ? confirmedEmphasis : .none, chrome: fieldChrome) {
                ZStack(alignment: .top) {
                    if isRoleOpen {
                        roleWheelView
                            .transition(.frilaLPEFieldContent)
                    } else {
                        closedFieldButton(
                            title: selectedRole.isEmpty ? Self.roleHint : selectedRole,
                            isPlaceholder: selectedRole.isEmpty,
                            isAnswer: isConfirmedRole,
                            isContext: false,
                            badge: selectedRoleOrigin == .custom && !selectedRole.isEmpty ? "Criada por você" : nil,
                            action: toggleRoleWheel
                        )
                        .transition(.frilaLPEFieldContent)
                    }
                }
            }
        }
    }

    private var verticalCategorySection: some View {
        categorySection
            .frilaLPEOutsideTap(id: categoryAnchorID, isOpen: isCategoryOpen) {
                handleVerticalOutsideTap(source: .category)
            }
    }

    private var verticalRoleSection: some View {
        roleSection
            .frilaLPEOutsideTap(id: roleAnchorID, isOpen: isRoleOpen) {
                handleVerticalOutsideTap(source: .role)
            }
    }

    // MARK: - Botão de Campo Fechado (52 pt Prominent)

    /// Cor do texto de um valor confirmado, conforme a variante. No grupo, sempre branco (preto ou laranja).
    private var confirmedTextColor: Color {
        if groupStyle != nil { return FrilaLPEColor.canvasLight }
        switch confirmedStyle {
        case .accentBorder: return FrilaLPEColor.dynamicBrandChipText(isDark: isDark)
        case .solid: return FrilaLPEColor.dynamicBrandSolidText(isDark: isDark)
        case .ink: return FrilaLPEColor.dynamicCanvas(isDark: isDark)
        }
    }

    /// Check de conclusão: na tinta é o acento laranja; no laranja, a mesma tinta do texto.
    private var confirmedCheckColor: Color {
        if groupStyle != nil { return confirmedTextColor }
        return confirmedStyle == .ink ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : confirmedTextColor
    }

    /// Campo fechado do layout vertical. O chevron mora no cabeçalho, então o campo é só o valor.
    /// `isAnswer`: valor confirmado de propósito (estado consolidado, em negrito).
    /// `isContext`: categoria apenas derivada da função, em peso regular, lida como contexto.
    private func closedFieldButton(
        title: String,
        isPlaceholder: Bool,
        isAnswer: Bool,
        isContext: Bool,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FrilaLPEGeometry.space8) {
                if isAnswer && showsConfirmedCheck {
                    Image(systemName: "checkmark")
                        .font(FrilaLPETypography.captionBold)
                        .foregroundColor(confirmedCheckColor)
                        .symbolEffect(.bounce.up, options: .nonRepeating, value: reduceMotion ? 0 : confirmTrigger)
                        .accessibilityHidden(true)
                }

                // Escolha em Bricolage (voz do catálogo); placeholder em SF Pro, como entrada vazia
                Text(verbatim: title)
                    .frilaLPEType(
                        isPlaceholder ? FrilaLPEFormType.input : (isContext && !isAnswer ? FrilaLPEFormType.answerContext : FrilaLPEFormType.answer),
                        dynamic: true
                    )
                    .foregroundColor(
                        isPlaceholder
                            ? FrilaLPEColor.dynamicFormTextMuted(isDark: isDark)
                            : (isAnswer ? confirmedTextColor : FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let badge {
                    badgeChip(badge, onSolid: isAnswer && (groupStyle != nil || confirmedStyle.isFilled))
                }

                Spacer(minLength: 0)

                // Affordance de abrir no próprio campo; aberto, o cabeçalho oferece "Concluir"
                Image(systemName: "chevron.down")
                    .font(FrilaLPEFonteDoSistema.fonte(size: 13, weight: .semibold))
                    .foregroundColor(isAnswer ? confirmedTextColor.opacity(0.8) : FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaLPEGeometry.space14)
            .frame(height: FrilaLPEGeometry.buttonHeightProminent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frilaLPEHitbox()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isAnswer ? [.isSelected] : [])
        .accessibilityHint(isAnswer ? String(localized: "Confirmado. Toque para revisar a escolha.", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "Toque para escolher", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
    }

    /// Selo "Criada por você". Sobre o sólido inverte: texto do par calibrado em fundo translúcido.
    private func badgeChip(_ badge: String, onSolid: Bool) -> some View {
        HStack(spacing: FrilaLPEGeometry.space4) {
            Image(systemName: "square.and.pencil")
                .font(FrilaLPETypography.caption)
            Text(verbatim: badge)
                .font(FrilaLPETypography.caption)
        }
        .foregroundColor(onSolid ? confirmedTextColor : FrilaLPEColor.dynamicBrandChipText(isDark: isDark))
        .padding(.horizontal, FrilaLPEGeometry.space8)
        .padding(.vertical, FrilaLPEGeometry.space2)
        .background(
            onSolid ? confirmedTextColor.opacity(0.16) : FrilaLPEColor.dynamicBrandChipBg(isDark: isDark),
            in: Capsule()
        )
    }

    // MARK: - Itens da Roleta de Categoria

    private var categoryWheelItems: [FrilaLPEWheelItem] {
        var items: [FrilaLPEWheelItem] = []

        // Linha 1: "Todas"
        items.append(FrilaLPEWheelItem(id: FrilaLPERoleCatalog.allCategory.id, title: FrilaLPERoleCatalog.allCategory.name))

        // Categorias nativas
        for cat in FrilaLPERoleCatalog.categories {
            items.append(FrilaLPEWheelItem(id: cat.id, title: cat.name))
        }

        // Categorias criadas pelo contratante
        for custom in customCategories {
            items.append(FrilaLPEWheelItem(id: custom.id, title: custom.name, subtitle: "Criada por você", iconName: "square.and.pencil"))
        }

        // Ação final: Nova categoria
        items.append(FrilaLPEWheelItem(id: "action_add_category", title: "Nova categoria", iconName: "plus.circle", isSelectable: false, isAction: true))

        return items
    }

    // MARK: - Fricção entre as Roletas

    /// Adia a troca da lista de Função conforme a velocidade do arrasto da Categoria.
    /// Cada nova linha cancela a troca pendente; o teto de espera total limita o adiamento.
    private func scheduleCategoryPreview(id: String) {
        let now = Date()
        let rowsPerSecond: Double
        if let last = lastHighlightAt {
            let dt = now.timeIntervalSince(last)
            rowsPerSecond = dt > 0 ? 1 / dt : FrilaLPECouplingDelay.saturationRowsPerSecond
        } else {
            rowsPerSecond = 0
        }
        lastHighlightAt = now

        let since = pendingSince ?? now
        pendingSince = since
        let delay = reduceMotion ? 0 : FrilaLPECouplingDelay.cappedDelay(
            FrilaLPECouplingDelay.delay(rowsPerSecond: rowsPerSecond),
            alreadyWaited: now.timeIntervalSince(since)
        )

        // Estado aguardando só em esperas perceptíveis: abaixo do limiar a troca é rápida demais e piscaria.
        if delay >= FrilaLPECouplingDelay.skeletonThreshold { isRoleListPending = true }

        pendingPreviewTask?.cancel()
        pendingPreviewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            previewCategoryID = id
            pendingSince = nil
            isRoleListPending = false
        }
    }

    /// Descarta a troca pendente e zera a medição (confirmação, recolhimento).
    private func cancelPendingPreview() {
        pendingPreviewTask?.cancel()
        pendingPreviewTask = nil
        lastHighlightAt = nil
        pendingSince = nil
        isRoleListPending = false
        previewCategoryID = nil
    }

    // MARK: - Itens da Roleta de Função

    /// Categoria que alimenta a lista de Função: a que está em foco no arrasto, a confirmada ou "Todas".
    private var roleListCategory: FrilaLPERoleCategory {
        if let id = previewCategoryID, let cat = category(withID: id) { return cat }
        return selectedCategory ?? FrilaLPERoleCatalog.allCategory
    }

    static func category(
        withID id: String,
        customCategories: [FrilaLPERoleCategory] = []
    ) -> FrilaLPERoleCategory? {
        if id == FrilaLPERoleCatalog.allCategory.id { return FrilaLPERoleCatalog.allCategory }
        if let custom = customCategories.first(where: { $0.id == id }) { return custom }
        return FrilaLPERoleCatalog.categories.first(where: { $0.id == id })
    }

    private func category(withID id: String) -> FrilaLPERoleCategory? {
        Self.category(withID: id, customCategories: customCategories)
    }

    private var roleWheelItems: [FrilaLPEWheelItem] {
        var items: [FrilaLPEWheelItem] = []

        // Linha 0: slot neutro (marca discreta), sem texto nem aparência de botão
        items.append(FrilaLPEWheelItem(id: "marker_role", title: "Nenhuma função", isSelectable: false, isNeutral: true))

        let currentCat = roleListCategory
        let catalogRoles = FrilaLPERoleCatalog.roles(in: currentCat)

        for role in catalogRoles {
            items.append(FrilaLPEWheelItem(id: role.id, title: role.name))
        }

        // Funções criadas para a categoria atual
        if let customs = customRolesByCategory[currentCat.id] {
            for custom in customs {
                items.append(
                    FrilaLPEWheelItem(
                        id: custom.id,
                        title: custom.name,
                        subtitle: "Criada por você",
                        iconName: "square.and.pencil"
                    )
                )
            }
        }

        // Ação final: Nova função
        items.append(FrilaLPEWheelItem(id: "action_add_role", title: "Nova função", iconName: "plus.circle", isSelectable: false, isAction: true))

        return items
    }

    // MARK: - Identificador de Seleção na Roleta de Função

    private var currentRoleWheelSelectedID: String? {
        FrilaLPERolePreselection.selectedID(
            selectedRole: selectedRole,
            confirmedID: FrilaLPERoleCatalog.match(selectedRole)?.id,
            hasCategoryContext: selectedCategory != nil || previewCategoryID != nil,
            firstSelectableID: roleWheelItems.first(where: { $0.isSelectable && !$0.isAction })?.id
        )
    }

    // MARK: - Ações de Abertura / Fechamento por Eixo (N4)

    func toggleCategoryWheel() {
        if axis == .vertical {
            if isCategoryOpen {
                concludeAndCollapseCategoryOnly(isOutsideTap: false)
            } else {
                outsideTapCoordinator?.updateAnchorOpen(id: categoryAnchorID, isOpen: true)
                withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
                    if !isExpanded {
                        lastConfirmedCategory = selectedCategory
                        lastConfirmedRole = selectedRole
                        lastConfirmedOrigin = selectedRoleOrigin
                    }
                    isCategoryOpen = true
                }
            }
        } else {
            if isCategoryOpen {
                concludeAndCollapsePair(isOutsideTap: false)
            } else {
                outsideTapCoordinator?.updateAnchorOpen(id: outsideTapAnchorID, isOpen: true)
                withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
                    if !isExpanded {
                        lastConfirmedCategory = selectedCategory
                        lastConfirmedRole = selectedRole
                        lastConfirmedOrigin = selectedRoleOrigin
                    }
                    isCategoryOpen = true
                    isRoleOpen = true
                }
            }
        }
    }

    func toggleRoleWheel() {
        if axis == .vertical {
            if isRoleOpen {
                concludeAndCollapseRoleOnly(isOutsideTap: false)
            } else {
                outsideTapCoordinator?.updateAnchorOpen(id: roleAnchorID, isOpen: true)
                withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
                    if !isExpanded {
                        lastConfirmedCategory = selectedCategory
                        lastConfirmedRole = selectedRole
                        lastConfirmedOrigin = selectedRoleOrigin
                    }
                    isRoleOpen = true
                }
            }
        } else {
            if isRoleOpen {
                concludeAndCollapsePair(isOutsideTap: false)
            } else {
                outsideTapCoordinator?.updateAnchorOpen(id: outsideTapAnchorID, isOpen: true)
                withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
                    if !isExpanded {
                        lastConfirmedCategory = selectedCategory
                        lastConfirmedRole = selectedRole
                        lastConfirmedOrigin = selectedRoleOrigin
                    }
                    isRoleOpen = true
                    isCategoryOpen = true
                }
            }
        }
    }

    func concludeAndCollapseCategoryOnly(isOutsideTap: Bool) {
        guard isCategoryOpen else { return }

        // R3: Conclusão síncrona do giro sem animação antes do recolhimento
        let catConcludedSnapshot = spinController.concludeSpin(columnID: "category")

        if isOutsideTap && isAddingCategory {
            isAddingCategory = false
        }
        cancelPendingPreview()

        let catSnap = catConcludedSnapshot ?? categorySnapshot

        let resolvedCat: FrilaLPERoleCategory?
        let isExplicit: Bool
        switch catSnap?.provenance {
        case .explicitInteraction:
            if let catItem = catSnap?.eligibleItem {
                if catItem.isAction {
                    // Q2/R11: Se destino for "Nova...", reverte à categoria do último par confirmado
                    resolvedCat = lastConfirmedCategory
                    isExplicit = lastConfirmedCategory != nil
                } else if catItem.isSelectable && !catItem.isNeutral {
                    resolvedCat = Self.category(withID: catItem.id, customCategories: customCategories)
                    isExplicit = true
                } else {
                    resolvedCat = nil
                    isExplicit = false
                }
            } else {
                resolvedCat = lastConfirmedCategory
                isExplicit = isCategoryExplicit
            }
        case .confirmed:
            resolvedCat = selectedCategory ?? lastConfirmedCategory
            isExplicit = isCategoryExplicit
        case .visualSuggestion, .none:
            resolvedCat = lastConfirmedCategory
            isExplicit = false
        }

        let cycleID = outsideTapCoordinator?.beginCollapse(id: categoryAnchorID)

        if reduceMotion {
            selectedCategory = resolvedCat
            isCategoryExplicit = isExplicit
            isCategoryOpen = false
            outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: cycleID)
        } else {
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: false), reduzir: reduceMotion) ?? .linear(duration: 0), completionCriteria: .logicallyComplete) {
                selectedCategory = resolvedCat
                isCategoryExplicit = isExplicit
                isCategoryOpen = false
            } completion: {
                outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: cycleID)
            }
        }

        onSelectionChanged?()
    }

    func concludeAndCollapseRoleOnly(isOutsideTap: Bool) {
        guard isRoleOpen else { return }

        // R3: Conclusão síncrona do giro sem animação antes do recolhimento
        let roleConcludedSnapshot = spinController.concludeSpin(columnID: "role")

        if isOutsideTap && isAddingRole {
            isAddingRole = false
        }

        let roleSnap = roleConcludedSnapshot ?? roleSnapshot

        let resolvedRole: String
        let resolvedOrigin: FrilaLPERoleOrigin
        switch roleSnap?.provenance {
        case .explicitInteraction:
            if let rItem = roleSnap?.eligibleItem {
                if rItem.isAction {
                    // Q2/R11: Se destino for "Nova...", reverte ao último par confirmado
                    resolvedRole = lastConfirmedRole
                    resolvedOrigin = lastConfirmedOrigin
                    if !lastConfirmedRole.isEmpty && lastConfirmedCategory != nil {
                        selectedCategory = lastConfirmedCategory
                    }
                } else if rItem.isSelectable && !rItem.isNeutral {
                    let candidateRole = FrilaLPERole(id: rItem.id, name: rItem.title)
                    let isCustom = rItem.isCustom
                    if let cat = selectedCategory {
                        let customs = customRolesByCategory[cat.id] ?? []
                        let coupled = FrilaLPERoleCouplingRules.resolveRoleOnCategoryChange(
                            currentRole: candidateRole,
                            newCategory: cat,
                            customRolesInCategory: customs
                        )
                        if let coupled {
                            resolvedRole = coupled.name
                            resolvedOrigin = isCustom ? .custom : .catalog
                        } else {
                            resolvedRole = ""
                            resolvedOrigin = .catalog
                        }
                    } else {
                        resolvedRole = candidateRole.name
                        resolvedOrigin = isCustom ? .custom : .catalog
                    }
                } else {
                    resolvedRole = ""
                    resolvedOrigin = .catalog
                }
            } else {
                resolvedRole = lastConfirmedRole
                resolvedOrigin = lastConfirmedOrigin
            }
        case .confirmed, .visualSuggestion, .none:
            resolvedRole = lastConfirmedRole
            resolvedOrigin = lastConfirmedOrigin
        }

        let cycleID = outsideTapCoordinator?.beginCollapse(id: roleAnchorID)

        if reduceMotion {
            selectedRole = resolvedRole
            selectedRoleOrigin = resolvedOrigin
            if !resolvedRole.isEmpty && roleSnap?.provenance == .explicitInteraction && !(roleSnap?.eligibleItem?.isAction == true) {
                lastConfirmedRole = resolvedRole
                lastConfirmedOrigin = resolvedOrigin
                lastConfirmedCategory = selectedCategory
            }
            isRoleOpen = false
            outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: cycleID)
        } else {
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: false), reduzir: reduceMotion) ?? .linear(duration: 0), completionCriteria: .logicallyComplete) {
                selectedRole = resolvedRole
                selectedRoleOrigin = resolvedOrigin
                if !resolvedRole.isEmpty && roleSnap?.provenance == .explicitInteraction && !(roleSnap?.eligibleItem?.isAction == true) {
                    lastConfirmedRole = resolvedRole
                    lastConfirmedOrigin = resolvedOrigin
                    lastConfirmedCategory = selectedCategory
                }
                isRoleOpen = false
            } completion: {
                outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: cycleID)
            }
        }

        onSelectionChanged?()
    }

    private enum VerticalSectionSource {
        case category
        case role
    }

    private func handleVerticalOutsideTap(source: VerticalSectionSource) {
        if isCategoryOpen && isRoleOpen {
            concludeAndCollapsePair(isOutsideTap: true)
            return
        }

        switch source {
        case .category:
            if isCategoryOpen {
                concludeAndCollapseCategoryOnly(isOutsideTap: true)
            }
        case .role:
            if isRoleOpen {
                concludeAndCollapseRoleOnly(isOutsideTap: true)
            }
        }
    }

    // MARK: - Estado Canônico do Seletor

    private var currentState: FrilaLPECoupledPickerState {
        FrilaLPECoupledPickerState(
            selectedCategory: selectedCategory,
            selectedRole: selectedRole,
            selectedRoleOrigin: selectedRoleOrigin,
            isCategoryExplicit: isCategoryExplicit,
            lastConfirmedCategory: lastConfirmedCategory,
            lastConfirmedRole: lastConfirmedRole,
            lastConfirmedOrigin: lastConfirmedOrigin
        )
    }

    private func applyState(_ state: FrilaLPECoupledPickerState) {
        selectedCategory = state.selectedCategory
        selectedRole = state.selectedRole
        selectedRoleOrigin = state.selectedRoleOrigin
        isCategoryExplicit = state.isCategoryExplicit
        lastConfirmedCategory = state.lastConfirmedCategory
        lastConfirmedRole = state.lastConfirmedRole
        lastConfirmedOrigin = state.lastConfirmedOrigin
    }

    // MARK: - Manipulação de Confirmação da Categoria

    private func handleCategoryCommitted(item: FrilaLPEWheelItem) {
        if item.isAction {
            isAddingCategory = true
            return
        }

        guard let transition = FrilaLPECoupledCategoryTransition.resolve(
            item: item,
            selectedRole: selectedRole,
            selectedRoleOrigin: selectedRoleOrigin,
            customCategories: customCategories,
            customRolesByCategory: customRolesByCategory
        ) else {
            return
        }

        cancelPendingPreview()

        var state = currentState
        state.apply(categoryTransition: transition)
        applyState(state)

        onSelectionChanged?()

        // Sem avanço automático: a roleta confirma a cada parada, então abrir a Função aqui
        // interromperia quem só está explorando as categorias. A lista de Função já acompanha a
        // categoria ao vivo; o usuário abre a Função quando quiser, e as duas podem ficar abertas.
    }

    // MARK: - Manipulação de Confirmação da Função

    private func handleRoleCommitted(item: FrilaLPEWheelItem) {
        if item.isAction {
            isAddingRole = true
            return
        }

        if !item.isSelectable {
            selectedRole = ""
            selectedRoleOrigin = .catalog
            lastConfirmedRole = ""
            lastConfirmedOrigin = .catalog
            onSelectionChanged?()
            return
        }

        // SPEC 2.3: Quando a função é confirmada, se o usuário tocar no item central já confirmado, fecha o par (ou a função no vertical)
        if selectedRole == item.title {
            if axis == .vertical {
                concludeAndCollapseRoleOnly(isOutsideTap: false)
            } else {
                concludeAndCollapsePair(isOutsideTap: false)
            }
            return
        }

        selectedRole = item.title
        selectedRoleOrigin = item.isCustom ? .custom : .catalog
        lastConfirmedRole = selectedRole
        lastConfirmedOrigin = selectedRoleOrigin
        lastConfirmedCategory = selectedCategory
        onSelectionChanged?()
    }

    // MARK: - Criação de Categoria Personalizada

    private func submitCustomCategory() {
        let (isValid, sanitized, _) = FrilaLPERoleValidation.validate(categoryInputText)
        guard isValid else { return }

        // Anti-duplicata: checa se já existe
        if let existing = FrilaLPERoleCatalog.categories.first(where: { FrilaLPERoleCatalog.fold($0.name) == FrilaLPERoleCatalog.fold(sanitized) }) {
            categoryDuplicateMatch = FrilaLPERole(id: existing.id, name: existing.name)
            return
        }

        let newCategory = FrilaLPERoleCategory(
            id: "custom_cat_\(UUID().uuidString.prefix(8))",
            name: sanitized,
            roleIDs: []
        )

        customCategories.append(newCategory)
        selectedCategory = newCategory
        isCategoryExplicit = true
        isAddingCategory = false
        categoryInputText = ""
        categoryDuplicateMatch = nil

        // A roleta de Função abre na hora com apenas "Adicionar função" no modo de digitação
        withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
            isRoleOpen = true
            isAddingRole = true
            if axis == .vertical {
                isCategoryOpen = false
            }
        }
    }

    private func handleUseCategoryDuplicate(role: FrilaLPERole) {
        if let cat = FrilaLPERoleCatalog.categories.first(where: { $0.id == role.id || FrilaLPERoleCatalog.fold($0.name) == FrilaLPERoleCatalog.fold(role.name) }) {
            selectedCategory = cat
            isCategoryExplicit = true
        }
        isAddingCategory = false
        categoryInputText = ""
        categoryDuplicateMatch = nil
        withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: true), reduzir: reduceMotion)) {
            isRoleOpen = true
        }
    }

    private func cancelCustomCategory() {
        isAddingCategory = false
        categoryInputText = ""
        categoryDuplicateMatch = nil
    }

    // MARK: - Criação de Função Personalizada

    private func submitCustomRole() {
        let (isValid, sanitized, _) = FrilaLPERoleValidation.validate(roleInputText)
        guard isValid else { return }

        // Anti-duplicata: se bater com o catálogo inteiro, não cria
        if let catalogMatch = FrilaLPERoleCatalog.match(sanitized) {
            roleDuplicateMatch = catalogMatch
            return
        }

        let catID = selectedCategory?.id ?? FrilaLPERoleCatalog.allCategory.id
        let newRole = FrilaLPERole(id: "custom_role_\(UUID().uuidString.prefix(8))", name: sanitized)

        var existingCustoms = customRolesByCategory[catID] ?? []
        existingCustoms.append(newRole)
        customRolesByCategory[catID] = existingCustoms

        selectedRole = sanitized
        selectedRoleOrigin = .custom
        isAddingRole = false
        roleInputText = ""
        roleDuplicateMatch = nil
        onSelectionChanged?()

        let catCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: categoryAnchorID) : nil
        let roleCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: roleAnchorID) : nil
        let horizontalCycleID = axis == .horizontal ? outsideTapCoordinator?.beginCollapse(id: outsideTapAnchorID) : nil

        if reduceMotion {
            isRoleOpen = false
            isCategoryOpen = false
            if axis == .vertical {
                outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
            } else {
                outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
            }
        } else {
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: false), reduzir: reduceMotion) ?? .linear(duration: 0), completionCriteria: .logicallyComplete) {
                isRoleOpen = false
                isCategoryOpen = false
            } completion: {
                if axis == .vertical {
                    outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                    outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
                } else {
                    outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
                }
            }
        }
    }

    private func handleUseRoleDuplicate(role: FrilaLPERole) {
        // Se a categoria atual a contém, mantém; senão muda para "Todas"
        if let currentCat = selectedCategory, currentCat.id != FrilaLPERoleCatalog.allCategory.id {
            let rolesInCat = FrilaLPERoleCatalog.roles(in: currentCat)
            if !rolesInCat.contains(where: { $0.id == role.id }) {
                selectedCategory = FrilaLPERoleCatalog.allCategory
            }
        } else {
            selectedCategory = FrilaLPERoleCatalog.allCategory
        }

        selectedRole = role.name
        selectedRoleOrigin = .catalog
        isAddingRole = false
        roleInputText = ""
        roleDuplicateMatch = nil
        onSelectionChanged?()

        let catCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: categoryAnchorID) : nil
        let roleCycleID = axis == .vertical ? outsideTapCoordinator?.beginCollapse(id: roleAnchorID) : nil
        let horizontalCycleID = axis == .horizontal ? outsideTapCoordinator?.beginCollapse(id: outsideTapAnchorID) : nil

        if reduceMotion {
            isRoleOpen = false
            isCategoryOpen = false
            if axis == .vertical {
                outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
            } else {
                outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
            }
        } else {
            withAnimation(FrilaMovimento.animacao(disclosureAnimation(opening: false), reduzir: reduceMotion) ?? .linear(duration: 0), completionCriteria: .logicallyComplete) {
                isRoleOpen = false
                isCategoryOpen = false
            } completion: {
                if axis == .vertical {
                    outsideTapCoordinator?.endCollapse(id: categoryAnchorID, cycleID: catCycleID)
                    outsideTapCoordinator?.endCollapse(id: roleAnchorID, cycleID: roleCycleID)
                } else {
                    outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: horizontalCycleID)
                }
            }
        }
    }

    private func cancelCustomRole() {
        isAddingRole = false
        roleInputText = ""
        roleDuplicateMatch = nil
    }

    // MARK: - Inicialização

    private func initializeSelection() {
        if !selectedRole.isEmpty {
            if let matched = FrilaLPERoleCatalog.match(selectedRole) {
                let containing = FrilaLPERoleCatalog.categories(containing: matched)
                if let first = containing.first {
                    selectedCategory = first
                } else {
                    selectedCategory = FrilaLPERoleCatalog.allCategory
                }
            } else {
                selectedCategory = FrilaLPERoleCatalog.allCategory
            }
        }
        lastConfirmedCategory = selectedCategory
        lastConfirmedRole = selectedRole
        lastConfirmedOrigin = selectedRoleOrigin
    }
}


/// Largura ideal de cada rótulo fechado, publicada pelas cópias ocultas de medição.
private struct FrilaLPEClosedIdealWidthKey: PreferenceKey {
    static let defaultValue: [CGFloat] = [0, 0]
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        let next = nextValue()
        for i in 0..<min(value.count, next.count) where next[i] > 0 { value[i] = next[i] }
    }
}


/// Elevação do grupo de seletores, aplicada só quando a paleta pede.
private struct FrilaLPEGroupElevation: ViewModifier {
    let isActive: Bool
    let isDark: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isActive {
            content.frilaLPEGroupElevation(isDark: isDark, cornerRadius: cornerRadius)
        } else {
            content
        }
    }
}
