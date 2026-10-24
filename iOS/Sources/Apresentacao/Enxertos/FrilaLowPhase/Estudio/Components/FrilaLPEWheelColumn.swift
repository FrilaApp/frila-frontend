import SwiftUI

// MARK: - Modelo de Item da Roleta

/// Item exibido em uma coluna de roleta.
public struct FrilaLPEWheelItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let iconName: String?
    public let isSelectable: Bool
    public let isAction: Bool
    /// Slot neutro: representa "nenhum item" sem texto nem aparência de botão (uma marca discreta).
    public let isNeutral: Bool

    /// Indica se o item representa uma criação customizada (não pertencente ao catálogo nativo).
    public var isCustom: Bool {
        subtitle != nil || iconName == "square.and.pencil"
    }

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        isSelectable: Bool = true,
        isAction: Bool = false,
        isNeutral: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.isSelectable = isSelectable
        self.isAction = isAction
        self.isNeutral = isNeutral
    }
}

// MARK: - Proveniência do Snapshot (N1)

/// Proveniência do snapshot de uma coluna de roleta para garantir que pré-seleção visual não marque escolha (N1).
public enum FrilaLPESnapshotProvenance: String, Equatable, Sendable {
    /// Valor já confirmado anteriormente pelo usuário ou injetado como estado confirmado.
    case confirmed
    /// Sugestão ou pré-seleção visual (abertura de controle, centralização inicial da primeira opção).
    case visualSuggestion
    /// Escolha explícita do usuário (giro/arrasto, toque em item, ajuste AX).
    case explicitInteraction
}

// MARK: - Snapshot de Estado da Roleta

/// Snapshot de estado de escolha da roleta exposto para o coordenador/pai (M20 / Q1 / Q2 / N1).
public struct FrilaLPEWheelSnapshot: Equatable, Sendable {
    public let eligibleItem: FrilaLPEWheelItem?
    public let isMoving: Bool
    public let targetIndex: Int?
    public let spinID: UUID?
    public let provenance: FrilaLPESnapshotProvenance

    public init(
        eligibleItem: FrilaLPEWheelItem? = nil,
        isMoving: Bool = false,
        targetIndex: Int? = nil,
        spinID: UUID? = nil,
        provenance: FrilaLPESnapshotProvenance = .visualSuggestion
    ) {
        self.eligibleItem = eligibleItem
        self.isMoving = isMoving
        self.targetIndex = targetIndex
        self.spinID = spinID
        self.provenance = provenance
    }
}

// MARK: - Componente Canônico: FrilaLPEWheelColumn

/// Coluna de roleta vertical com snap e 5 linhas visíveis de 44 pt (altura total 220 pt).
/// Motor próprio guiado por manipulação direta (.highPriorityGesture), física de inércia UIKit,
/// destaque por máscara de duas camadas e compromisso estrito no repouso da mola.
public struct FrilaLPEWheelColumn: View {
    public let title: String
    public let items: [FrilaLPEWheelItem]
    public let selectedID: String?
    @Binding public var isEditingCustom: Bool
    @Binding public var customText: String
    public let customPlaceholder: String
    public let duplicateSuggestion: FrilaLPERole?
    public let isDark: Bool
    public let onCommit: (FrilaLPEWheelItem) -> Void
    public let onUseDuplicate: ((FrilaLPERole) -> Void)?
    public let onSubmitCustom: (() -> Void)?
    public let onCancelCustom: (() -> Void)?
    public var onSnapshotChange: ((FrilaLPEWheelSnapshot) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isCustomFieldFocused: Bool

    /// Sessão observável do giro/inércia com conclusão síncrona sem animação (R3).
    @State private var spinSession = FrilaLPEWheelSpinSession()
    private var spinController: FrilaLPEWheelSpinController? = nil
    private var columnID: String? = nil
    @State private var lastObservedConclusionRevision: Int = 0

    /// Gatilho sensorial de seleção (disparado ao cruzar cada linha).
    @State private var sensoryTriggerIndex: Int = 0
    /// Sinaliza se a view já apareceu na tela para guiar animações de sincronia externa.
    @State private var hasAppeared: Bool = false
    /// Início da cascata de nascimento da lista nova e linha de origem (a selecionada).
    @State private var spawnStart: Date? = nil
    @State private var spawnOrigin: Int = 0
    @State private var spawnTask: Task<Void, Never>? = nil

    /// Altura de cada linha da roleta adaptável ao Dynamic Type (padrão HIG 44 pt).
    /// 30 pt, a mesma ordem do UIPickerView (32 pt): a roleta é um controle de arrasto, o alvo de toque é a coluna
    /// inteira e não cada linha, então a linha pode ser mais densa que os 44 pt de um botão.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = FrilaLPEWheelColumn.rowHeight
    /// Altura estática padrão para referências de layout.
    public static let rowHeight: CGFloat = 30
    /// Quantidade de linhas visíveis (centro na linha 2, indexada de 0 a 4).
    public static let visibleRowsCount: Int = 5
    /// Altura total do container da roleta padrão (150 pt, antes 220).
    public static let totalHeight: CGFloat = rowHeight * CGFloat(visibleRowsCount)
    /// Padding vertical padrão (88 pt).
    public static let endPadding: CGFloat = rowHeight * 2

    /// Quando falso, a roleta não desenha superfície, borda nem sombra: o container pai
    /// (`FrilaLPEMorphingFieldContainer`) é dono do chrome e o anima junto com a altura.
    private var showsChrome: Bool = true

    /// Devolve a roleta sem chrome próprio, para viver dentro de um container morfável.
    public func chromeless() -> FrilaLPEWheelColumn {
        var copy = self
        copy.showsChrome = false
        return copy
    }

    /// Estado "aguardando": o texto das linhas ganha brilho diagonal, respiração e pulso encadeados
    /// enquanto a lista espera a troca. O texto segue legível, sem esqueleto.
    private var isPending: Bool = false

    public func showsPending(_ pending: Bool) -> FrilaLPEWheelColumn {
        var copy = self
        copy.isPending = pending
        return copy
    }

    /// Experimental: linhas alinhadas pela margem esquerda em vez de centralizadas. O texto começa
    /// na mesma coluna do rótulo do campo fechado (14 pt), então nada salta ao abrir, e a leitura
    /// segue a borda esquerda como uma lista, com o comprimento de cada rótulo livre à direita.
    private var isLeadingAligned: Bool = false
    private let spinCancellationTrigger: Int

    public func leadingAligned(_ enabled: Bool = true) -> FrilaLPEWheelColumn {
        var copy = self
        copy.isLeadingAligned = enabled
        return copy
    }

    /// Chamado a cada linha que cruza a faixa central durante o arrasto, antes de a roleta assentar.
    /// Permite que uma lista paralela (Função) acompanhe a linha em foco (Categoria) ao vivo.
    private var highlightHandler: ((FrilaLPEWheelItem) -> Void)? = nil

    public func onHighlight(_ handler: @escaping (FrilaLPEWheelItem) -> Void) -> FrilaLPEWheelColumn {
        var copy = self
        copy.highlightHandler = handler
        return copy
    }

    /// Observa alterações no snapshot de escolha (para arbitragem por toque fora M20 / Q1).
    public func onSnapshot(_ handler: @escaping (FrilaLPEWheelSnapshot) -> Void) -> FrilaLPEWheelColumn {
        var copy = self
        copy.onSnapshotChange = handler
        return copy
    }

    /// Vincula o controlador externo de conclusão síncrona do giro por identidade de coluna (R3).
    func spinController(_ controller: FrilaLPEWheelSpinController?, columnID: String) -> FrilaLPEWheelColumn {
        var copy = self
        copy.spinController = controller
        copy.columnID = columnID
        return copy
    }

    /// Proveniência inicial do snapshot desta coluna (N1).
    private var initialProvenance: FrilaLPESnapshotProvenance = .visualSuggestion

    public func initialProvenance(_ provenance: FrilaLPESnapshotProvenance) -> FrilaLPEWheelColumn {
        var copy = self
        copy.initialProvenance = provenance
        return copy
    }

    /// Identidade estável do campo de entrada customizada (N3).
    private var explicitCustomInputFieldID: String? = nil
    @State private var defaultCustomInputFieldID: String = "wheel_custom_\(UUID().uuidString)"

    public func customInputFieldID(_ id: String) -> FrilaLPEWheelColumn {
        var copy = self
        copy.explicitCustomInputFieldID = id
        return copy
    }

    private var effectiveCustomInputFieldID: String {
        explicitCustomInputFieldID ?? defaultCustomInputFieldID
    }

    private var currentTotalHeight: CGFloat {
        rowHeight * CGFloat(Self.visibleRowsCount)
    }

    public init(
        title: String,
        items: [FrilaLPEWheelItem],
        selectedID: String? = nil,
        spinCancellationTrigger: Int = 0,
        isEditingCustom: Binding<Bool> = .constant(false),
        customText: Binding<String> = .constant(""),
        customPlaceholder: String = "Novo nome",
        duplicateSuggestion: FrilaLPERole? = nil,
        isDark: Bool = false,
        onCommit: @escaping (FrilaLPEWheelItem) -> Void = { _ in },
        onUseDuplicate: ((FrilaLPERole) -> Void)? = nil,
        onSubmitCustom: (() -> Void)? = nil,
        onCancelCustom: (() -> Void)? = nil,
        onSnapshotChange: ((FrilaLPEWheelSnapshot) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.selectedID = selectedID
        self.spinCancellationTrigger = spinCancellationTrigger
        self._isEditingCustom = isEditingCustom
        self._customText = customText
        self.customPlaceholder = customPlaceholder
        self.duplicateSuggestion = duplicateSuggestion
        self.isDark = isDark
        self.onCommit = onCommit
        self.onUseDuplicate = onUseDuplicate
        self.onSubmitCustom = onSubmitCustom
        self.onCancelCustom = onCancelCustom
        self.onSnapshotChange = onSnapshotChange
    }

    public init(
        title: String,
        items: [FrilaLPEWheelItem],
        selectedID: Binding<String?>,
        spinCancellationTrigger: Int = 0,
        isEditingCustom: Binding<Bool> = .constant(false),
        customText: Binding<String> = .constant(""),
        customPlaceholder: String = "Novo nome",
        duplicateSuggestion: FrilaLPERole? = nil,
        isDark: Bool = false,
        onCommit: @escaping (FrilaLPEWheelItem) -> Void = { _ in },
        onUseDuplicate: ((FrilaLPERole) -> Void)? = nil,
        onSubmitCustom: (() -> Void)? = nil,
        onCancelCustom: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            items: items,
            selectedID: selectedID.wrappedValue,
            spinCancellationTrigger: spinCancellationTrigger,
            isEditingCustom: isEditingCustom,
            customText: customText,
            customPlaceholder: customPlaceholder,
            duplicateSuggestion: duplicateSuggestion,
            isDark: isDark,
            onCommit: { item in
                selectedID.wrappedValue = item.id
                onCommit(item)
            },
            onUseDuplicate: onUseDuplicate,
            onSubmitCustom: onSubmitCustom,
            onCancelCustom: onCancelCustom
        )
    }

    public var body: some View {
        ZStack {
            if isEditingCustom {
                inlineCustomInputView
            } else {
                scrollWheelView
            }
        }
        .frame(height: currentTotalHeight)
        .modifier(FrilaLPEWheelChrome(isActive: showsChrome, radius: outerRadius, isDark: isDark))
        .sensoryFeedback(.selection, trigger: sensoryTriggerIndex)
        .accessibilityElement(children: isEditingCustom ? .contain : .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityCurrentValue)
        .accessibilityAdjustableAction { direction in
            handleAccessibilityAdjust(direction: direction)
        }
        .accessibilityAction(named: "Nova \(title.lowercased())") {
            isEditingCustom = true
        }
        .onAppear {
            spinSession.items = items
            spinSession.rowHeight = rowHeight
            spinSession.onCommit = onCommit
            spinSession.onActionTapped = { isEditingCustom = true }
            spinSession.onSnapshotChange = onSnapshotChange
            let prov: FrilaLPESnapshotProvenance = (initialProvenance == .confirmed && selectedID != nil) ? .confirmed : initialProvenance
            spinSession.currentProvenance = prov
            if let controller = spinController {
                lastObservedConclusionRevision = controller.conclusionRevision
                if let id = columnID {
                    controller.register(columnID: id) { [weak spinSession] in
                        spinSession?.concludeSpin() ?? FrilaLPEWheelSnapshot(eligibleItem: nil, isMoving: false, targetIndex: 0, spinID: nil, provenance: .visualSuggestion)
                    }
                }
            }
            spinSession.syncOffsetWithSelectedID(selectedID: selectedID, animated: false, reduceMotion: reduceMotion, provenanceOverride: prov)
            hasAppeared = true
        }
        .onDisappear {
            if let controller = spinController, let id = columnID {
                controller.unregister(columnID: id)
            }
            spinSession.currentSpinID = nil
        }
        .onChange(of: selectedID) { _, newID in
            spinSession.items = items
            let currentRevision = spinController?.conclusionRevision ?? 0
            let isSuppressedByConclusion = currentRevision > lastObservedConclusionRevision
            if isSuppressedByConclusion {
                lastObservedConclusionRevision = currentRevision
            }
            let shouldAnimate = hasAppeared && !isSuppressedByConclusion
            let prov: FrilaLPESnapshotProvenance = (newID != nil && initialProvenance == .confirmed) ? .confirmed : .visualSuggestion
            spinSession.syncOffsetWithSelectedID(
                selectedID: newID,
                animated: shouldAnimate,
                reduceMotion: reduceMotion,
                provenanceOverride: prov
            )
        }
        .onChange(of: items) { _, newItems in
            spinSession.items = newItems
            spinSession.currentSpinID = nil
            // Mudanças de lista não fabricam intenção (N1): preserva a proveniência corrente
            let currentRevision = spinController?.conclusionRevision ?? 0
            let isSuppressedByConclusion = currentRevision > lastObservedConclusionRevision
            if isSuppressedByConclusion {
                lastObservedConclusionRevision = currentRevision
            }
            let shouldAnimate = hasAppeared && !isSuppressedByConclusion
            spinSession.syncOffsetWithSelectedID(
                selectedID: selectedID,
                animated: shouldAnimate,
                reduceMotion: reduceMotion,
                provenanceOverride: spinSession.currentProvenance
            )
            startSpawnCascade(in: newItems)
        }
    }

    // MARK: - Raio

    /// Sem faixa aninhada, a roleta é uma superfície única: o raio acompanha a folha (24 pt)
    /// e não o campo de texto (14 pt), porque o container aberto tem 150 pt de altura.
    private var outerRadius: CGFloat {
        FrilaLPEGeometry.radiusSheet
    }

    /// Padding interno das linhas, igual ao do campo fechado, para o texto não pular ao abrir.
    private var bandHorizontalPadding: CGFloat {
        FrilaLPEGeometry.space6
    }

    // MARK: - Motor da Roleta com Destaque por Máscara de Duas Camadas

    /// Recorte da linha central. Sem caixa desenhada: a seleção é só tipográfica
    /// (semibold + cor da marca), recortada no quadro exato em que o item cruza o centro.
    private var centerLineMask: some View {
        Rectangle().frame(height: rowHeight)
    }

    /// Máscara de margens com rampa suavizada (smoothstep em vários pontos): sem a quina de um
    /// gradiente linear de dois pontos, a dissolução acontece como luz difusa, no estilo Liquid Glass.
    private func softEdgeMask(fadeLength: CGFloat) -> some View {
        let steps = 10
        var stops: [Gradient.Stop] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let eased = t * t * (3 - 2 * t)
            let location = Double(fadeLength) * t
            stops.append(.init(color: .black.opacity(eased), location: location))
        }
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let eased = t * t * (3 - 2 * t)
            let location = 1 - Double(fadeLength) * t
            stops.append(.init(color: .black.opacity(eased), location: location))
        }
        stops.sort { $0.location < $1.location }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private var scrollWheelView: some View {
        ZStack {
            // Camada A: texto regular em projeção cilíndrica, com desfoque contínuo por linha e
            // dissolução suave nas margens superior e inferior, vazada na linha central.
            itemsListView(isHighlighted: false)
                .mask {
                    ZStack {
                        softEdgeMask(fadeLength: 0.34)
                        centerLineMask.blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }

            // Camada B: texto destacado, visível só na linha central
            itemsListView(isHighlighted: true)
                .mask { centerLineMask }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !spinSession.isDragging {
                    spinSession.isDragging = true
                    spinSession.currentSpinID = nil
                    spinSession.dragStartOffset = spinSession.offset
                    spinSession.currentProvenance = .explicitInteraction
                }
                let raw = spinSession.dragStartOffset - value.translation.height
                let maxOffset = max(0, CGFloat(items.count - 1) * rowHeight)
                spinSession.offset = FrilaLPEWheelPhysics.rubberBand(offset: raw, maxOffset: maxOffset, dimension: currentTotalHeight)

                let currentIdx = FrilaLPEWheelPhysics.indexUnderBand(offset: spinSession.offset, rowHeight: rowHeight, itemCount: items.count)
                if currentIdx != sensoryTriggerIndex {
                    sensoryTriggerIndex = currentIdx
                    if items.indices.contains(currentIdx) {
                        highlightHandler?(items[currentIdx])
                    }
                }
                let currentItem = items.indices.contains(currentIdx) ? items[currentIdx] : nil
                let snapshot = FrilaLPEWheelSnapshot(eligibleItem: currentItem, isMoving: true, targetIndex: currentIdx, spinID: nil, provenance: .explicitInteraction)
                spinSession.currentSnapshot = snapshot
                onSnapshotChange?(snapshot)
            }
            .onEnded { value in
                spinSession.isDragging = false

                // Verificação de Toque sintético ou deliberado
                let isTap = abs(value.translation.height) < 5 && abs(value.translation.width) < 5
                if isTap {
                    let halfHeight = currentTotalHeight / 2.0
                    let projected = value.location.y - halfHeight
                    let linear = reduceMotion
                        ? projected
                        : CGFloat(FrilaLPEWheelPerspective.delta(forProjected: Double(projected), halfHeight: Double(halfHeight)))
                    let tappedIndex = Int(((linear + spinSession.offset) / rowHeight).rounded())
                    if items.indices.contains(tappedIndex) {
                        itemTapped(at: tappedIndex)
                        return
                    }
                }

                // Snap por inércia
                let targetIdx: Int
                let finalOffset: CGFloat
                let springVelocity: Double

                if reduceMotion {
                    targetIdx = FrilaLPEWheelPhysics.targetIndex(projectedOffset: spinSession.offset, rowHeight: rowHeight, itemCount: items.count)
                    finalOffset = FrilaLPEWheelPhysics.targetOffset(targetIndex: targetIdx, rowHeight: rowHeight)
                    springVelocity = 0
                } else {
                    let projected = FrilaLPEWheelPhysics.projectedOffset(currentOffset: spinSession.offset, velocityY: value.velocity.height)
                    targetIdx = FrilaLPEWheelPhysics.targetIndex(projectedOffset: projected, rowHeight: rowHeight, itemCount: items.count)
                    finalOffset = FrilaLPEWheelPhysics.targetOffset(targetIndex: targetIdx, rowHeight: rowHeight)
                    springVelocity = FrilaLPEWheelPhysics.initialSpringVelocity(velocityY: value.velocity.height, currentOffset: spinSession.offset, targetOffset: finalOffset)
                }

                if targetIdx != sensoryTriggerIndex {
                    sensoryTriggerIndex = targetIdx
                }

                let targetItem = items.indices.contains(targetIdx) ? items[targetIdx] : nil
                _ = spinSession.startSpin(
                    targetIndex: targetIdx,
                    targetOffset: finalOffset,
                    targetItem: targetItem,
                    springVelocity: springVelocity,
                    reduceMotion: reduceMotion
                )
            }
    }

    // MARK: - Renderização da Lista de Itens

    private func itemsListView(isHighlighted: Bool) -> some View {
        let halfHeight = currentTotalHeight / 2.0

        return ZStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let delta = CGFloat(index) * rowHeight - spinSession.offset
                if abs(delta) < currentTotalHeight {
                    let projected = reduceMotion
                        ? delta
                        : CGFloat(FrilaLPEWheelPerspective.projectedDelta(delta: Double(delta), halfHeight: Double(halfHeight)))
                    wheelRow(item: item, index: index, delta: delta, isHighlighted: isHighlighted)
                        .offset(y: halfHeight + projected - rowHeight / 2.0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func wheelRow(item: FrilaLPEWheelItem, index: Int, delta: CGFloat, isHighlighted: Bool) -> some View {
        let n = FrilaLPEWheelPerspective.normalized(delta: Double(delta), halfHeight: Double(currentTotalHeight / 2.0))
        let flat = isHighlighted || reduceMotion
        let tilt = flat ? 0.0 : FrilaLPEWheelPerspective.angle(normalized: n)
        let scale: CGFloat = flat ? 1.0 : CGFloat(FrilaLPEWheelPerspective.scale(normalized: n))
        let opacity: Double = flat ? 1.0 : FrilaLPEWheelPerspective.opacity(normalized: n)
        let blur: CGFloat = flat ? 0 : CGFloat(FrilaLPEWheelPerspective.blurRadius(normalized: n))

        HStack(spacing: FrilaLPEGeometry.space6) {
            rowContent(item: item, isHighlighted: isHighlighted)
        }
        .frilaLPEPendingText(
            isActive: isPending && !item.isNeutral && !item.isAction,
            phaseOffset: Double(delta / rowHeight) * -0.09,
            isDark: isDark
        )
        .frilaLPESpawnCascade(
            start: spawnStart,
            distance: FrilaLPESpawnCascade.distance(row: index, origin: spawnOrigin),
            isDark: isDark
        )
        .padding(.horizontal, isLeadingAligned ? FrilaLPEGeometry.space14 : bandHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: isLeadingAligned ? .leading : .center)
        .frame(height: rowHeight)
        .blur(radius: blur)
        // Alinhado à esquerda, a escala de profundidade parte da margem: a borda do texto fica fixa
        .scaleEffect(scale, anchor: isLeadingAligned ? .leading : .center)
        .rotation3DEffect(.radians(-tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .opacity(opacity)
    }

    @ViewBuilder
    private func rowContent(item: FrilaLPEWheelItem, isHighlighted: Bool) -> some View {
        if item.isNeutral {
            Capsule()
                .fill(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark).opacity(0.45))
                .frame(width: 28, height: 4)
                .accessibilityHidden(true)
        } else {
            if let iconName = item.iconName {
                Image(systemName: iconName)
                    .font(isHighlighted ? FrilaLPETypography.captionBold : FrilaLPETypography.caption)
                    .foregroundColor(iconColor(for: item, isHighlighted: isHighlighted))
            }

            Text(verbatim: item.title)
                .font(isHighlighted ? FrilaLPETypography.bodyBold : FrilaLPETypography.body)
                .foregroundColor(textColor(for: item, isHighlighted: isHighlighted))
                .lineLimit(1)
                .multilineTextAlignment(isLeadingAligned ? .leading : .center)
                .truncationMode(.tail)

            if let subtitle = item.subtitle {
                Text(verbatim: subtitle)
                    .font(FrilaLPETypography.caption)
                    .foregroundColor(isHighlighted ? FrilaLPEColor.dynamicBrandText(isDark: isDark) : FrilaLPEColor.dynamicTextMuted(isDark: isDark))
            }
        }
    }

    private func textColor(for item: FrilaLPEWheelItem, isHighlighted: Bool) -> Color {
        if !item.isSelectable {
            return FrilaLPEColor.dynamicTextMuted(isDark: isDark)
        }
        // A cor da marca é o sinal de seleção: fora do centro, nem a ação "Nova" usa laranja,
        // senão ela parece selecionada.
        if isHighlighted {
            return FrilaLPEColor.dynamicBrandText(isDark: isDark)
        }
        return FrilaLPEColor.dynamicTextPrimary(isDark: isDark)
    }

    private func iconColor(for item: FrilaLPEWheelItem, isHighlighted: Bool) -> Color {
        isHighlighted ? FrilaLPEColor.dynamicBrandText(isDark: isDark) : FrilaLPEColor.dynamicTextMuted(isDark: isDark)
    }

    // MARK: - Modo de Digitação Direta (Adicionar Item)

    /// Respiro do formulário dentro do container aberto. O campo interno tem raio concêntrico:
    /// R_campo = R_container (24) − respiro (12) = 12.
    private var addFormPadding: CGFloat { FrilaLPEGeometry.space12 }

    private var isCustomTextValid: Bool {
        customText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    /// Formulário de adição no padrão mobile: um campo de texto de verdade (superfície, borda e raio
    /// concêntrico), teclado com Concluir, e as duas ações como par de pílulas de mesma altura e
    /// largura. Nada de ícone decorativo, check solto ou texto como botão.
    private var inlineCustomInputView: some View {
        let fieldRadius = FrilaLPEGeometry.concentricInnerRadius(outerRadius: outerRadius, padding: addFormPadding)
        let duplicate = duplicateSuggestion

        return VStack(spacing: FrilaLPEGeometry.space8) {
            HStack(spacing: FrilaLPEGeometry.space4) {
                TextField(customPlaceholder, text: $customText)
                    .frilaLPEType(FrilaLPEFormType.input, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .focused($isCustomFieldFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .onSubmit { onSubmitCustom?() }
                    .accessibilityLabel(customPlaceholder)
                    .frilaLPEFormField(id: effectiveCustomInputFieldID, isFocused: isCustomFieldFocused, onDismiss: { isCustomFieldFocused = false })

                if !customText.isEmpty {
                    Button(action: { customText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(FrilaLPETypography.bodyBold)
                            .foregroundColor(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                    }
                    .buttonStyle(.plain)
                    .frilaLPEHitbox()
                    .accessibilityLabel(String(localized: "Limpar texto", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
                }
            }
            .padding(.leading, FrilaLPEGeometry.space12)
            .padding(.trailing, customText.isEmpty ? FrilaLPEGeometry.space12 : FrilaLPEGeometry.space4)
            .frame(height: FrilaLPEGeometry.buttonHeightStandard)
            .background(FrilaLPEColor.dynamicCanvas(isDark: isDark), in: RoundedRectangle(cornerRadius: fieldRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: fieldRadius, style: .continuous)
                    .strokeBorder(
                        isCustomFieldFocused ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark),
                        lineWidth: isCustomFieldFocused ? 1.5 : 1
                    )
            }

            if let duplicate {
                Text("\(duplicate.name) já existe no catálogo.", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.caption)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, FrilaLPEGeometry.space4)
            }

            HStack(spacing: FrilaLPEGeometry.space8) {
                Button {
                    isEditingCustom = false
                    customText = ""
                    onCancelCustom?()
                } label: {
                    Text("Cancelar", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao).frame(maxWidth: .infinity)
                }
                .buttonStyle(FrilaLPEPillButtonStyle(variant: .outline, isDark: isDark))

                if let duplicate {
                    Button { onUseDuplicate?(duplicate) } label: {
                        Text("Usar \(duplicate.name)", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FrilaLPEPillButtonStyle(variant: .primary, isDark: isDark))
                } else {
                    Button { onSubmitCustom?() } label: {
                        Text("Adicionar", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FrilaLPEPillButtonStyle(variant: .primary, isDark: isDark))
                        .disabled(!isCustomTextValid)
                        .opacity(isCustomTextValid ? 1 : 0.4)
                }
            }
            .frame(height: FrilaLPEGeometry.buttonHeightStandard)
        }
        .padding(.horizontal, addFormPadding)
        .padding(.vertical, FrilaLPEGeometry.space8)
        .onAppear {
            isCustomFieldFocused = true
        }
    }

    // MARK: - Ações de Interação e Navegação

    private func itemTapped(at index: Int) {
        guard items.indices.contains(index) else { return }
        spinSession.currentProvenance = .explicitInteraction
        let item = items[index]
        let currentCenterIndex = FrilaLPEWheelPhysics.indexUnderBand(offset: spinSession.offset, rowHeight: rowHeight, itemCount: items.count)

        if currentCenterIndex == index {
            if item.isAction {
                isEditingCustom = true
            } else {
                spinSession.commitTarget(item: item)
                let snapshot = FrilaLPEWheelSnapshot(eligibleItem: item, isMoving: false, targetIndex: index, spinID: nil, provenance: .explicitInteraction)
                spinSession.currentSnapshot = snapshot
                onSnapshotChange?(snapshot)
            }
        } else {
            let finalOffset = FrilaLPEWheelPhysics.targetOffset(targetIndex: index, rowHeight: rowHeight)
            if index != sensoryTriggerIndex {
                sensoryTriggerIndex = index
            }
            _ = spinSession.startSpin(
                targetIndex: index,
                targetOffset: finalOffset,
                targetItem: item,
                springVelocity: 0,
                reduceMotion: reduceMotion
            )
        }
    }

    /// Dispara o nascimento em cascata a partir da linha selecionada, só quando a lista de fato muda de conteúdo.
    private func startSpawnCascade(in newItems: [FrilaLPEWheelItem]) {
        guard hasAppeared, !reduceMotion else { return }
        spawnOrigin = newItems.firstIndex(where: { $0.id == selectedID }) ?? 0
        spawnStart = Date()
        spawnTask?.cancel()
        spawnTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaLPESpawnCascade.totalDuration + 0.1))
            guard !Task.isCancelled else { return }
            spawnStart = nil
        }
    }

    private var accessibilityCurrentValue: String {
        let idx = FrilaLPEWheelPhysics.indexUnderBand(offset: spinSession.offset, rowHeight: rowHeight, itemCount: items.count)
        if items.indices.contains(idx) {
            return items[idx].title
        }
        return "Nenhum selecionado"
    }

    private func handleAccessibilityAdjust(direction: AccessibilityAdjustmentDirection) {
        guard !items.isEmpty else { return }
        spinSession.currentProvenance = .explicitInteraction
        let currentIdx = FrilaLPEWheelPhysics.indexUnderBand(offset: spinSession.offset, rowHeight: rowHeight, itemCount: items.count)
        let nextIdx: Int
        switch direction {
        case .increment:
            nextIdx = min(items.count - 1, currentIdx + 1)
        case .decrement:
            nextIdx = max(0, currentIdx - 1)
        @unknown default:
            return
        }

        let finalOffset = FrilaLPEWheelPhysics.targetOffset(targetIndex: nextIdx, rowHeight: rowHeight)
        spinSession.offset = finalOffset
        sensoryTriggerIndex = nextIdx
        let item = items.indices.contains(nextIdx) ? items[nextIdx] : nil
        spinSession.commitTarget(item: item)
        let snapshot = FrilaLPEWheelSnapshot(eligibleItem: item, isMoving: false, targetIndex: nextIdx, spinID: nil, provenance: .explicitInteraction)
        spinSession.currentSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }
}

// MARK: - Controlador e Sessão de Giro Síncrono (R3)

/// Controlador externo de conclusão síncrona do giro das colunas da roleta (R3).
@Observable
@MainActor
final class FrilaLPEWheelSpinController {
    typealias ConcludeOperation = @MainActor () -> FrilaLPEWheelSnapshot

    private var operations: [String: ConcludeOperation] = [:]
    private(set) var conclusionRevision: Int = 0

    init() {}

    func register(columnID: String, operation: @escaping ConcludeOperation) {
        operations[columnID] = operation
    }

    func unregister(columnID: String) {
        operations.removeValue(forKey: columnID)
    }

    @discardableResult
    func concludeSpin(columnID: String) -> FrilaLPEWheelSnapshot? {
        conclusionRevision += 1
        return operations[columnID]?()
    }

    func concludeAll(columnIDs: [String]) -> [String: FrilaLPEWheelSnapshot] {
        conclusionRevision += 1
        var snapshots: [String: FrilaLPEWheelSnapshot] = [:]
        for id in columnIDs {
            if let snap = operations[id]?() {
                snapshots[id] = snap
            }
        }
        return snapshots
    }
}

/// Estado interno e sessão do giro/inércia de uma coluna, com suporte a conclusão síncrona sem animação (R3).
@Observable
@MainActor
final class FrilaLPEWheelSpinSession {
    var offset: CGFloat = 0.0
    var currentSpinID: UUID? = nil
    var pendingTargetIndex: Int? = nil
    var pendingTargetOffset: CGFloat? = nil
    var pendingTargetItem: FrilaLPEWheelItem? = nil
    var lastCommittedID: String? = nil
    var isDragging: Bool = false
    var dragStartOffset: CGFloat = 0.0
    var currentSnapshot: FrilaLPEWheelSnapshot? = nil
    var currentProvenance: FrilaLPESnapshotProvenance = .visualSuggestion

    var items: [FrilaLPEWheelItem] = []
    var rowHeight: CGFloat = FrilaLPEWheelColumn.rowHeight
    var onCommit: ((FrilaLPEWheelItem) -> Void)? = nil
    var onActionTapped: (() -> Void)? = nil
    var onSnapshotChange: ((FrilaLPEWheelSnapshot) -> Void)? = nil

    init() {}

    func startSpin(
        targetIndex: Int,
        targetOffset: CGFloat,
        targetItem: FrilaLPEWheelItem?,
        springVelocity: Double = 0,
        reduceMotion: Bool = false
    ) -> UUID {
        let spinID = UUID()
        self.currentSpinID = spinID
        self.pendingTargetIndex = targetIndex
        self.pendingTargetOffset = targetOffset
        self.pendingTargetItem = targetItem
        self.currentProvenance = .explicitInteraction

        let movingSnapshot = FrilaLPEWheelSnapshot(eligibleItem: targetItem, isMoving: true, targetIndex: targetIndex, spinID: spinID, provenance: .explicitInteraction)
        self.currentSnapshot = movingSnapshot
        onSnapshotChange?(movingSnapshot)

        if reduceMotion {
            self.offset = targetOffset
            commitTarget(item: targetItem)
            self.currentSpinID = nil
            self.pendingTargetIndex = nil
            self.pendingTargetOffset = nil
            self.pendingTargetItem = nil
            let settledSnapshot = FrilaLPEWheelSnapshot(eligibleItem: targetItem, isMoving: false, targetIndex: targetIndex, spinID: nil, provenance: .explicitInteraction)
            self.currentSnapshot = settledSnapshot
            onSnapshotChange?(settledSnapshot)
        } else {
            let spring = Animation.interpolatingSpring(
                stiffness: FrilaLPEWheelPhysics.springStiffness,
                damping: FrilaLPEWheelPhysics.springDamping,
                initialVelocity: springVelocity
            )
            var isStartingSpin = true
            defer { isStartingSpin = false }

            withAnimation(FrilaMovimento.animacao(spring, reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                self.offset = targetOffset
            } completion: { [weak self] in
                guard let self = self, self.currentSpinID == spinID else { return }
                let finishSettle = {
                    guard self.currentSpinID == spinID else { return }
                    self.currentSpinID = nil
                    self.pendingTargetIndex = nil
                    self.pendingTargetOffset = nil
                    self.pendingTargetItem = nil
                    self.commitTarget(item: targetItem)
                    let settledSnapshot = FrilaLPEWheelSnapshot(eligibleItem: targetItem, isMoving: false, targetIndex: targetIndex, spinID: nil, provenance: .explicitInteraction)
                    self.currentSnapshot = settledSnapshot
                    self.onSnapshotChange?(settledSnapshot)
                }

                if isStartingSpin {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        finishSettle()
                    }
                } else {
                    finishSettle()
                }
            }
        }
        return spinID
    }

    @discardableResult
    func concludeSpin() -> FrilaLPEWheelSnapshot {
        if currentSpinID != nil {
            // R3: Captura o snapshot/destino calculado ao soltar, invalida o spinID e aplica o offset sem animação
            currentSpinID = nil

            let finalOffset = pendingTargetOffset ?? offset
            let finalItem = pendingTargetItem
            let finalIdx = pendingTargetIndex ?? FrilaLPEWheelPhysics.indexUnderBand(offset: finalOffset, rowHeight: rowHeight, itemCount: items.count)

            pendingTargetIndex = nil
            pendingTargetOffset = nil
            pendingTargetItem = nil

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.offset = finalOffset
            }

            // Exclusividade de conclusão: NÃO chama commitTarget ou handlers intermediários aqui.
            // O componente dono (coordenador) aplica o resultado uma única vez.
            let snapshot = FrilaLPEWheelSnapshot(eligibleItem: finalItem, isMoving: false, targetIndex: finalIdx, spinID: nil, provenance: currentProvenance)
            currentSnapshot = snapshot
            onSnapshotChange?(snapshot)
            return snapshot
        } else {
            let currentIdx = FrilaLPEWheelPhysics.indexUnderBand(offset: offset, rowHeight: rowHeight, itemCount: items.count)
            let currentItem = items.indices.contains(currentIdx) ? items[currentIdx] : nil
            let snapshot = FrilaLPEWheelSnapshot(eligibleItem: currentItem, isMoving: false, targetIndex: currentIdx, spinID: nil, provenance: currentProvenance)
            currentSnapshot = snapshot
            return snapshot
        }
    }

    func commitTarget(item: FrilaLPEWheelItem?) {
        guard let item, items.contains(where: { $0.id == item.id }) else { return }

        if item.isAction {
            onActionTapped?()
            return
        }

        if !item.isSelectable {
            if lastCommittedID != item.id {
                lastCommittedID = item.id
                onCommit?(item)
            }
            return
        }

        lastCommittedID = item.id
        onCommit?(item)
    }

    public func syncOffsetWithSelectedID(
        selectedID: String?,
        animated: Bool,
        reduceMotion: Bool,
        provenanceOverride: FrilaLPESnapshotProvenance? = nil
    ) {
        guard !isDragging else { return }

        if let provenanceOverride {
            self.currentProvenance = provenanceOverride
        } else if selectedID != nil {
            self.currentProvenance = .confirmed
        } else {
            self.currentProvenance = .visualSuggestion
        }

        let targetIndex: Int
        if let selectedID, let idx = items.firstIndex(where: { $0.id == selectedID }) {
            targetIndex = idx
        } else {
            targetIndex = 0
        }
        let targetOffset = FrilaLPEWheelPhysics.targetOffset(targetIndex: targetIndex, rowHeight: rowHeight)

        if animated && !reduceMotion {
            let spring = Animation.interpolatingSpring(
                stiffness: FrilaLPEWheelPhysics.springStiffness,
                damping: FrilaLPEWheelPhysics.springDamping
            )
            withAnimation(FrilaMovimento.animacao(spring, reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                self.offset = targetOffset
            }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.offset = targetOffset
            }
        }
        let targetItem = items.indices.contains(targetIndex) ? items[targetIndex] : nil
        let snapshot = FrilaLPEWheelSnapshot(eligibleItem: targetItem, isMoving: false, targetIndex: targetIndex, spinID: nil, provenance: self.currentProvenance)
        self.currentSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }
}


private struct FrilaLPEWheelChrome: ViewModifier {
    let isActive: Bool
    let radius: CGFloat
    let isDark: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .background(FrilaLPEColor.dynamicFormFieldSurface(isDark: isDark))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark), lineWidth: 1)
                }
                .frilaLPEFormLift(isDark: isDark)
        } else {
            content
        }
    }
}
