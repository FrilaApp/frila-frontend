import SwiftUI

/// Item representativo de um passo de fluxo ou marco contratual.
public struct FrilaLPEFlowStepItem: Identifiable, Sendable {
    public let id: String
    public let stepNumber: String
    public let title: String
    public let subtitle: String
    public let prompt: String?
    public let isHot: Bool
    public let isCompleted: Bool

    public init(
        id: String = UUID().uuidString,
        stepNumber: String,
        title: String,
        subtitle: String = "",
        prompt: String? = nil,
        isHot: Bool = false,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.isHot = isHot
        self.isCompleted = isCompleted
    }

    /// Retorna uma cópia do item com o estado ativo e concluído atualizados
    public func withState(isHot: Bool, isCompleted: Bool) -> FrilaLPEFlowStepItem {
        FrilaLPEFlowStepItem(
            id: id,
            stepNumber: stepNumber,
            title: title,
            subtitle: subtitle,
            prompt: prompt,
            isHot: isHot,
            isCompleted: isCompleted
        )
    }
}

/// Modo de apresentação do stepper de progressão
public enum FrilaLPEFlowStepperStyle: String, Sendable, CaseIterable {
    /// Modo focado e adaptativo (Padrão para Studio e fluxos móveis):
    /// Barras Capsule de 4pt com larguras iguais e gap fixo, preenchimento contínuo em Terracotta
    /// sob máscara que atravessa os gaps com física de mola suave, e bloco de texto unificado
    /// em largura total exibindo exclusivamente os dados da etapa ativa com reserva de altura.
    case activeFocused

    /// Modo clássico expandido (Deck editorial):
    /// Todas as etapas exibem simultaneamente número, título e subtítulo.
    case fullExpanded

    /// Modo minimalista de pontos discretos com cápsula elástica deslizante.
    case dots

    public var displayName: String {
        switch self {
        case .activeFocused: return "Ativo Focado"
        case .fullExpanded: return "Expandido"
        case .dots: return "Pontos Fluidos"
        }
    }
}

/// Configuração do dock de ações de navegação do stepper
public struct FrilaLPEFlowStepperDockConfiguration: Sendable {
    public let continueTitle: String
    public let finishTitle: String
    public let backTitle: String
    public let forwardIcon: String?
    public let finishIcon: String
    public let isProminentOnFinish: Bool
    public let onContinue: (@Sendable () -> Void)?
    public let onBack: (@Sendable () -> Void)?
    public let onFinish: (@Sendable () -> Void)?

    public init(
        continueTitle: String = "Continuar",
        finishTitle: String = "Concluir",
        backTitle: String = "Voltar",
        forwardIcon: String? = nil,
        finishIcon: String = "checkmark.circle.fill",
        isProminentOnFinish: Bool = false,
        onContinue: (@Sendable () -> Void)? = nil,
        onBack: (@Sendable () -> Void)? = nil,
        onFinish: (@Sendable () -> Void)? = nil
    ) {
        self.continueTitle = continueTitle
        self.finishTitle = finishTitle
        self.backTitle = backTitle
        self.forwardIcon = forwardIcon
        self.finishIcon = finishIcon
        self.isProminentOnFinish = isProminentOnFinish
        self.onContinue = onContinue
        self.onBack = onBack
        self.onFinish = onFinish
    }
}

/// Frila Design System - FrilaLPEFlowStepper
/// Componente canônico unificado de navegação e progressão por etapas com física tátil e transições suaves.
/// Sintetiza a régua de marcos contratuais, a trilha de pontos fluidos e o dock de navegação com mola.
public struct FrilaLPEFlowStepper: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public typealias DockConfiguration = FrilaLPEFlowStepperDockConfiguration

    public let steps: [FrilaLPEFlowStepItem]
    public let totalStepsCount: Int?
    public let isDark: Bool
    public let style: FrilaLPEFlowStepperStyle
    public let showsTextBlock: Bool
    /// Preenchimento por seção (0...1). Quando presente, cada barra enche de forma independente
    /// e a etapa atual passa a indicar apenas a seção visível (formulário contínuo).
    public let sectionProgress: [Double]?
    public let onSelectStep: ((Int) -> Void)?
    public let currentStepBinding: Binding<Int>?
    public let dockConfiguration: DockConfiguration?

    @State private var internalStep: Int = 1
    @State private var previousStep: Int = 1
    @State private var lastMovingForward: Bool = true
    @State private var rulerSelectionTrigger: Int = 0

    // MARK: - Initializers

    /// Inicializador padrão dirigido por Binding e itens de etapas
    public init(
        currentStep: Binding<Int>,
        steps: [FrilaLPEFlowStepItem],
        isDark: Bool = false,
        style: FrilaLPEFlowStepperStyle = .activeFocused,
        showsTextBlock: Bool = true,
        sectionProgress: [Double]? = nil,
        dock: DockConfiguration? = nil,
        onSelectStep: ((Int) -> Void)? = nil
    ) {
        self.currentStepBinding = currentStep
        self.steps = steps
        self.totalStepsCount = steps.count
        self.isDark = isDark
        self.style = style
        self.showsTextBlock = showsTextBlock
        self.sectionProgress = sectionProgress
        self.dockConfiguration = dock
        self.onSelectStep = onSelectStep
        self._internalStep = State(initialValue: currentStep.wrappedValue)
        self._previousStep = State(initialValue: currentStep.wrappedValue)
    }

    /// Inicializador passivo ou independente (compatibilidade com marcos contratuais e decks editoriais)
    public init(
        steps: [FrilaLPEFlowStepItem],
        isDark: Bool = false,
        style: FrilaLPEFlowStepperStyle = .activeFocused,
        showsTextBlock: Bool = true,
        onSelectStep: ((Int) -> Void)? = nil
    ) {
        self.currentStepBinding = nil
        self.steps = steps
        self.totalStepsCount = steps.count
        self.isDark = isDark
        self.style = style
        self.showsTextBlock = showsTextBlock
        self.sectionProgress = nil
        self.dockConfiguration = nil
        self.onSelectStep = onSelectStep
        let initialHot = (steps.firstIndex(where: { $0.isHot }) ?? 0) + 1
        self._internalStep = State(initialValue: initialHot)
        self._previousStep = State(initialValue: initialHot)
    }

    /// Inicializador para modo de pontos (dots) com contagem total de etapas
    public init(
        currentStep: Binding<Int>,
        totalSteps: Int = 3,
        isDark: Bool = false,
        style: FrilaLPEFlowStepperStyle = .dots,
        dock: DockConfiguration? = nil
    ) {
        self.currentStepBinding = currentStep
        self.steps = []
        self.totalStepsCount = max(2, totalSteps)
        self.isDark = isDark
        self.style = style
        self.showsTextBlock = false
        self.sectionProgress = nil
        self.dockConfiguration = dock
        self.onSelectStep = nil
        self._internalStep = State(initialValue: currentStep.wrappedValue)
        self._previousStep = State(initialValue: currentStep.wrappedValue)
    }

    // MARK: - Computed Properties

    public var effectiveCurrentStep: Int {
        if let binding = currentStepBinding {
            return binding.wrappedValue
        }
        if let hotIndex = steps.firstIndex(where: { $0.isHot }) {
            return hotIndex + 1
        }
        return internalStep
    }

    public var effectiveTotalSteps: Int {
        if let count = totalStepsCount, count > 0 {
            return max(2, count)
        }
        return max(2, steps.count)
    }

    public var resolvedSteps: [FrilaLPEFlowStepItem] {
        if currentStepBinding != nil {
            let current = effectiveCurrentStep
            return steps.enumerated().map { index, item in
                let stepNum = index + 1
                let isCompleted = sectionProgress.map {
                    Self.isLinearValidated(at: index, in: $0) && Self.sectionFill($0, at: index) >= 1
                } ?? (stepNum < current)
                return item.withState(
                    isHot: stepNum == current,
                    isCompleted: isCompleted
                )
            }
        }
        return steps
    }

    private var isInteractive: Bool {
        onSelectStep != nil || currentStepBinding != nil
    }

    public struct ActiveStepTextTransitionModifier: AnimatableModifier, Sendable {
        public var offset: CGFloat
        public var opacity: Double
        public var blur: CGFloat
        public var scale: CGFloat

        public init(offset: CGFloat, opacity: Double, blur: CGFloat, scale: CGFloat = 1.0) {
            self.offset = offset
            self.opacity = opacity
            self.blur = blur
            self.scale = scale
        }

        nonisolated public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<Double, CGFloat>> {
            get {
                AnimatablePair(AnimatablePair(offset, scale), AnimatablePair(opacity, blur))
            }
            set {
                offset = newValue.first.first
                scale = newValue.first.second
                opacity = newValue.second.first
                blur = newValue.second.second
            }
        }

        public func body(content: Content) -> some View {
            content
                .offset(x: offset)
                .scaleEffect(scale, anchor: .topLeading)
                .opacity(opacity)
                .blur(radius: blur)
        }
    }

    public static func stepTextTransition(isMovingForward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            // Acessibilidade (reduceMotion): crossfade puro sem deslocamento nem blur; saída rápida antes da entrada
            let removal = AnyTransition.opacity
                // Curva de saída rápida em 80ms para limpar o texto anterior sem movimento
                .animation(FrilaMovimento.animacao(.easeOut(duration: 0.08), reduzir: FrilaLPEMovimentoReduzido.ativo))
            let insertion = AnyTransition.opacity
                // Aparição gradual imediata (40ms), eliminando sobreposição legível
                .animation(FrilaMovimento.animacao(.easeIn(duration: 0.12).delay(0.04), reduzir: FrilaLPEMovimentoReduzido.ativo))
            return .asymmetric(insertion: insertion, removal: removal)
        }

        // Saída: dissolve rápido quase no lugar (100ms), deslocamento 4pt e sem distorção de escala
        let removalOffset: CGFloat = isMovingForward ? -4 : 4
        let removal = AnyTransition.modifier(
            active: ActiveStepTextTransitionModifier(offset: removalOffset, opacity: 0, blur: 1.5, scale: 1.0),
            identity: ActiveStepTextTransitionModifier(offset: 0, opacity: 1, blur: 0, scale: 1.0)
        )
        // Curva de desaceleração rápida (100ms) que dissolve o texto de saída quase no lugar antes da entrada
        .animation(FrilaMovimento.animacao(.easeOut(duration: 0.10), reduzir: FrilaLPEMovimentoReduzido.ativo))

        // Entrada: rápida e nítida para a pergunta (40ms), offset de 4pt, blur suave (2.0pt) e escala 1.0
        // Mola criticamente amortecida (stiffness: 400, damping: 40) para o prompt tomar sua posição de imediato
        let insertionOffset: CGFloat = isMovingForward ? 4 : -4
        let insertion = AnyTransition.modifier(
            active: ActiveStepTextTransitionModifier(offset: insertionOffset, opacity: 0, blur: 2.0, scale: 1.0),
            identity: ActiveStepTextTransitionModifier(offset: 0, opacity: 1, blur: 0, scale: 1.0)
        )
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 400, damping: 40).delay(0.04), reduzir: FrilaLPEMovimentoReduzido.ativo))

        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Transição direcional padronizada para conteúdos de etapas e formulários na tela no Frila.
    ///
    /// Saída ágil quase no lugar (100ms easeOut) e entrada imediata e responsiva (40ms de atraso técnico
    /// com mola criticamente amortecida stiffness: 400, damping: 40), sem delay artificial nem deformação de escala nas informações da tela.
    public static func stepTransition(isMovingForward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            let removal = AnyTransition.opacity
                .animation(FrilaMovimento.animacao(.easeOut(duration: 0.08), reduzir: FrilaLPEMovimentoReduzido.ativo))
            let insertion = AnyTransition.opacity
                .animation(FrilaMovimento.animacao(.easeIn(duration: 0.12).delay(0.04), reduzir: FrilaLPEMovimentoReduzido.ativo))
            return .asymmetric(insertion: insertion, removal: removal)
        }

        let removalOffset: CGFloat = isMovingForward ? -6 : 6
        let removal = AnyTransition.modifier(
            active: ActiveStepTextTransitionModifier(offset: removalOffset, opacity: 0, blur: 1.5, scale: 1.0),
            identity: ActiveStepTextTransitionModifier(offset: 0, opacity: 1, blur: 0, scale: 1.0)
        )
        .animation(FrilaMovimento.animacao(.easeOut(duration: 0.10), reduzir: FrilaLPEMovimentoReduzido.ativo))

        let insertionOffset: CGFloat = isMovingForward ? 6 : -6
        let insertion = AnyTransition.modifier(
            active: ActiveStepTextTransitionModifier(offset: insertionOffset, opacity: 0, blur: 2.0, scale: 1.0),
            identity: ActiveStepTextTransitionModifier(offset: 0, opacity: 1, blur: 0, scale: 1.0)
        )
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 400, damping: 40).delay(0.04), reduzir: FrilaLPEMovimentoReduzido.ativo))

        return .asymmetric(insertion: insertion, removal: removal)
    }

    private func activeStepTransition(isMovingForward: Bool) -> AnyTransition {
        Self.stepTransition(isMovingForward: isMovingForward, reduceMotion: reduceMotion)
    }

    private var effectiveDockBinding: Binding<Int> {
        currentStepBinding ?? Binding(
            get: { internalStep },
            set: { internalStep = $0 }
        )
    }

    // MARK: - Mathematical Fill Calculation

    /// Calcula a largura do preenchimento contínuo em função da etapa ativa, total de etapas, largura disponível e espaçamento entre barras.
    ///
    /// - Parameters:
    ///   - step: Etapa atual (1-based, clamped entre 0 e `total`).
    ///   - total: Contagem total de etapas.
    ///   - width: Largura horizontal disponível total da régua.
    ///   - gap: Espaçamento fixo entre as barras (padrão: `FrilaLPEGeometry.space6`).
    /// - Returns: A largura em pontos do preenchimento contínuo.
    public static func fillWidth(
        step: Int,
        total: Int,
        width: CGFloat,
        gap: CGFloat = FrilaLPEGeometry.space6
    ) -> CGFloat {
        guard total > 0, width > 0 else { return 0 }
        let clampedStep = min(max(step, 0), total)
        guard clampedStep > 0 else { return 0 }
        if clampedStep == total {
            return width
        }
        let totalGaps = CGFloat(total - 1) * gap
        let availableForBars = max(0, width - totalGaps)
        let barWidth = availableForBars / CGFloat(total)
        let calculated = (CGFloat(clampedStep) * barWidth) + (CGFloat(clampedStep - 1) * gap)
        return min(width, max(0, calculated))
    }

    /// Preenchimento da seção no índice, limitado a 0...1 (0 quando ausente).
    public static func sectionFill(_ progress: [Double], at index: Int) -> Double {
        guard progress.indices.contains(index) else { return 0 }
        return min(max(progress[index], 0), 1)
    }

    /// Determina se a etapa no índice informado está validada na sequência linear do formulário.
    ///
    /// Uma etapa é linearmente validada quando todas as etapas antecedentes (0 ..< index)
    /// estão 100% preenchidas (`sectionFill >= 1.0`). A etapa inicial (índice 0) é sempre elegível.
    /// - Parameters:
    ///   - index: O índice da etapa (0-based).
    ///   - progress: O vetor de preenchimento fracionário das seções.
    /// - Returns: `true` se todas as etapas anteriores estão completas, `false` caso contrário.
    public static func isLinearValidated(at index: Int, in progress: [Double]) -> Bool {
        guard index > 0 else { return true }
        for priorIndex in 0..<index {
            if sectionFill(progress, at: priorIndex) < 1.0 - 0.0001 {
                return false
            }
        }
        return true
    }

    /// Espessura uniforme e constante das barras de seção (4pt), eliminando o aumento da barra
    /// ativa durante a rolagem vertical para manter uma régua arquitetural serena e estável.
    public static let sectionBarHeight: CGFloat = 4

    /// Compatibilidade com chamadas existentes: retorna sempre a espessura uniforme (4pt),
    /// sem salto de espessura entre ativa e inativa.
    public static func sectionBarHeight(isActive: Bool = false) -> CGFloat {
        sectionBarHeight
    }

    // MARK: - Body

    public var body: some View {
        let isMovingForward = (effectiveCurrentStep != previousStep)
            ? (effectiveCurrentStep > previousStep)
            : lastMovingForward

        VStack(spacing: FrilaLPEGeometry.space20) {
            switch style {
            case .activeFocused:
                if !resolvedSteps.isEmpty {
                    activeFocusedRulerView(isMovingForward: isMovingForward)
                }
            case .fullExpanded:
                if !resolvedSteps.isEmpty {
                    fullExpandedRulerView(isMovingForward: isMovingForward)
                }
            case .dots:
                Dots(
                    currentStep: effectiveCurrentStep,
                    totalSteps: effectiveTotalSteps,
                    isDark: isDark
                )
            }

            if let dock = dockConfiguration {
                Dock(
                    currentStep: effectiveDockBinding,
                    totalSteps: effectiveTotalSteps,
                    isDark: isDark,
                    configuration: dock
                )
            }
        }
        .onAppear {
            previousStep = effectiveCurrentStep
        }
        .onChange(of: effectiveCurrentStep) { oldValue, newValue in
            if newValue != oldValue {
                lastMovingForward = newValue > oldValue
                previousStep = newValue
            }
        }
    }

    // MARK: - Active Focused Ruler View

    private func activeFocusedRulerView(isMovingForward: Bool) -> some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
            // Barras com larguras iguais, preenchimento contínuo sob máscara e área de toque HIG >= 44x44pt
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                let currentFillWidth = Self.fillWidth(
                    step: effectiveCurrentStep,
                    total: resolvedSteps.count,
                    width: totalWidth,
                    gap: FrilaLPEGeometry.space6
                )

                ZStack(alignment: .center) {
                    if let progress = sectionProgress {
                        sectionProgressTrack(progress)
                    } else {
                        // Trilha inativa e preenchimento contínuo em Terracotta
                        ZStack(alignment: .leading) {
                            // Trilha inativa (N barras Capsule de 5pt com larguras iguais e gaps de 6pt)
                            HStack(spacing: FrilaLPEGeometry.space6) {
                                ForEach(0..<resolvedSteps.count, id: \.self) { _ in
                                    Capsule()
                                        .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                                        .frame(height: 5)
                                }
                            }

                            // Preenchimento contínuo único mascarado pelas N barras
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                                    .frame(width: currentFillWidth, height: 5)
                            }
                            .frame(width: totalWidth, height: 5, alignment: .leading)
                            .mask(
                                HStack(spacing: FrilaLPEGeometry.space6) {
                                    ForEach(0..<resolvedSteps.count, id: \.self) { _ in
                                        Capsule()
                                            .frame(height: 5)
                                    }
                                }
                                .frame(width: totalWidth, height: 5)
                            )
                        }
                        .frame(height: 5)
                        // Mola 300/20 idêntica ao Dots: física de massa fluida contínua que viaja entre os marcos sem oscilação excessiva
                        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 300, damping: 20), reduzir: reduceMotion),
                            value: effectiveCurrentStep
                        )
                    }

                    // Alvos de toque interativos (HIG >= 44x44pt) sobre cada segmento da barra
                    HStack(spacing: FrilaLPEGeometry.space6) {
                        ForEach(Array(resolvedSteps.enumerated()), id: \.element.id) { index, step in
                            if isInteractive {
                                Button {
                                    handleStepSelection(index: index)
                                } label: {
                                    Color.clear
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(FrilaLPEHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: 0.97))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(accessibilityLabel(for: step))
                                .accessibilityAddTraits(accessibilityTraits(for: step))
                                .accessibilityHint(String(localized: "Toque duas vezes para selecionar o passo \(step.stepNumber)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(accessibilityLabel(for: step))
                                    .accessibilityAddTraits(accessibilityTraits(for: step))
                            }
                        }
                    }
                    .frame(height: FrilaLPEGeometry.hitboxMinimum)
                }
                .frame(width: totalWidth, height: FrilaLPEGeometry.hitboxMinimum)
            }
            .frame(height: FrilaLPEGeometry.hitboxMinimum)

            // Bloco de texto ocupando largura total (apenas etapa ativa visível, altura estável)
            if showsTextBlock {
                activeStepTextBlock(isMovingForward: isMovingForward)
            }
        }
        .sensoryFeedback(.selection, trigger: rulerSelectionTrigger)
    }

    /// Barras por seção: altura uniforme (4pt), camada neutra para campos preenchidos
    /// e camada da marca (Terracotta) liberada conforme as etapas anteriores são validadas.
    private func sectionProgressTrack(_ progress: [Double]) -> some View {
        HStack(alignment: .center, spacing: FrilaLPEGeometry.space6) {
            ForEach(0..<resolvedSteps.count, id: \.self) { index in
                let fill = Self.sectionFill(progress, at: index)
                let isValidated = Self.isLinearValidated(at: index, in: progress)
                Capsule()
                    .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                    .overlay(alignment: .leading) {
                        GeometryReader { bar in
                            let barWidth = bar.size.width
                            let neutralWidth = barWidth * fill
                            let brandWidth = isValidated ? neutralWidth : 0

                            ZStack(alignment: .leading) {
                                // Camada 1: Preenchimento neutro (cinza) para campos preenchidos
                                Capsule()
                                    .fill(FrilaLPEColor.dynamicProgressNeutral(isDark: isDark))
                                    .frame(width: max(0, neutralWidth))

                                // Camada 2: Preenchimento validado da marca (Terracotta),
                                // liberado apenas quando as etapas anteriores estão concluídas
                                Capsule()
                                    .fill(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                                    .frame(width: max(0, brandWidth))
                            }
                        }
                    }
                    .clipShape(Capsule())
                    .frame(height: Self.sectionBarHeight)
            }
        }
        .frame(height: Self.sectionBarHeight)
        .animation(FrilaMovimento.animacao(FrilaLPEMotion.progressBarSpring, reduzir: reduceMotion),
            value: progress
        )
    }

    private func activeStepTextBlock(isMovingForward: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            // Reserva de altura invariante com todos os passos ocultos para evitar saltos verticais
            ForEach(resolvedSteps) { step in
                stepTextContent(for: step)
                    .hidden()
                    .accessibilityHidden(true)
            }

            // Exibição exclusiva da etapa ativa com transição direcional suave
            if let activeStep = currentActiveStepItem {
                stepTextContent(for: activeStep)
                    .id(activeStep.id)
                    .transition(activeStepTransition(isMovingForward: isMovingForward))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentActiveStepItem: FrilaLPEFlowStepItem? {
        let current = effectiveCurrentStep
        let index = current - 1
        if resolvedSteps.indices.contains(index) {
            return resolvedSteps[index]
        }
        return resolvedSteps.first
    }

    @ViewBuilder
    private func stepTextContent(for step: FrilaLPEFlowStepItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Título elevado para bodyBold (15pt) para contraste hierárquico nítido sobre o subtítulo (13pt)
            Text(verbatim: step.title)
                .font(FrilaLPETypography.bodyBold)
                .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                .lineLimit(1)

            if !step.subtitle.isEmpty {
                Text(verbatim: step.subtitle)
                    .font(FrilaLPETypography.caption)
                    .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Full Expanded Ruler View

    private func fullExpandedRulerView(isMovingForward: Bool) -> some View {
        HStack(alignment: .top, spacing: FrilaLPEGeometry.space10) {
            ForEach(Array(resolvedSteps.enumerated()), id: \.element.id) { index, step in
                stepColumnExpanded(step: step, index: index)
            }
        }
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
            value: effectiveCurrentStep
        )
        .sensoryFeedback(.selection, trigger: rulerSelectionTrigger)
    }

    @ViewBuilder
    private func stepColumnExpanded(step: FrilaLPEFlowStepItem, index: Int) -> some View {
        let isFilled = step.isCompleted || step.isHot

        Button {
            handleStepSelection(index: index)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Barra superior Capsule de 4pt com preenchimento em Terracotta
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                        .frame(height: 4)

                    Capsule()
                        .fill(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                        .frame(height: 4)
                        .scaleEffect(
                            x: isFilled ? 1.0 : 0.0001,
                            y: 1.0,
                            anchor: .leading
                        )
                        .opacity(isFilled ? 1.0 : 0.0)
                }
                .clipShape(Capsule())
                .frame(height: 4)

                // Modo clássico editorial (todas colunas expandidas)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: step.stepNumber)
                        .font(step.isHot ? FrilaLPETypography.captionBold : FrilaLPETypography.captionMedium)
                        .foregroundColor(step.isHot ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : FrilaLPEColor.dynamicSubtle(isDark: isDark))

                    Text(verbatim: step.title)
                        .font(FrilaLPETypography.captionBold)
                        .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    if !step.subtitle.isEmpty {
                        Text(verbatim: step.subtitle)
                            .font(FrilaLPETypography.caption)
                            .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .frame(minWidth: FrilaLPEGeometry.hitboxMinimum, maxWidth: .infinity, alignment: .topLeading)
            .clipped()
        }
        .buttonStyle(FrilaLPEHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: 0.97))
        .frame(minWidth: FrilaLPEGeometry.hitboxMinimum, minHeight: FrilaLPEGeometry.hitboxMinimum, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: step))
        .accessibilityAddTraits(accessibilityTraits(for: step))
        .accessibilityHint(isInteractive ? String(localized: "Toque duas vezes para selecionar o passo \(step.stepNumber)", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : "")
    }

    private func handleStepSelection(index: Int) {
        let nextStep = index + 1
        rulerSelectionTrigger += 1
        if nextStep != effectiveCurrentStep {
            lastMovingForward = nextStep > effectiveCurrentStep
        }
        let spring: Animation = (style == .activeFocused)
            ? .interpolatingSpring(stiffness: 300, damping: 20)
            : .interpolatingSpring(stiffness: 350, damping: 25)
        if let binding = currentStepBinding {
            withAnimation(FrilaMovimento.animacao(spring, reduzir: reduceMotion)) {
                binding.wrappedValue = nextStep
            }
        } else {
            withAnimation(FrilaMovimento.animacao(spring, reduzir: reduceMotion)) {
                internalStep = nextStep
            }
        }
        onSelectStep?(index)
    }

    public func accessibilityLabel(for step: FrilaLPEFlowStepItem) -> String {
        let totalCount = resolvedSteps.isEmpty ? effectiveTotalSteps : resolvedSteps.count
        let totalFormatted = (step.stepNumber.count >= 2 && totalCount < 100)
            ? String(format: "%02d", totalCount)
            : "\(totalCount)"
        var label = "Passo \(step.stepNumber) de \(totalFormatted): \(step.title)."
        if !step.subtitle.isEmpty {
            label += " \(step.subtitle)."
        }
        if let progress = sectionProgress,
           let index = resolvedSteps.firstIndex(where: { $0.id == step.id }) {
            let fill = Self.sectionFill(progress, at: index)
            let isValidated = Self.isLinearValidated(at: index, in: progress)
            if fill < 1 {
                label += " \(Int((fill * 100).rounded())) por cento preenchido."
            } else if !isValidated {
                label += " Preenchido, validação das etapas anteriores pendente."
            }
        }
        if step.isHot {
            label += " Destaque ativo."
        }
        if step.isCompleted {
            label += " Concluído."
        }
        return label
    }

    public func accessibilityTraits(for step: FrilaLPEFlowStepItem) -> AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isInteractive {
            traits.formUnion(.isButton)
        }
        if step.isHot {
            traits.formUnion(.isSelected)
        }
        return traits
    }
}

// MARK: - FrilaLPEFlowStepper.Dock (Dock de Ações de Navegação)
extension FrilaLPEFlowStepper {
    public struct Dock: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        @Binding public var currentStep: Int
        public let totalSteps: Int
        public let isDark: Bool
        public let configuration: DockConfiguration

        @State private var dockSelectionTrigger: Int = 0
        @State private var finishTrigger: Int = 0

        public init(
            currentStep: Binding<Int>,
            totalSteps: Int = 3,
            isDark: Bool = false,
            configuration: DockConfiguration = DockConfiguration()
        ) {
            self._currentStep = currentStep
            self.totalSteps = max(2, totalSteps)
            self.isDark = isDark
            self.configuration = configuration
        }

        public init(
            currentStep: Binding<Int>,
            totalSteps: Int = 3,
            isDark: Bool = false,
            continueTitle: String = "Continuar",
            finishTitle: String = "Concluir",
            backTitle: String = "Voltar",
            forwardIcon: String? = nil,
            finishIcon: String = "checkmark.circle.fill",
            isProminentOnFinish: Bool = false,
            onContinue: (@Sendable () -> Void)? = nil,
            onBack: (@Sendable () -> Void)? = nil,
            onFinish: (@Sendable () -> Void)? = nil
        ) {
            self._currentStep = currentStep
            self.totalSteps = max(2, totalSteps)
            self.isDark = isDark
            self.configuration = DockConfiguration(
                continueTitle: continueTitle,
                finishTitle: finishTitle,
                backTitle: backTitle,
                forwardIcon: forwardIcon,
                finishIcon: finishIcon,
                isProminentOnFinish: isProminentOnFinish,
                onContinue: onContinue,
                onBack: onBack,
                onFinish: onFinish
            )
        }

        public var isExpanded: Bool {
            currentStep <= 1
        }

        public var isFinalStep: Bool {
            currentStep >= totalSteps
        }

        public var body: some View {
            HStack(spacing: FrilaLPEGeometry.space12) {
                if !isExpanded {
                    Button(action: handleBack) {
                        Text(verbatim: configuration.backTitle)
                            .font(FrilaLPETypography.button)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FrilaLPEPillButtonStyle(variant: .outline, isDark: isDark, size: .standard))
                    .frame(width: 96)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.85)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: -16)),
                                removal: .scale(scale: 0.85)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: -16))
                            )
                    )
                    .frilaLPEHitbox()
                    .accessibilityLabel(String(localized: "Voltar para etapa anterior", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
                }

                Button(action: handleForward) {
                    HStack(spacing: 8) {
                        Text(verbatim: isFinalStep ? configuration.finishTitle : configuration.continueTitle)
                            .font(FrilaLPETypography.button)
                            .lineLimit(1)
                            .contentTransition(.interpolate)

                        if isFinalStep {
                            Image(systemName: configuration.finishIcon)
                                .font(FrilaLPETypography.captionBold)
                                .symbolEffect(.bounce, value: reduceMotion ? 0 : finishTrigger)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else if let forwardIcon = configuration.forwardIcon {
                            Image(systemName: forwardIcon)
                                .font(FrilaLPETypography.captionBold)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    FrilaLPEPillButtonStyle(
                        variant: .primary,
                        isDark: isDark,
                        size: (isFinalStep && configuration.isProminentOnFinish) ? .prominent : .standard
                    )
                )
                .frilaLPEHitbox()
                .accessibilityLabel(isFinalStep ? String(localized: "\(configuration.finishTitle), etapa final", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "\(configuration.continueTitle), próxima etapa", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
            }
            .frame(maxWidth: 400)
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                value: isExpanded
            )
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 400, damping: 22), reduzir: reduceMotion),
                value: isFinalStep
            )
            .sensoryFeedback(.selection, trigger: dockSelectionTrigger)
            .sensoryFeedback(.success, trigger: finishTrigger)
        }

        private func handleBack() {
            if currentStep > 1 {
                let previous = currentStep - 1
                dockSelectionTrigger += 1
                withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion)) {
                    currentStep = previous
                }
                configuration.onBack?()
            }
        }

        private func handleForward() {
            if isFinalStep {
                finishTrigger += 1
                configuration.onFinish?()
            } else {
                let next = min(totalSteps, currentStep + 1)
                dockSelectionTrigger += 1
                withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion)) {
                    currentStep = next
                }
                configuration.onContinue?()
            }
        }
    }
}

// MARK: - FrilaLPEFlowStepper.Dots (Trilha de Pontos com Cápsula Elástica Deslizante)
extension FrilaLPEFlowStepper {
    public struct Dots: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public let currentStep: Int
        public let totalSteps: Int
        public let isDark: Bool

        private let dotDiameter: CGFloat = 8
        private let dotSpacing: CGFloat = 20
        private let horizontalPadding: CGFloat = 6
        private let pillHeight: CGFloat = 16

        public init(
            currentStep: Int,
            totalSteps: Int = 3,
            isDark: Bool = false
        ) {
            self.totalSteps = max(2, totalSteps)
            self.currentStep = max(1, min(currentStep, self.totalSteps))
            self.isDark = isDark
        }

        public var clampedStep: Int {
            max(1, min(currentStep, totalSteps))
        }

        public var activePillWidth: CGFloat {
            let activeDotsSpan = CGFloat(clampedStep) * dotDiameter + CGFloat(clampedStep - 1) * dotSpacing
            return activeDotsSpan + (horizontalPadding * 2)
        }

        public var body: some View {
            ZStack(alignment: .leading) {
                // Cápsula fluida animada que desliza e cobre os pontos ativos
                Capsule()
                    .fill(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                    .frame(width: activePillWidth, height: pillHeight)
                    .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 300, damping: 20), reduzir: reduceMotion),
                        value: clampedStep
                    )

                // Trilha de pontos discretos
                HStack(spacing: dotSpacing) {
                    ForEach(1...totalSteps, id: \.self) { index in
                        Circle()
                            .fill(dotColor(for: index))
                            .frame(width: dotDiameter, height: dotDiameter)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .frame(height: 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Progresso: etapa \(clampedStep) de \(totalSteps)", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
            .accessibilityValue((Double(clampedStep) / Double(totalSteps)).formatted(.percent.precision(.fractionLength(0))))
        }

        private func dotColor(for index: Int) -> Color {
            if index <= clampedStep {
                return isDark ? FrilaLPEColor.pontoDoPassoNoEscuro : Color.white
            } else {
                return FrilaLPEColor.dynamicDividerStrong(isDark: isDark)
            }
        }
    }
}

// MARK: - FrilaLPEFlowStepper.StepHeader (Cabeçalho Unificado de Etapa: Pergunta e Apoio)
extension FrilaLPEFlowStepper {
    /// Bloco de cabeçalho unificado de etapa para visualizações com rolagem (como o Studio de Criação).
    ///
    /// Hierarquia visual e semântica de 2 níveis:
    /// 1. Pergunta: Chamada de ação em `titleLarge` (`dynamicInk`) indicando "o que fazer".
    /// 2. Apoio: Subtítulo descritivo em `caption` (`dynamicSubtle`) indicando "como fazer".
    ///
    /// O nome da etapa é preservado no VoiceOver (`accessibilityLabel: "\(step.title). \(prompt)"`),
    /// eliminando redundância visual frente às barras de progresso e ao toolbar.
    ///
    /// Suporta colapso contínuo do texto de apoio via scroll offset (`supportCollapse`: 0...1),
    /// encolhendo suavemente a altura e ocultando a opacidade na primeira metade do gesto.
    public struct StepHeader: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public let currentStep: Int
        public let steps: [FrilaLPEFlowStepItem]
        public let isDark: Bool
        public let supportCollapse: CGFloat

        @State private var previousStep: Int
        @State private var lastMovingForward: Bool = true

        public init(
            currentStep: Int,
            steps: [FrilaLPEFlowStepItem],
            isDark: Bool = false,
            supportCollapse: CGFloat = 0
        ) {
            self.currentStep = currentStep
            self.steps = steps
            self.isDark = isDark
            self.supportCollapse = min(max(supportCollapse, 0), 1)
            self._previousStep = State(initialValue: currentStep)
        }

        public init(
            currentStep: Binding<Int>,
            steps: [FrilaLPEFlowStepItem],
            isDark: Bool = false,
            supportCollapse: CGFloat = 0
        ) {
            self.currentStep = currentStep.wrappedValue
            self.steps = steps
            self.isDark = isDark
            self.supportCollapse = min(max(supportCollapse, 0), 1)
            self._previousStep = State(initialValue: currentStep.wrappedValue)
        }

        public var activeStep: FrilaLPEFlowStepItem? {
            let index = currentStep - 1
            if steps.indices.contains(index) {
                return steps[index]
            }
            return steps.first
        }

        private var isMovingForward: Bool {
            (currentStep != previousStep)
                ? (currentStep > previousStep)
                : lastMovingForward
        }

        /// Layout personalizado que dimensiona o cabeçalho estritamente pela etapa que entra (ativa).
        /// A etapa que está saindo não participa do dimensionamento (`sizeThatFits`), saindo do layout
        /// enquanto se dissolve alinhada ao topo (`topLeading`), permitindo que a altura do cabeçalho
        /// e o inset da rolagem sigam diretamente a etapa ativa sem folga residual.
        private struct ActiveStepLayout: Layout, Sendable {
            func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
                // Apenas a etapa ativa (última subview inserida durante a transição) define o tamanho do layout
                guard let active = subviews.last else { return .zero }
                let childProposal = ProposedViewSize(width: proposal.width, height: nil)
                return active.sizeThatFits(childProposal)
            }

            func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
                let childProposal = ProposedViewSize(width: bounds.width, height: nil)
                for subview in subviews {
                    subview.place(
                        at: bounds.origin,
                        anchor: .topLeading,
                        proposal: childProposal
                    )
                }
            }

            func explicitAlignment(
                of guide: HorizontalAlignment,
                in bounds: CGRect,
                proposal: ProposedViewSize,
                subviews: Subviews,
                cache: inout ()
            ) -> CGFloat? {
                nil
            }

            func explicitAlignment(
                of guide: VerticalAlignment,
                in bounds: CGRect,
                proposal: ProposedViewSize,
                subviews: Subviews,
                cache: inout ()
            ) -> CGFloat? {
                nil
            }
        }

        public var body: some View {
            ActiveStepLayout {
                if let active = activeStep {
                    stepContent(for: active)
                        .id(active.stepNumber)
                        .transition(FrilaLPEFlowStepper.stepTextTransition(isMovingForward: isMovingForward, reduceMotion: reduceMotion))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 400, damping: 40), reduzir: reduceMotion),
                value: currentStep
            )
            .onAppear {
                previousStep = currentStep
            }
            .onChange(of: currentStep) { oldValue, newValue in
                if newValue != oldValue {
                    lastMovingForward = newValue > oldValue
                    previousStep = newValue
                }
            }
        }

        @ViewBuilder
        public func stepContent(for step: FrilaLPEFlowStepItem) -> some View {
            VStack(alignment: .leading, spacing: 4 * (1.0 - supportCollapse)) {
                // Pergunta da etapa (ou fallback para title em titleLarge) com trait de Header e label falado completo
                if let prompt = step.prompt, !prompt.isEmpty {
                    Text(verbatim: prompt)
                        .font(FrilaLPETypography.titleLarge)
                        .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel(Self.headerAccessibilityLabel(for: step))
                } else {
                    // Fallback sem prompt: exibe title diretamente em titleLarge
                    Text(verbatim: step.title)
                        .font(FrilaLPETypography.titleLarge)
                        .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel(Self.headerAccessibilityLabel(for: step))
                }

                // Apoio (como fazer): caption, dynamicSubtle com colapso progressivo ligado à rolagem
                // e florescimento isolado em escala com delay dedicado na navegação
                if !step.subtitle.isEmpty {
                    supportView(for: step)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        @ViewBuilder
        private func supportView(for step: FrilaLPEFlowStepItem) -> some View {
            StepSupportTextView(
                subtitle: step.subtitle,
                supportCollapse: supportCollapse,
                isDark: isDark,
                reduceMotion: reduceMotion
            )
        }

        /// Componente de exibição do texto de apoio com florescimento isolado em escala + delay maior
        /// na navegação e colapso dinâmico 1:1 durante o scroll.
        private struct StepSupportTextView: View {
            let subtitle: String
            let supportCollapse: CGFloat
            let isDark: Bool
            let reduceMotion: Bool

            @State private var hasAppeared: Bool = false

            var body: some View {
                let scrollOpacity = FrilaLPEScrollCollapseMath.supportOpacity(for: supportCollapse)
                let scrollOffset = FrilaLPEScrollCollapseMath.supportVerticalOffset(progress: supportCollapse, reduceMotion: reduceMotion)
                let scrollScale = FrilaLPEScrollCollapseMath.supportScale(progress: supportCollapse, reduceMotion: reduceMotion)

                let effectiveOpacity = hasAppeared ? scrollOpacity : 0
                let effectiveScale = hasAppeared ? scrollScale : (reduceMotion ? 1.0 : 0.86)
                let effectiveOffset = hasAppeared ? scrollOffset : (reduceMotion ? 0 : 4)

                FrilaLPECollapsingHeightLayout(progress: supportCollapse) {
                    Text(verbatim: subtitle)
                        .font(FrilaLPETypography.caption)
                        .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel(subtitle)
                        .opacity(effectiveOpacity)
                        .scaleEffect(effectiveScale, anchor: .topLeading)
                        .offset(y: effectiveOffset)
                }
                .clipped()
                .onAppear {
                    if reduceMotion {
                        hasAppeared = true
                    } else {
                        withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 180, damping: 24).delay(0.22), reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                            hasAppeared = true
                        }
                    }
                }
            }
        }

        /// Rótulo falado para VoiceOver agrupando o nome da etapa e a pergunta como cabeçalho
        public static func headerAccessibilityLabel(for step: FrilaLPEFlowStepItem) -> String {
            if let prompt = step.prompt, !prompt.isEmpty {
                return "\(step.title). \(prompt)"
            }
            return step.title
        }
    }
}

// MARK: - Layout de Colapso de Altura Visual sem Estado
/// Layout que recolhe a altura do conteúdo proporcionalmente a `progress` (0 = altura natural, 1 = altura 0),
/// medindo a altura natural do filho com a largura proposta e devolvendo altura * (1 - p).
/// Ancora o filho no topo (`topLeading`) e descarta propostas de alinhamento explícito para estabilidade estrita.
public struct FrilaLPECollapsingHeightLayout: Layout, Sendable {
    public var progress: CGFloat

    public init(progress: CGFloat) {
        self.progress = min(max(progress, 0), 1)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let first = subviews.first else { return .zero }
        let naturalProposal = ProposedViewSize(width: proposal.width, height: nil)
        let naturalSize = first.sizeThatFits(naturalProposal)
        let clampedP = min(max(progress, 0), 1)
        return CGSize(
            width: naturalSize.width,
            height: max(0, naturalSize.height * (1.0 - clampedP))
        )
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let first = subviews.first else { return }
        let childProposal = ProposedViewSize(width: bounds.width, height: nil)
        first.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: childProposal
        )
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        nil
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        nil
    }
}

// MARK: - Funções Puras de Cálculo do Colapso de Rolagem
public enum FrilaLPEScrollCollapseMath {
    /// Epsilon mínimo para considerar que uma etapa possui curso de rolagem viável.
    /// Etapas com rolagem máxima disponível menor ou igual a 1pt mantêm o apoio visível (p = 0).
    public static let scrollEpsilon: CGFloat = 1.0

    /// Degrau de quantização para estabilidade de renderização e prevenção de invalidações contínuas.
    public static let progressQuantum: CGFloat = 0.01

    /// Calcula a distância dinâmica de colapso para a etapa.
    ///
    /// Regra: min(altura do apoio, rolagem máxima disponível da etapa com cabeçalho expandido).
    /// Etapa com pouco conteúdo ainda colapsa por inteiro no curso que tem;
    /// etapa que não rola (rolagem máxima <= 1pt) retorna 0 (mantém o apoio visível).
    public static func collapseDistance(
        supportHeight: CGFloat,
        maxScrollable: CGFloat
    ) -> CGFloat {
        guard maxScrollable > scrollEpsilon, supportHeight > 0 else {
            return 0
        }
        return min(supportHeight, maxScrollable)
    }

    /// Calcula o progresso contínuo de colapso p ∈ [0, 1] ligado 1:1 ao deslocamento do dedo.
    ///
    /// - Parameters:
    ///   - offset: Deslocamento da rolagem a partir do topo em repouso (positivo quando o conteúdo sobe).
    ///   - supportHeight: Altura medida natural do texto de apoio da etapa ativa.
    ///   - maxScrollable: Rolagem máxima disponível calculada com o cabeçalho EXPANDIDO (estável).
    ///   - quantize: Se verdadeiro, quantiza p em degraus de 0.01 para evitar recomposições desnecessárias.
    public static func progress(
        offset: CGFloat,
        supportHeight: CGFloat,
        maxScrollable: CGFloat,
        quantize: Bool = false
    ) -> CGFloat {
        let distance = collapseDistance(supportHeight: supportHeight, maxScrollable: maxScrollable)
        guard distance > 0 else { return 0 }

        let rawP = min(max(offset / distance, 0), 1)
        if quantize {
            return (rawP / progressQuantum).rounded() * progressQuantum
        }
        return rawP
    }

    /// Opacidade do texto de apoio: extingue-se antecipadamente (p >= 0.35)
    /// para evitar que o conteúdo rolante passe visível por trás do texto de apoio antes do desfoque total ("ghost caption").
    public static func supportOpacity(for progress: CGFloat) -> Double {
        let clampedP = min(max(progress, 0), 1)
        if clampedP >= 0.35 {
            return 0
        }
        return Double(1.0 - (clampedP / 0.35))
    }

    /// Altura do texto de apoio: colapso proporcional de h até 0 com clip.
    public static func supportHeight(naturalHeight: CGFloat, progress: CGFloat) -> CGFloat {
        let clampedP = min(max(progress, 0), 1)
        return max(0, naturalHeight * (1.0 - clampedP))
    }

    /// Deslocamento vertical do texto de apoio acompanhando a rolagem (até -4pt no topo).
    /// Suprimido se `reduceMotion` estiver ativo.
    public static func supportVerticalOffset(progress: CGFloat, reduceMotion: Bool) -> CGFloat {
        if reduceMotion { return 0 }
        let clampedP = min(max(progress, 0), 1)
        return -4.0 * clampedP
    }

    // MARK: - Curvas de Interpolação (Easing) e Escala
    /// Curva básica de facilitação de saída (ease-out quadrática): aceleração instantânea e desaceleração suave.
    /// f(t) = 1 - (1 - t)^2 para t ∈ [0, 1].
    public static func easeOut(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return 1.0 - (1.0 - clamped) * (1.0 - clamped)
    }

    /// Curva básica de facilitação suave (ease-in-out quadrática) para t ∈ [0, 1].
    public static func easeInOut(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return clamped < 0.5
            ? 2.0 * clamped * clamped
            : 1.0 - pow(-2.0 * clamped + 2.0, 2.0) / 2.0
    }

    /// Escala do texto de apoio durante colapso/expansão na rolagem (saída/entrada).
    ///
    /// Em repouso (progresso 0, entrada completa), escala = 1.0.
    /// Conforme colapsa até a extinção visual (janela p ∈ [0, 0.40]), reduz suavemente com curva easeInOut
    /// até 0.90, ancorado no topo/início (.topLeading).
    /// Suprimido se `reduceMotion` estiver ativo (bloqueado estritamente em 1.0 per Pillar 6).
    public static func supportScale(progress: CGFloat, reduceMotion: Bool = false) -> CGFloat {
        if reduceMotion { return 1.0 }
        let clampedP = min(max(progress, 0), 1)
        let visualP = min(clampedP / 0.40, 1.0)
        let ease = easeInOut(visualP)
        return 1.0 - (0.10 * ease)
    }
}

// MARK: - View Extension for Canonical Step Transitions
extension View {
    /// Aplica a transição direcional de etapas canônica do Frila (saída rápida em 110ms, entrada com atraso de 60ms e mola amortecida zeta=1.0).
    public func frilaLPEStepTransition(isMovingForward: Bool, reduceMotion: Bool) -> some View {
        self.transition(FrilaLPEFlowStepper.stepTransition(isMovingForward: isMovingForward, reduceMotion: reduceMotion))
    }
}
