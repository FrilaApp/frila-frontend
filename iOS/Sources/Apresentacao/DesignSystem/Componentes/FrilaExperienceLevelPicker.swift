import SwiftUI

// MARK: - Modelo dos níveis

/// Nível de experiência pedido para a vaga. Os quatro níveis formam uma escada: cada degrau exige
/// mais do profissional que o anterior, então o seletor mostra ordem e esforço, não quatro opções iguais.
public struct FrilaExperienceLevel: Identifiable, Equatable, Sendable {
    /// Valor gravado na vaga (`FrilaJobCreationDraft.seniority`).
    public let title: String
    /// Frase curta que diz o que o nível pede, no registro de placa de museu.
    public let detail: String
    /// Posição na escada, de 1 (aberto a todos) a `FrilaExperienceLevel.catalog.count`.
    public let rank: Int

    public var id: String { title }

    public static let catalog: [FrilaExperienceLevel] = [
        FrilaExperienceLevel(title: "Qualquer Experiência", detail: "Aceita quem está começando", rank: 1),
        FrilaExperienceLevel(title: "Iniciante / Prático", detail: "Já fez o serviço algumas vezes", rank: 2),
        FrilaExperienceLevel(title: "Intermediário", detail: "Trabalha sozinho, com pouca orientação", rank: 3),
        FrilaExperienceLevel(title: "Especialista", detail: "Domina a função e orienta os outros", rank: 4)
    ]

    public static func level(titled title: String) -> FrilaExperienceLevel? {
        catalog.first { $0.title == title }
    }

    /// Texto falado: ordem na escada e o que o nível pede.
    var spokenDescription: String {
        "\(title), nível \(rank) de \(Self.catalog.count). \(detail)"
    }
}

// MARK: - Estilo de seleção em lista

/// Como o texto da linha escolhida responde à camada de seleção que desliza.
public enum FrilaListSelectionStyle: String, CaseIterable, Sendable {
    /// A escolha em Bricolage Bold e as demais em Regular. A troca de peso esmaece as duas versões
    /// com desfoque leve (o desfoque funde as larguras diferentes, sem texto duplicado nítido).
    case softWeight
    /// A mesma camada cinza clara, e o peso trocado por máscara: o texto Regular fica por baixo e uma cópia
    /// em Bold, recortada pela camada, desliza com ela. A troca de peso acontece na borda da camada, sem
    /// esmaecer nem duplicar (a técnica de duas camadas da roleta). Uma primeira versão com camada escura e
    /// texto invertido foi descartada: carga visual nova e pesada, abrupta na linearidade do formulário.
    case weightMask

    public var label: String {
        switch self {
        case .softWeight: return "Peso suave"
        case .weightMask: return "Máscara de peso"
        }
    }
}

// MARK: - Seletor

/// Seletor de experiência desejada em lista recolhível. Fork do seletor de chips: a escolha é ordinal,
/// então aberto cada nível ocupa uma linha de largura total, em ordem crescente de cima para baixo, com o
/// nome e o que ele pede. A hierarquia vem da ordem e do texto, sem glifo (M11 em `RULES.md`).
///
/// Ciclo, no padrão de minimalismo por recolhimento do Frila:
/// - Recolhido (padrão): uma linha só com o nível escolhido e um chevron. Tocar abre a lista.
/// - Abrir e fechar usam o mesmo movimento dos campos de categoria e função: a mola de disclosure, o
///   assentamento para baixo e a troca de conteúdo escalonada.
/// - Aberto: a linha escolhida tem a cor do campo do grupo (um degrau acima do fundo), não a cor da marca, e o nome em
///   Bricolage Bold; as demais ficam em Bricolage Regular (ou a máscara de peso, ver
///   `FrilaListSelectionStyle`). A camada é uma só, atrás da lista inteira, e desliza na vertical até a
///   linha escolhida com a mola `selectionWashSlide`. Uma camada por linha passava por cima do texto das
///   linhas do meio durante o deslize. Não há check durante a escolha.
/// - A escolha é a conclusão: um toque numa linha, ou soltar o dedo depois de um deslize, grava o valor e
///   recolhe a lista na mesma transação (sem timer, sem segundo toque para aceitar). O chevron do campo
///   recolhido vira um check por um instante e volta (troca nativa de SF Symbol). Tocar no nível já
///   escolhido só recolhe.
/// - Deslize: segurar uma linha por `FrilaMotion.selectionSlideHoldDuration` faz a camada passar a seguir
///   o dedo, saltando de linha em linha com um tique de háptico por linha. Soltar confirma a linha sob o
///   dedo. Um arrasto vertical mais rápido que a espera rola a página; o gesto cancelado pelo sistema
///   não escolhe nada (o destaque fica na última linha até o próximo toque). VoiceOver usa as linhas
///   como botões, sem depender do deslize.
public struct FrilaExperienceLevelPicker: View {
    @Binding public var selection: String
    public let isDark: Bool
    public let levels: [FrilaExperienceLevel]
    /// Mesma paleta do grupo de Categoria e Função: fundo do grupo, linha escolhida na cor do campo.
    public let palette: FrilaPickerGroupStyle
    public let selectionStyle: FrilaListSelectionStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.frilaOutsideTapCoordinator) private var outsideTapCoordinator
    private let outsideTapAnchorID = "frila_experience_level_picker"
    @State private var isExpanded: Bool = false
    /// Verdadeiro por um instante depois de recolher com uma escolha nova: o chevron vira check.
    @State private var showsConclusion: Bool = false
    @State private var conclusionTask: Task<Void, Never>?
    /// Linha sob o dedo durante o deslize; nil fora dele. Só a escolha de verdade grava em `selection`.
    /// Limpa em `choose`, na mesma transação (`withAnimation`) que grava `selection` e recolhe, e ao abrir a
    /// lista; nunca ao soltar o dedo. Escrito fora dessa transação, o SwiftUI renderizava um passe com
    /// `slideTitle` nil e `selection`/`isExpanded` ainda antigos, e a camada pulava um quadro à escolha antiga.
    @State private var slideTitle: String?
    /// Retângulos das linhas no espaço da lista, para achar a linha sob o dedo.
    @State private var rowFrames: [String: CGRect] = [:]
    private static let listSpace = "FrilaExperienceLevelPicker.list"

    public init(
        selection: Binding<String>,
        isDark: Bool = false,
        levels: [FrilaExperienceLevel] = FrilaExperienceLevel.catalog,
        palette: FrilaPickerGroupStyle = .neutral,
        selectionStyle: FrilaListSelectionStyle = .softWeight
    ) {
        self.palette = palette
        self.selectionStyle = selectionStyle
        self._selection = selection
        self.isDark = isDark
        self.levels = levels
    }

    /// Linha escolhida: a cor do campo do grupo, um degrau acima do fundo (segregação suave), nos dois estilos.
    private var selectionFill: Color { palette.fieldFill(isDark: isDark) }

    /// A camada de seleção (preenchimento e filete), desenhada no lugar da linha escolhida.
    private func selectionLayer(_ rect: CGRect) -> some View {
        FrilaSelectionLayer(rect: rect, radius: rowRadius, fill: selectionFill, stroke: palette.fieldStroke(isDark: isDark))
    }

    /// Respiro horizontal do texto nas linhas: com o inset do cartão, o texto fica a 14 pt da borda,
    /// na mesma coluna dos campos de Categoria e Função e das linhas da roleta.
    private let rowTextPadding: CGFloat = FrilaGeometry.space10

    /// Raio externo do cartão e interno das linhas: R_linha = R_cartão − respiro (concêntrico).
    private let cardRadius: CGFloat = FrilaGeometry.radiusCard
    private let inset: CGFloat = FrilaGeometry.space4
    private var rowRadius: CGFloat { FrilaGeometry.concentricInnerRadius(outerRadius: cardRadius, padding: inset) }

    private var selectedLevel: FrilaExperienceLevel? { levels.first { $0.title == selection } }

    /// A linha em destaque: a que está sob o dedo no deslize, senão a escolha gravada.
    private var highlightedTitle: String { slideTitle ?? selection }

    public var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                ForEach(levels) { level in
                    row(level)
                        .frilaSelectionRow(id: level.id)
                        .transition(.frilaFieldContent)
                }
            } else {
                collapsedRow
                    .transition(.frilaFieldContent)
            }
        }
        // Camada única de seleção, atrás de todas as linhas: desliza sem cobrir texto de nenhuma
        .frilaSelectionLayerBackground(
            selectedID: highlightedTitle,
            isVisible: selectionStyle == .softWeight && isExpanded,
            radius: rowRadius,
            fill: selectionFill,
            stroke: palette.fieldStroke(isDark: isDark)
        )
        // Máscara de peso: por cima das linhas, a camada (que cobre o texto Regular dela) e uma cópia do
        // texto em Bold recortada pela camada. As duas usam o mesmo retângulo, então andam juntas.
        .overlayPreferenceValue(FrilaSelectionRowBoundsKey.self) { anchors in
            if selectionStyle == .weightMask, isExpanded, let anchor = anchors[highlightedTitle] {
                GeometryReader { proxy in
                    let rect = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        selectionLayer(rect)
                        VStack(spacing: 0) {
                            ForEach(levels) { level in
                                levelText(level, isEmphasized: true, forceWeight: true)
                                    .padding(.horizontal, rowTextPadding)
                                    .frame(minHeight: 60)
                            }
                        }
                        .frame(width: proxy.size.width, alignment: .top)
                        .mask(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.minX, y: rect.minY)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .coordinateSpace(name: Self.listSpace)
        .simultaneousGesture(slideGesture, including: isExpanded ? .all : .subviews)
        .padding(inset)
        .background(palette.fill(isDark: isDark), in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        // Mesma elevação do grupo de Categoria e Função
        .frilaGroupElevation(isDark: isDark, cornerRadius: cardRadius)
        .frilaDisclosureDrop(isOpen: isExpanded, reduceMotion: reduceMotion)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Experiência desejada", table: "Estudio", bundle: bundleApresentacao))
        .sensoryFeedback(.success, trigger: showsConclusion) { _, new in new }
        .sensoryFeedback(.selection, trigger: slideTitle) { _, new in new != nil }
        .onDisappear { conclusionTask?.cancel() }
        .frilaOutsideTap(id: outsideTapAnchorID, isOpen: isExpanded) {
            collapseOnOutsideTap()
        }
    }

    // MARK: - Toque Fora (M20 / R10)

    private func collapseOnOutsideTap() {
        guard isExpanded else { return }
        let cycleID = outsideTapCoordinator?.beginCollapse(id: outsideTapAnchorID)
        if reduceMotion {
            slideTitle = nil
            isExpanded = false
            outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: cycleID)
        } else {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.disclosureCollapse, reduzir: FrilaMovimentoReduzido.ativo), completionCriteria: .logicallyComplete) {
                slideTitle = nil
                isExpanded = false
            } completion: {
                outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: cycleID)
            }
        }
    }

    // MARK: Recolhido

    /// Só o conteúdo escolhido, sem estado de seleção: nome, o que pede e o chevron que abre a lista.
    private var collapsedRow: some View {
        Button(action: expand) {
            HStack(spacing: FrilaGeometry.space14) {
                levelText(selectedLevel ?? levels[0], isEmphasized: true, forceWeight: true)
                Image(systemName: showsConclusion ? "checkmark" : "chevron.down")
                    .font(FrilaFonteDoSistema.fonte(size: 13, weight: .semibold))
                    .foregroundColor(showsConclusion ? FrilaColor.dynamicBrandAccent(isDark: isDark) : FrilaColor.dynamicFormTextMuted(isDark: isDark))
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace.downUp))
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, rowTextPadding)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(FrilaPreselectionButtonStyle(radius: rowRadius, fill: palette.fieldFill(isDark: isDark), isSelected: false, reduceMotion: reduceMotion))
        .frilaHitbox()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Experiência desejada: \(selectedLevel?.spokenDescription ?? selection)", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityHint(String(localized: "Toque para ver os níveis", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Aberto

    private func row(_ level: FrilaExperienceLevel) -> some View {
        let isHighlighted = highlightedTitle == level.title
        let isSelected = selection == level.title

        return Button { choose(level) } label: {
            levelText(level, isEmphasized: isHighlighted)
                .padding(.horizontal, rowTextPadding)
                .frame(minHeight: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(FrilaPreselectionButtonStyle(radius: rowRadius, fill: palette.fieldFill(isDark: isDark), isSelected: isHighlighted, reduceMotion: reduceMotion, isDragging: slideTitle != nil))
        .frilaHitbox()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.listSpace)) } action: { rowFrames[level.id] = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.spokenDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Nome e o que o nível pede.
    /// - Peso suave: a escolha em Bricolage Bold, as demais em Regular. As duas versões ficam empilhadas e
    ///   esmaecem com desfoque leve (`selectionTextCrossfade`): a Bricolage não é variável, e um corte seco
    ///   de peso lia como duro; o desfoque funde as duas larguras no meio da troca.
    /// - Máscara de peso: as linhas ficam sempre em Regular; o Bold vem da cópia recortada pela camada.
    /// `forceWeight`: Bold fixo (campo recolhido e a cópia da máscara).
    private func levelText(_ level: FrilaExperienceLevel, isEmphasized: Bool, forceWeight: Bool = false) -> some View {
        let titleColor = FrilaColor.dynamicTextPrimary(isDark: isDark)
        return VStack(alignment: .leading, spacing: FrilaGeometry.space2) {
            if selectionStyle == .softWeight && !forceWeight {
                FrilaWeightCrossfadeTitle(text: level.title, isEmphasized: isEmphasized, color: titleColor)
            } else {
                Text(verbatim: level.title)
                    .frilaType(forceWeight ? FrilaFormType.answer : FrilaFormType.answerContext, dynamic: true)
                    .foregroundColor(titleColor)
            }
            // Tinta secundária, e não o cinza claro: segue em AA também sobre a camada
            Text(verbatim: level.detail)
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundColor(FrilaColor.dynamicInkSecondary(isDark: isDark))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Ações

    private func expand() {
        conclusionTask?.cancel()
        showsConclusion = false
        slideTitle = nil
        outsideTapCoordinator?.updateAnchorOpen(id: outsideTapAnchorID, isOpen: true)
        withAnimation(FrilaMovimento.animacao(FrilaMotion.disclosureExpand, reduzir: reduceMotion)) { isExpanded = true }
    }

    /// A escolha conclui: grava o valor e recolhe na mesma transação. Escolher o nível que já valia só recolhe.
    private func choose(_ level: FrilaExperienceLevel) {
        let isNewChoice = selection != level.title
        let cycleID = outsideTapCoordinator?.beginCollapse(id: outsideTapAnchorID)
        if reduceMotion {
            slideTitle = nil
            selection = level.title
            isExpanded = false
            outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: cycleID)
        } else {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.disclosureCollapse, reduzir: FrilaMovimentoReduzido.ativo), completionCriteria: .logicallyComplete) {
                slideTitle = nil
                selection = level.title
                isExpanded = false
            } completion: {
                outsideTapCoordinator?.endCollapse(id: outsideTapAnchorID, cycleID: cycleID)
            }
        }
        guard isNewChoice else { return }
        // Conclusão: o chevron vira check quando o campo assenta, e volta a ser chevron depois
        conclusionTask?.cancel()
        conclusionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(FrilaMotion.confirmCelebrationDelayMs))
            guard !Task.isCancelled else { return }
            showsConclusion = true
            try? await Task.sleep(for: .seconds(FrilaMotion.conclusionHold))
            guard !Task.isCancelled else { return }
            showsConclusion = false
        }
    }

    // MARK: Deslize

    /// Segurar e arrastar: a espera curta deixa o arrasto vertical rápido para a rolagem da página.
    private var slideGesture: some Gesture {
        LongPressGesture(minimumDuration: FrilaMotion.selectionSlideHoldDuration)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.listSpace)))
            .onChanged { value in
                if case .second(true, let drag?) = value { slide(toY: drag.location.y) }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let id = rowID(atY: drag.location.y),
                      let level = levels.first(where: { $0.id == id }) else { return }
                choose(level)
            }
    }

    private func rowID(atY y: CGFloat) -> String? {
        let rows = levels.compactMap { level in rowFrames[level.id].map { (id: level.id, frame: $0) } }
        return FrilaSlideSelection.rowID(atY: y, in: rows)
    }

    private func slide(toY y: CGFloat) {
        guard let id = rowID(atY: y), id != slideTitle else { return }
        withAnimation(FrilaMovimento.animacao(FrilaMotion.selectionWashSlide, reduzir: reduceMotion)) { slideTitle = id }
    }
}

// MARK: - Preview
