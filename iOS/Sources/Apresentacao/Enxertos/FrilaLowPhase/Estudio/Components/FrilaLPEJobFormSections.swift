import SwiftUI

// MARK: - Seções do formulário de Publicar vaga
//
// Conjunto único de campos consumido pelo formulário direto e pelo modo em etapas.
// Padrão de entrada: rótulo acima do campo, campos contornados e grade para campos curtos.

// MARK: - Regras do rascunho

enum FrilaLPEJobPaymentMode: Hashable, Sendable {
    case perShift
    case hourly
}

extension FrilaLPEJobCreationDraft {
    /// Rascunho de uma vaga nova: campos vazios (o formulário mostra os placeholders),
    /// sem valor definido e sem inclusões. A experiência parte de "Qualquer Experiência",
    /// que é uma escolha neutra e não um dado de exemplo.
    public static var blank: FrilaLPEJobCreationDraft {
        FrilaLPEJobCreationDraft(
            client: "",
            craft: "",
            seniority: "Qualquer Experiência",
            tags: [],
            protocolType: "",
            duration: "",
            location: "",
            rateHourly: 0,
            totalBudget: 0,
            title: "",
            role: "",
            shiftDate: "",
            startTime: "",
            endTime: "",
            address: "",
            addressNote: "",
            payPerPosition: 0,
            positionsCount: 1,
            positionsOpen: 1,
            mealIncluded: false,
            transportIncluded: false,
            bringOwnMaterial: false,
            dressCode: "",
            contactPerson: "",
            distanceText: "",
            reputationScore: "",
            reputationLabel: "",
            urgencyNote: ""
        )
    }

    /// Duração do turno em minutos a partir de Início e Fim (atravessa a meia-noite).
    /// Nil enquanto falta um horário ou quando os dois são iguais.
    var shiftDurationMinutes: Int? {
        FrilaLPEJobShiftFormat.durationMinutes(start: startTime, end: endTime)
    }

    var paymentMode: FrilaLPEJobPaymentMode {
        get { paymentType.contains("Único") ? .perShift : .hourly }
        set { paymentType = newValue == .perShift ? "Pagamento Único (por turno)" : "Por Hora" }
    }

    /// Recalcula o total das vagas conforme o modo de pagamento.
    /// Por hora, o total segue a duração real do turno; sem horários válidos, fica em zero.
    mutating func recalculateTotalBudget() {
        switch paymentMode {
        case .perShift:
            totalBudget = payPerPosition * positionsCount
        case .hourly:
            let minutes = shiftDurationMinutes ?? 0
            totalBudget = (rateHourly * minutes * positionsCount) / 60
        }
    }

    mutating func selectRole(_ name: String, origin: FrilaLPERoleOrigin = .catalog) {
        role = name
        roleOrigin = origin
        title = name
    }

    /// O título acompanha a função enquanto estiver vazio ou igual à função anterior. Um título que a pessoa
    /// escreveu (ou que veio de uma vaga existente) nunca é sobrescrito ao girar a roleta.
    mutating func followRole(from previousRole: String) {
        if title.isEmpty || title == previousRole { title = role }
    }
}

// MARK: - Modelo das seções

/// Seções do formulário único, em ordem. Alimentam as barras do cabeçalho,
/// a pergunta fixa, o resumo da seção completa e o foco do Publicar.
enum FrilaLPEJobFormSection: Int, CaseIterable, Identifiable, Sendable {
    case vaga
    case turno
    case valor

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .vaga: return "Vaga"
        case .turno: return "Turno"
        case .valor: return "Valor"
        }
    }

    var question: String {
        switch self {
        case .vaga: return "Qual é a vaga?"
        case .turno: return "Quando é o turno?"
        case .valor: return "Quanto paga o turno?"
        }
    }

    var support: String {
        switch self {
        case .vaga: return "Selecione a função e o local de atendimento."
        case .turno: return "Informe quando o profissional irá atuar e quem o receberá no local."
        case .valor: return "Defina o valor pago por profissional e o número de vagas disponíveis."
        }
    }

    var stepItem: FrilaLPEFlowStepItem {
        FrilaLPEFlowStepItem(
            id: "job-form-\(title.lowercased())",
            stepNumber: String(format: "%02d", rawValue + 1),
            title: title,
            subtitle: support,
            prompt: question
        )
    }

    /// Campos obrigatórios da seção, na ordem em que aparecem.
    private func requiredChecks(_ draft: FrilaLPEJobCreationDraft) -> [Bool] {
        switch self {
        case .vaga:
            return [draft.role.isFilled, draft.address.isFilled]
        case .turno:
            // O fim só conta quando forma um turno válido com o início
            let validEnd = draft.endTime.isFilled
                && FrilaLPEJobShiftFormat.blockingIssue(start: draft.startTime, end: draft.endTime) == nil
            return [draft.shiftDate.isFilled, draft.startTime.isFilled, validEnd]
        case .valor:
            // O contador de vagas nunca fica abaixo de 1, então só o valor conta como preenchimento
            let value = draft.paymentMode == .perShift ? draft.payPerPosition : draft.rateHourly
            return [value > 0]
        }
    }

    /// Fração dos campos obrigatórios preenchidos, de 0 a 1. Enche a barra da seção.
    func progress(_ draft: FrilaLPEJobCreationDraft) -> Double {
        let checks = requiredChecks(draft)
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }

    func isComplete(_ draft: FrilaLPEJobCreationDraft) -> Bool {
        requiredChecks(draft).allSatisfy { $0 }
    }

    /// Seções antecedentes a esta na ordem linear estrita do formulário.
    var priorSections: [FrilaLPEJobFormSection] {
        FrilaLPEJobFormSection.allCases.filter { $0.rawValue < self.rawValue }
    }

    /// Retorna verdadeiro se todas as seções anteriores à atual estiverem 100% completas.
    /// Para a primeira seção (.vaga), o retorno é sempre verdadeiro.
    func arePriorSectionsComplete(_ draft: FrilaLPEJobCreationDraft) -> Bool {
        priorSections.allSatisfy { $0.isComplete(draft) }
    }

    /// Linha compacta mostrada no título da seção completa. Nil enquanto incompleta.
    func summary(_ draft: FrilaLPEJobCreationDraft) -> String? {
        guard isComplete(draft) else { return nil }
        switch self {
        case .vaga:
            return "\(draft.role.trimmed), \(draft.address.trimmed)"
        case .turno:
            return "\(draft.shiftDate.trimmed), \(draft.startTime.trimmed) às \(draft.endTime.trimmed)"
        case .valor:
            let value = draft.paymentMode == .perShift
                ? "\(FrilaLPEMoney.total(draft.payPerPosition)) por turno"
                : FrilaLPEMoney.rate(draft.rateHourly)
            let positions = draft.positionsCount == 1 ? "1 vaga" : "\(draft.positionsCount) vagas"
            return "\(value), \(positions)"
        }
    }

    /// Primeira seção com obrigatório faltando. Destino do toque em Publicar incompleto.
    static func firstIncomplete(in draft: FrilaLPEJobCreationDraft) -> FrilaLPEJobFormSection? {
        allCases.first { !$0.isComplete(draft) }
    }

    /// Seção visível na rolagem contínua: a última cujo topo passou da linha de leitura
    /// (`offset + probe`), em coordenadas do conteúdo.
    ///
    /// Voltar para uma seção anterior exige recuar `hysteresis` pontos além da linha. Isso absorve
    /// a mudança de altura do cabeçalho fixo quando a pergunta troca, que desloca o conteúdo
    /// e faria a seção oscilar no limite. No fim da rolagem, a última seção fica ativa.
    static func visibleSection(
        current: FrilaLPEJobFormSection,
        offset: CGFloat,
        tops: [FrilaLPEJobFormSection: CGFloat],
        probe: CGFloat,
        hysteresis: CGFloat = 24,
        atBottom: Bool = false
    ) -> FrilaLPEJobFormSection {
        if atBottom, let last = allCases.last { return last }
        let line = offset + probe
        let candidate = allCases.last { (tops[$0] ?? .infinity) <= line } ?? .vaga
        guard candidate.rawValue < current.rawValue else { return candidate }
        // Recuo: mantém a seção atual enquanto seu topo não descer além da folga
        let currentTop = tops[current] ?? .infinity
        return currentTop <= line + hysteresis ? current : candidate
    }

    /// Folga depois da última seção: só o bastante para ela encaixar logo abaixo do cabeçalho
    /// no fim da rolagem. Com folga maior, o fundo passava do início da seção e escondia seu conteúdo
    /// sob o cabeçalho; com menos, ela nunca chegava à linha de leitura.
    ///
    /// Repouso máximo = conteúdo − área visível; ele deve coincidir com a âncora da última seção
    /// (topo − `snapInset`). Seção mais alta que a área visível não precisa de folga além do mínimo.
    static func trailingSpace(
        viewport: CGFloat,
        lastSectionHeight: CGFloat,
        spacing: CGFloat,
        snapInset: CGFloat,
        minimum: CGFloat = FrilaLPEGeometry.space24
    ) -> CGFloat {
        guard viewport > 0, lastSectionHeight > 0 else { return minimum }
        return max(minimum, viewport - lastSectionHeight - spacing - snapInset)
    }

    /// Repouso da rolagem em modo carrossel: sempre o topo de uma seção, nunca o meio do caminho.
    ///
    /// Cada seção tem um intervalo de repouso `[topo, base]`, onde `base` é o maior deslocamento que
    /// ainda mostra a seção ancorada na parte de baixo da área visível. Seção que cabe na tela tem
    /// `base == topo`; seção mais alta que a tela rola livre dentro do intervalo, sem esconder campos.
    ///
    /// Fora do intervalo, o gesto decide por intenção, no máximo uma seção por vez:
    /// - avança ou recua se o repouso proposto passou de `commitFraction` do vão até a próxima âncora
    ///   ou se a velocidade passou de `flickVelocity`;
    /// - senão, volta para a borda do intervalo atual.
    ///
    /// Trocar de seção, para qualquer lado, sempre chega no topo da seção de destino: o início do conteúdo
    /// da etapa aparece alinhado. Seção alta se percorre rolando por dentro dela.
    static func pagedOffset(
        proposed: CGFloat,
        original: CGFloat,
        velocity: CGFloat,
        anchors: [CGFloat],
        viewport: CGFloat,
        maxOffset: CGFloat,
        tuning: FrilaLPEJobFormPagingTuning = .standard
    ) -> CGFloat {
        let tops = anchors.map { min(max(0, $0), maxOffset) }.sorted()
        guard !tops.isEmpty else { return proposed }
        let bottoms = tops.indices.map { index -> CGFloat in
            let limit = index + 1 < tops.count ? tops[index + 1] - viewport : maxOffset
            return max(tops[index], min(limit, maxOffset))
        }

        // Seção de origem: a de intervalo mais próximo de onde o gesto começou
        func distance(_ index: Int) -> CGFloat {
            original < tops[index] ? tops[index] - original : max(0, original - bottoms[index])
        }
        let current = tops.indices.min { distance($0) < distance($1) } ?? 0

        if proposed >= tops[current] && proposed <= bottoms[current] { return proposed }

        let flick = abs(velocity) >= tuning.flickVelocity
        if proposed > bottoms[current] {
            guard current + 1 < tops.count else { return bottoms[current] }
            let gap = tops[current + 1] - bottoms[current]
            let commits = flick || proposed - bottoms[current] >= gap * tuning.commitFraction
            return commits ? tops[current + 1] : bottoms[current]
        }
        guard current > 0 else { return tops[current] }
        let gap = tops[current] - bottoms[current - 1]
        let commits = flick || tops[current] - proposed >= gap * tuning.commitFraction
        return commits ? tops[current - 1] : tops[current]
    }
}

/// Sensibilidade do carrossel de seções do formulário. Valores ajustáveis para testes no simulador.
struct FrilaLPEJobFormPagingTuning: Equatable, Sendable {
    /// Fração do vão até a próxima seção que o arrasto precisa cobrir para trocar de seção.
    var commitFraction: CGFloat
    /// Velocidade (pt/s) a partir da qual um gesto curto já troca de seção.
    var flickVelocity: CGFloat

    static let standard = FrilaLPEJobFormPagingTuning(commitFraction: 0.18, flickVelocity: 650)
}

// MARK: - Carrossel vertical de seções

/// Força o repouso da rolagem no topo de uma seção, como páginas de um carrossel vertical.
/// Seções mais altas que a tela rolam livres por dentro (ver `FrilaLPEJobFormSection.pagedOffset`).
struct FrilaLPEJobFormSectionPagingBehavior: ScrollTargetBehavior {
    /// Deslocamentos de conteúdo que alinham cada seção logo abaixo do cabeçalho fixo.
    var anchors: [CGFloat]
    var tuning: FrilaLPEJobFormPagingTuning = .standard
    var isEnabled: Bool = true

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard isEnabled else { return }
        let maxOffset = max(0, context.contentSize.height - context.containerSize.height)
        target.rect.origin.y = FrilaLPEJobFormSection.pagedOffset(
            proposed: target.rect.minY,
            original: context.originalTarget.rect.minY,
            velocity: context.velocity.dy,
            anchors: anchors,
            viewport: context.containerSize.height,
            maxOffset: maxOffset,
            tuning: tuning
        )
    }
}

// MARK: - Pergunta e apoio do cabeçalho no formulário contínuo

/// Pergunta e texto de apoio da seção visível no cabeçalho fixo, com altura estável reservada pelo
/// par pergunta + apoio mais longo.
///
/// O apoio da etapa ativa não rola com o conteúdo: vive fixo no cabeçalho, logo abaixo da pergunta,
/// permanecendo 100% visível e íntegro durante todo o arrasto, sem nunca passar sob o véu.
///
/// Troca rápida e discreta em duas camadas que se cruzam na mesma unidade (pergunta + apoio):
/// - saída: o bloco atual dissolve com desfoque de 2pt em 80ms (desaceleração);
/// - entrada: 20ms depois, o novo bloco parte 6pt deslocado (de baixo ao descer, de cima ao subir) e
///   assenta com mola criticamente amortecida (400/40), sem oscilar.
/// O desfoque funde as duas no cruzamento e não há quadro com o cabeçalho vazio.
/// Movimento reduzido: só opacidade, sem desfoque nem deslocamento.
struct FrilaLPEJobFormHeaderQuestion: View {
    let section: FrilaLPEJobFormSection
    let draft: FrilaLPEJobCreationDraft
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var incoming: FrilaLPEJobFormSection?
    @State private var inOffset: CGFloat = 0
    @State private var inOpacity: Double = 1
    @State private var inBlur: CGFloat = 0

    @State private var outgoing: FrilaLPEJobFormSection?
    @State private var outOpacity: Double = 0
    @State private var outBlur: CGFloat = 0

    static let travel: CGFloat = 6
    /// Desfoque sutil na transição de saída/entrada da pergunta e apoio.
    /// Valor existente preservado da transição canônica de pergunta do Frila.
    static let blurRadius: CGFloat = 2
    static let exitDuration: Double = 0.08
    static let entryDelay: Double = 0.02

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Reserva de altura estável para o par pergunta + apoio de qualquer seção.
            // O cabeçalho reserva a altura do maior par, garantindo que a transição entre etapas
            // nunca altere a altura do cabeçalho nem provoque deslocamentos no conteúdo.
            ForEach(FrilaLPEJobFormSection.allCases) { reserved in
                pairBlock(for: reserved)
                    .hidden()
                    .accessibilityHidden(true)
            }

            if let outgoing {
                pairBlock(for: outgoing)
                    .modifier(FrilaLPEQuestionSwapEffect(offsetY: 0, opacity: outOpacity, blur: outBlur))
                    .accessibilityHidden(true)
            }

            let active = incoming ?? section
            pairBlock(for: active)
                .modifier(FrilaLPEQuestionSwapEffect(offsetY: inOffset, opacity: inOpacity, blur: inBlur))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(accessibilityLabel(for: active))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: section) { old, new in
            swap(from: old, to: new)
        }
    }

    private func pairBlock(for sec: FrilaLPEJobFormSection) -> some View {
        let summary = sec.summary(draft)
        let isValidated = sec.arePriorSectionsComplete(draft)
        return VStack(alignment: .leading, spacing: FrilaLPEGeometry.space6) {
            questionText(sec.question)

            HStack(alignment: .firstTextBaseline, spacing: FrilaLPEGeometry.space8) {
                Text(verbatim: sec.support)
                    .frilaLPEType(FrilaLPEFormType.support, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if summary != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FrilaLPETypography.caption)
                        .foregroundColor(
                            isValidated
                                ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark)
                                : FrilaLPEColor.dynamicProgressNeutral(isDark: isDark)
                        )
                        .transition(.opacity)
                        .animation(FrilaMovimento.animacao(FrilaLPEMotion.progressBarSpring, reduzir: reduceMotion), value: isValidated)
                }
            }
        }
    }

    private func accessibilityLabel(for sec: FrilaLPEJobFormSection) -> String {
        let summary = sec.summary(draft)
        let isValidated = sec.arePriorSectionsComplete(draft)
        return "Etapa \(sec.rawValue + 1) de \(FrilaLPEJobFormSection.allCases.count). "
            + (summary.map {
                let status = isValidated ? "completo" : "preenchido, validação das etapas anteriores pendente"
                return "\(sec.title), \(status): \($0)."
            } ?? "\(sec.title).") + " \(sec.support)"
    }

    private func swap(from old: FrilaLPEJobFormSection, to new: FrilaLPEJobFormSection) {
        let movingForward = new.rawValue > old.rawValue
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = incoming ?? old
            outOpacity = inOpacity
            outBlur = 0
            incoming = new
            inOffset = reduceMotion ? 0 : (movingForward ? Self.travel : -Self.travel)
            inOpacity = 0
            inBlur = reduceMotion ? 0 : Self.blurRadius
        }
        DispatchQueue.main.async {
            withAnimation(FrilaMovimento.animacao(.easeOut(duration: Self.exitDuration), reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                outOpacity = 0
                if !reduceMotion { outBlur = Self.blurRadius }
            }
            let entry: Animation = reduceMotion
                ? .easeOut(duration: 0.14)
                : .interpolatingSpring(stiffness: 400, damping: 40).delay(Self.entryDelay)
            withAnimation(FrilaMovimento.animacao(entry, reduzir: FrilaLPEMovimentoReduzido.ativo)) {
                inOffset = 0
                inOpacity = 1
                inBlur = 0
            }
        }
    }

    private func questionText(_ text: String) -> some View {
        Text(verbatim: text)
            .frilaLPEType(FrilaLPEFormType.question, dynamic: true)
            .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
    }
}

/// Deslocamento vertical, opacidade e desfoque da troca de pergunta e apoio.
struct FrilaLPEQuestionSwapEffect: ViewModifier {
    let offsetY: CGFloat
    let opacity: Double
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .opacity(opacity)
            .blur(radius: blur)
    }
}


private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isFilled: Bool { !trimmed.isEmpty }
}

// MARK: - Campo com rótulo acima

struct FrilaLPEJobFormLabeledField<Content: View>: View {
    let label: String
    let isDark: Bool
    var support: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
            Text(verbatim: label)
                .frilaLPEType(FrilaLPEFormType.fieldLabel, dynamic: true)
                .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))

            content

            if let support {
                Text(verbatim: support)
                    .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
            }
        }
    }
}

extension View {
    /// Contorno padrão dos campos de digitação do formulário.
    func jobFormInputChrome(isDark: Bool, horizontalPadding: CGFloat = FrilaLPEGeometry.space14) -> some View {
        self
            .frilaLPEType(FrilaLPEFormType.input, dynamic: true)
            .padding(.horizontal, horizontalPadding)
            .frame(height: FrilaLPEGeometry.buttonHeightProminent)
            .background(FrilaLPEColor.dynamicFormFieldSurface(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusInput, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusInput, style: .continuous)
                    .strokeBorder(FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark), lineWidth: 1)
            }
    }
}

// MARK: - Seção Vaga

struct FrilaLPEJobFormVagaSection: View {
    @Binding var draft: FrilaLPEJobCreationDraft
    let isDark: Bool
    let groupStyle: FrilaLPEPickerGroupStyle
    /// Folga abaixo da experiência desejada: torna a seção mais alta que a tela, então ela rola livre
    /// por dentro e o usuário pode trazer o seletor de experiência até o meio da tela antes de abri-lo.
    static let experienceScrollRoom: CGFloat = 200

    private enum Field: Hashable {
        case client
        case address
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space20) {
            // Seletor inline em roletas acopladas (Categoria e Função)
            FrilaLPECoupledRolePicker(
                axis: .vertical,
                selectedRole: $draft.role,
                selectedRoleOrigin: $draft.roleOrigin,
                isDark: isDark,
                // Vertical solto com borda de acento ao confirmar; o agrupamento só vale para o seletor de experiência
                confirmedStyle: .accentBorder,
                groupStyle: nil
            )
            .onChange(of: draft.role) { previous, _ in
                draft.followRole(from: previous)
            }

            FrilaLPEJobFormLabeledField(label: "Estabelecimento", isDark: isDark) {
                TextField(String(localized: "Bar da Quadra", table: "FrilaLPEEstudio", bundle: bundleApresentacao), text: $draft.client)
                    .focused($focusedField, equals: .client)
                    .jobFormInputChrome(isDark: isDark)
                    .frilaLPEFormField(id: "job_form_client", isFocused: focusedField == .client, onDismiss: { focusedField = nil })
            }

            FrilaLPEJobFormLabeledField(
                label: "Endereço",
                isDark: isDark,
                // Só afirma a origem do endereço quando há um endereço para trocar
                support: draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : "Vem do cadastro do estabelecimento; dá para trocar."
            ) {
                TextField(String(localized: "CLN 408, Bloco B, Asa Norte", table: "FrilaLPEEstudio", bundle: bundleApresentacao), text: $draft.address)
                    .focused($focusedField, equals: .address)
                    .jobFormInputChrome(isDark: isDark)
                    .frilaLPEFormField(id: "job_form_address", isFocused: focusedField == .address, onDismiss: { focusedField = nil })
            }

            FrilaLPEJobFormLabeledField(label: "Experiência desejada", isDark: isDark) {
                FrilaLPEExperienceLevelPicker(selection: $draft.seniority, isDark: isDark, palette: groupStyle)
            }
            .padding(.bottom, Self.experienceScrollRoom)
        }
    }
}

// MARK: - Seção Turno

struct FrilaLPEJobFormTurnoSection: View {
    @Binding var draft: FrilaLPEJobCreationDraft
    /// Campo de data ou horário com o seletor flutuante aberto.
    @Binding var editingShift: FrilaLPEJobShiftField?
    let isDark: Bool
    let navigationStyle: FrilaLPEJobShiftNavigationStyle
    /// Depois de tentar publicar incompleto, campos de turno vazios ganham contorno de erro.
    var showsMissing: Bool = false

    private enum Field: Hashable {
        case contactPerson
        case dressCode
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space20) {
            FrilaLPEJobFormShiftTimeRow(draft: $draft, editing: $editingShift, isDark: isDark, navigationStyle: navigationStyle, showsMissing: showsMissing)

            FrilaLPEJobFormInclusionsCard(draft: $draft, isDark: isDark)

            FrilaLPEJobFormLabeledField(label: "Quem recebe o profissional no local", isDark: isDark) {
                TextField(String(localized: "Renata, no balcão", table: "FrilaLPEEstudio", bundle: bundleApresentacao), text: $draft.contactPerson)
                    .focused($focusedField, equals: .contactPerson)
                    .jobFormInputChrome(isDark: isDark)
                    .frilaLPEFormField(id: "job_form_contact_person", isFocused: focusedField == .contactPerson, onDismiss: { focusedField = nil })
            }

            FrilaLPEJobFormLabeledField(label: "Traje ou uniforme", isDark: isDark) {
                TextField(String(localized: "Camisa preta, calça escura", table: "FrilaLPEEstudio", bundle: bundleApresentacao), text: $draft.dressCode)
                    .focused($focusedField, equals: .dressCode)
                    .jobFormInputChrome(isDark: isDark)
                    .frilaLPEFormField(id: "job_form_dress_code", isFocused: focusedField == .dressCode, onDismiss: { focusedField = nil })
            }
        }
    }
}

// MARK: - Card O que está incluso

struct FrilaLPEJobFormInclusionsCard: View {
    @Binding var draft: FrilaLPEJobCreationDraft
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space14) {
            Text("O que está incluso", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .textCase(.uppercase)
                .frilaLPEType(FrilaLPEFormType.microLabel, dynamic: true)
                .foregroundColor(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                .accessibilityAddTraits(.isHeader)

            FrilaLPEJobFormYesNoRow(title: "Refeição", isOn: $draft.mealIncluded, isDark: isDark)
            FrilaLPEJobFormYesNoRow(title: "Transporte", isOn: $draft.transportIncluded, isDark: isDark)
            FrilaLPEJobFormYesNoRow(title: "Material próprio", isOn: $draft.bringOwnMaterial, isDark: isDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaLPEGeometry.space16)
        .background(FrilaLPEColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaLPEFormLift(isDark: isDark)
    }
}

/// Linha de Sim/Não do formulário com `FrilaLPESegmentedControl` canônico.
struct FrilaLPEJobFormYesNoRow: View {
    let title: String
    @Binding var isOn: Bool
    let isDark: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Mapeamento canônico dos segmentos booleanos do formulário.
    static let items: [FrilaLPESegmentedItem<Bool>] = [
        FrilaLPESegmentedItem(tag: true, title: "Sim"),
        FrilaLPESegmentedItem(tag: false, title: "Não")
    ]

    /// Largura padronizada para alinhamento em coluna dos três controles do card.
    static let controlWidth: CGFloat = 120

    /// Valor falado pelo VoiceOver indicando o estado atual da opção.
    var spokenValue: String {
        isOn ? "Sim" : "Não"
    }

    /// Alterna o valor do binding associado.
    func toggle() {
        isOn.toggle()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
                    labelView
                    controlView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    labelView
                    Spacer()
                    controlView
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spokenValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            toggle()
        }
    }

    private var labelView: some View {
        Text(verbatim: title)
            .frilaLPEType(FrilaLPEFormType.input, dynamic: true)
            .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
    }

    private var controlView: some View {
        FrilaLPESegmentedControl(
            items: Self.items,
            selection: $isOn,
            isDark: isDark,
            height: FrilaLPEGeometry.buttonHeightStandard
        )
        .frame(width: Self.controlWidth)
    }
}

// MARK: - Seção Valor

struct FrilaLPEJobFormValorSection: View {
    @Binding var draft: FrilaLPEJobCreationDraft
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let shiftPresets = [100, 120, 140, 160, 200]
    private static let hourlyPresets = [15, 20, 25, 30, 35]

    private var isPerShift: Bool { draft.paymentMode == .perShift }
    private var currentValue: Int { isPerShift ? draft.payPerPosition : draft.rateHourly }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space20) {
            FrilaLPESegmentedControl(
                items: [
                    FrilaLPESegmentedItem(tag: FrilaLPEJobPaymentMode.perShift, title: "Por turno"),
                    FrilaLPESegmentedItem(tag: FrilaLPEJobPaymentMode.hourly, title: "Por hora")
                ],
                selection: Binding(
                    get: { draft.paymentMode },
                    set: {
                        draft.paymentMode = $0
                        draft.recalculateTotalBudget()
                    }
                ),
                isDark: isDark,
                height: FrilaLPEGeometry.buttonHeightStandard
            )

            VStack(alignment: .leading, spacing: FrilaLPEGeometry.space12) {
                HStack(alignment: .firstTextBaseline) {
                    // O segmento acima já diz "por turno" ou "por hora": o rótulo não repete
                    Text("Valor", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                        .frilaLPEType(FrilaLPEFormType.fieldLabel, dynamic: true)
                        .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    Spacer()
                    if currentValue > 0 {
                        Text(verbatim: isPerShift ? FrilaLPEMoney.total(draft.payPerPosition) : FrilaLPEMoney.rate(draft.rateHourly))
                            .font(FrilaLPETypography.metricTabular(size: 20, weight: .bold))
                            .foregroundColor(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                            .contentTransition(.numericText())
                    } else {
                        Text("Escolha um valor", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                            .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                            .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    }
                }

                presetRow
                valueSlider
            }

            positionsStepper

            totalCard
        }
    }

    private var presetRow: some View {
        let presets = isPerShift ? Self.shiftPresets : Self.hourlyPresets
        let current = isPerShift ? draft.payPerPosition : draft.rateHourly
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FrilaLPEGeometry.space8) {
                ForEach(presets, id: \.self) { value in
                    Button(action: { setValue(value) }) {
                        Text(verbatim: isPerShift ? FrilaLPEMoney.total(value) : FrilaLPEMoney.rate(value))
                            .font(FrilaLPETypography.captionMedium)
                            .lineLimit(1)
                            .foregroundColor(current == value ? .white : FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                            .padding(.horizontal, FrilaLPEGeometry.space12)
                            .frame(height: FrilaLPEGeometry.buttonHeightCompact)
                            .background(
                                current == value ? FrilaLPEColor.dynamicBrandAccent(isDark: isDark) : FrilaLPEColor.dynamicFormCardSurface(isDark: isDark),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(
                                    current == value ? Color.clear : FrilaLPEColor.dynamicFormCardBorder(isDark: isDark),
                                    lineWidth: 1
                                )
                            }
                            .frilaLPEFormLift(isDark: isDark)
                    }
                    .buttonStyle(FrilaLPEHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: 0.96))
                    .frilaLPEHitbox()
                    .accessibilityAddTraits(current == value ? [.isSelected] : [])
                }
            }
        }
    }

    private var valueSlider: some View {
        Slider(
            value: Binding(
                get: { Double(isPerShift ? draft.payPerPosition : draft.rateHourly) },
                set: { setValue(Int($0), animated: false) }
            ),
            in: isPerShift ? 80...300 : 15...45,
            step: isPerShift ? 10 : 5
        )
        .tint(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
        .accessibilityLabel(isPerShift ? String(localized: "Valor por turno", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "Valor por hora", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
    }

    private var positionsStepper: some View {
        HStack {
            VStack(alignment: .leading, spacing: FrilaLPEGeometry.space2) {
                Text("Vagas abertas", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .frilaLPEType(FrilaLPEFormType.fieldLabel, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                Text("Profissionais necessários para o turno", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
            }

            Spacer()

            HStack(spacing: FrilaLPEGeometry.space4) {
                stepButton(systemImage: "minus", label: "Remover uma vaga", delta: -1)
                    .disabled(draft.positionsCount <= 1)

                Text("\(draft.positionsCount)", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .font(FrilaLPETypography.metricTabular(size: 18, weight: .bold))
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .contentTransition(.numericText())
                    .frame(minWidth: 24)
                    .accessibilityLabel(String(localized: "\(draft.positionsCount) vagas", table: "FrilaLPEEstudio", bundle: bundleApresentacao))

                stepButton(systemImage: "plus", label: "Adicionar uma vaga", delta: 1)
            }
        }
    }

    private func stepButton(systemImage: String, label: String, delta: Int) -> some View {
        Button(action: {
            withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion)) {
                draft.positionsCount = max(1, draft.positionsCount + delta)
                draft.recalculateTotalBudget()
            }
        }) {
            Image(systemName: systemImage)
                .font(FrilaLPEFonteDoSistema.fonte(size: 14, weight: .bold))
                .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                .frame(width: FrilaLPEGeometry.buttonHeightCompact, height: FrilaLPEGeometry.buttonHeightCompact)
                .background(FrilaLPEColor.dynamicFormCardSurface(isDark: isDark), in: Circle())
                .overlay { Circle().strokeBorder(FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark), lineWidth: 1) }
                .frilaLPEFormLift(isDark: isDark)
        }
        .buttonStyle(FrilaLPEHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: 0.96))
        .frilaLPEHitbox()
        .accessibilityLabel(label)
    }

    private var totalCard: some View {
        HStack(alignment: .center, spacing: FrilaLPEGeometry.space12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Valor total das vagas", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .textCase(.uppercase)
                    .frilaLPEType(FrilaLPEFormType.microLabel, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                Text(verbatim: FrilaLPEMoney.total(draft.totalBudget))
                    .font(FrilaLPETypography.metricTabular(size: 22, weight: .bold))
                    .foregroundColor(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .contentTransition(.numericText())
                if let breakdown = totalBreakdown {
                    Text(verbatim: breakdown)
                        .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                        .foregroundColor(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Sem taxa: o profissional recebe o valor integral.", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                    .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                    .foregroundColor(FrilaLPEColor.dynamicFormTextMuted(isDark: isDark))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: FrilaLPEGeometry.space8)
            // O selo só faz sentido com um valor definido
            if draft.totalBudget > 0 {
                FrilaLPEStatusChip("Garantido", style: .verified, systemImage: "checkmark.seal.fill", isDark: isDark)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .padding(FrilaLPEGeometry.space16)
        .background(FrilaLPEColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaLPEFormLift(isDark: isDark)
        .accessibilityElement(children: .combine)
    }

    /// Conta aberta do total por hora: "8h a R$ 20/h, 2 vagas". Pede os horários quando faltam.
    private var totalBreakdown: String? {
        guard !isPerShift else { return nil }
        // O aviso aparece mesmo antes de o valor por hora ser digitado: sem horários não há total.
        guard let minutes = draft.shiftDurationMinutes else {
            return "Defina início e fim do turno para calcular o total."
        }
        guard draft.rateHourly > 0 else { return nil }
        let positions = draft.positionsCount == 1 ? "1 vaga" : "\(draft.positionsCount) vagas"
        return "\(FrilaLPEJobShiftFormat.durationLabel(minutes: minutes)) a \(FrilaLPEMoney.rate(draft.rateHourly)), \(positions)"
    }

    private func setValue(_ value: Int, animated: Bool = true) {
        let update = {
            if isPerShift { draft.payPerPosition = value } else { draft.rateHourly = value }
            draft.recalculateTotalBudget()
        }
        if animated && !reduceMotion {
            withAnimation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaLPEMovimentoReduzido.ativo), update)
        } else {
            update()
        }
    }
}
