import FrilaDominio
import SwiftUI

/// "Nova vaga" do FrilaLowPhase (`FrilaPublishShiftSheet`, main 4badc63), enxertada no app.
/// Rótulo acima de cada campo, campos curtos em grade de duas colunas e barra fixa com resumo,
/// total e "Publicar vaga". Depois do toque, 5 s de "Enviando" com Desfazer; no fim, publica pelo
/// `PublicarVagaViewModel`, o mesmo caminho da tela atual. Só abre com `-FRILA_ENXERTO_LOWPHASE` (DEBUG).
public struct TelaPublicarVagaFrilaLP: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var formulario: FormularioPublicarVagaFrilaLP
    @State private var segundosRestantes: Int?
    @State private var tarefaDeEnvio: Task<Void, Never>?
    @State private var publicou = 0
    @State private var confirmandoDescarte = false
    @State private var escolhendoData = false
    @State private var trocandoLocal = false
    @State private var assinaturaInicial: String?
    @State private var keyboardObserver = FrilaLPKeyboardObserver()

    private let estabelecimento: Estabelecimento
    private let aoPublicar: () -> Void
    private let aoCancelar: (() -> Void)?

    public init(
        api: any ApiCliente,
        fila: any FilaDeAcoes,
        estabelecimento: Estabelecimento,
        aoPublicar: @escaping () -> Void = {},
        aoCancelar: (() -> Void)? = nil
    ) {
        let vaga = PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento)
        self.init(formulario: FormularioPublicarVagaFrilaLP(vaga: vaga), estabelecimento: estabelecimento, aoPublicar: aoPublicar, aoCancelar: aoCancelar)
    }

    init(
        formulario: FormularioPublicarVagaFrilaLP,
        estabelecimento: Estabelecimento,
        aoPublicar: @escaping () -> Void = {},
        aoCancelar: (() -> Void)? = nil
    ) {
        _formulario = State(initialValue: formulario)
        self.estabelecimento = estabelecimento
        self.aoPublicar = aoPublicar
        self.aoCancelar = aoCancelar
    }

    private var vaga: PublicarVagaViewModel { formulario.vaga }
    private var isDark: Bool { colorScheme == .dark }
    private var secondary: Color { FrilaLPColor.dynamicSecondaryText(isDark: isDark) }
    private var enviando: Bool { segundosRestantes != nil || vaga.enviando }
    private var bloqueio: String? { formulario.bloqueio }

    /// Retrato dos campos para saber se há edição a descartar.
    private var assinatura: String {
        [vaga.funcaoID?.uuidString ?? "", vaga.posicoesTexto, vaga.valorTexto, vaga.responsavelLocal,
         "\(vaga.inicio.timeIntervalSince1970)", "\(vaga.fim.timeIntervalSince1970)"].joined(separator: "|")
    }

    private var editou: Bool { assinaturaInicial.map { $0 != assinatura } ?? false }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    form
                        .disabled(enviando || vaga.restaurandoPublicacao)
                        .padding(.horizontal, FrilaLPGeometry.screenGutter)
                        .padding(.top, FrilaLPGeometry.space8)
                        .padding(
                            .bottom,
                            keyboardObserver.isKeyboardVisible
                                ? max(FrilaLPGeometry.space24, max(0, (keyboardObserver.coordinator?.scopeFrame.height ?? 600) - keyboardObserver.keyboardTop) + FrilaLPGeometry.space16)
                                : FrilaLPGeometry.space24
                        )
                }
                .scrollDismissesKeyboard(.interactively)
                .background(FrilaLPColor.dynamicGroupedBackground(isDark: isDark).ignoresSafeArea())
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    publishBar
                        .frilaLPCollapseOnKeyboard()
                        .frilaLPRevealBottomBar()
                }
                .frilaLPFieldReveal(
                    scrollProxy: scrollProxy,
                    keyboardObserver: keyboardObserver
                )
            }
            .navigationTitle(Text("Nova vaga", bundle: bundleApresentacao))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if aoCancelar != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: tentarCancelar) {
                            Text("Cancelar", bundle: bundleApresentacao)
                        }
                        .disabled(enviando)
                        .accessibilityIdentifier("cancelar-publicacao-frilalp")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { esconderTeclado() } label: { Text("OK", bundle: bundleApresentacao) }
                        .fontWeight(.semibold)
                }
            }
        }
        .frilaLPKeyboardDismissScope(observer: keyboardObserver)
        .tint(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
        .interactiveDismissDisabled(editou || enviando)
        .confirmationDialog(Text("Descartar esta vaga?", bundle: bundleApresentacao), isPresented: $confirmandoDescarte, titleVisibility: .visible) {
            Button(role: .destructive) { aoCancelar?() } label: { Text("Descartar vaga", bundle: bundleApresentacao) }
            Button(role: .cancel) {} label: { Text("Continuar editando", bundle: bundleApresentacao) }
        } message: {
            Text("O que você preencheu não fica salvo.", bundle: bundleApresentacao)
        }
        .sheet(isPresented: $escolhendoData) {
            FrilaLPShiftOtherDateSheet(now: .now, initial: formulario.diaDoTurno) { data in
                selecionarData(data)
            }
        }
        .sheet(isPresented: $trocandoLocal) {
            FrilaLPShiftVenuePickerSheet(estabelecimento: estabelecimento, endereco: vaga.local)
        }
        .sensoryFeedback(.success, trigger: publicou)
        .task {
            await vaga.restaurarPublicacaoPendente()
            await vaga.carregarFuncoes()
            if assinaturaInicial == nil { assinaturaInicial = assinatura }
        }
        .onChange(of: vaga.resultado != nil) { _, publicada in
            if publicada { aoPublicar() }
        }
        .onDisappear { tarefaDeEnvio?.cancel() }
    }

    // MARK: Formulário

    private var form: some View {
        VStack(alignment: .leading, spacing: FrilaLPGeometry.space24) {
            field(String(localized: "Função", bundle: bundleApresentacao)) {
                FrilaLPMenuField(
                    value: formulario.funcaoSelecionada?.nome ?? String(localized: "Escolha a função", bundle: bundleApresentacao),
                    accessibilityTitle: String(localized: "Função", bundle: bundleApresentacao)
                ) {
                    Picker(selection: Binding(get: { vaga.funcaoID }, set: { vaga.funcaoID = $0 })) {
                        ForEach(vaga.funcoes) { funcao in
                            Text(verbatim: funcao.nome).tag(Optional(funcao.id))
                        }
                    } label: {
                        Text("Função", bundle: bundleApresentacao)
                    }
                }
            }
            .id("campo-funcao")

            twoColumns {
                field(String(localized: "Posições", bundle: bundleApresentacao)) {
                    FrilaLPQuantityStepper(
                        value: Binding(get: { formulario.posicoes }, set: { formulario.posicoes = $0 }),
                        range: FormularioPublicarVagaFrilaLP.faixaDePosicoes,
                        accessibilityTitle: String(localized: "Posições", bundle: bundleApresentacao)
                    )
                }
            } trailing: {
                field(String(localized: "Valor por posição", bundle: bundleApresentacao)) {
                    FrilaLPCurrencyField(
                        cents: Binding(get: { formulario.valorCentavos }, set: { formulario.valorCentavos = $0 }),
                        accessibilityTitle: String(localized: "Valor por posição", bundle: bundleApresentacao),
                        fieldID: "publish_shift_pay_per_position"
                    )
                }
            }

            field(String(localized: "Quando", bundle: bundleApresentacao)) {
                FrilaLPFlowLayout(horizontalSpacing: FrilaLPGeometry.space8, verticalSpacing: 0) {
                    FrilaLPChoiceChip(formulario.rotuloDeHoje, isSelected: formulario.dia == .today) {
                        selecionar(.today)
                    }
                    FrilaLPChoiceChip(String(localized: "Amanhã", bundle: bundleApresentacao), isSelected: formulario.dia == .tomorrow) {
                        selecionar(.tomorrow)
                    }
                    FrilaLPChoiceChip(
                        formulario.rotuloDeOutraData,
                        isSelected: formulario.outraDataEscolhida,
                        leadingSystemImage: formulario.outraDataEscolhida ? "calendar" : nil
                    ) {
                        escolhendoData = true
                    }
                }
                .padding(.vertical, -FrilaLPGeometry.space6)
            }

            VStack(alignment: .leading, spacing: FrilaLPGeometry.space12) {
                twoColumns {
                    field(String(localized: "Início", bundle: bundleApresentacao)) {
                        FrilaLPTimeField(String(localized: "Início", bundle: bundleApresentacao), selection: $formulario.janela.start)
                    }
                } trailing: {
                    field(String(localized: "Fim", bundle: bundleApresentacao)) {
                        FrilaLPTimeField(String(localized: "Fim", bundle: bundleApresentacao), selection: $formulario.janela.end)
                    }
                }
                if let nota = formulario.notaDeVirada {
                    Label {
                        Text(verbatim: nota)
                    } icon: {
                        Image(systemName: "moon")
                    }
                    .font(FrilaLPTypography.Native.note)
                    .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                    .transition(.opacity)
                }
            }
            .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: formulario.janela)

            field(String(localized: "Local", bundle: bundleApresentacao)) {
                VStack(alignment: .leading, spacing: FrilaLPGeometry.space8) {
                    venueCard
                    Text("Ponto confirmado no mapa no cadastro. O check-in dos profissionais vale num raio de 200 m deste ponto.", bundle: bundleApresentacao)
                        .font(FrilaLPTypography.Native.note)
                        .foregroundStyle(secondary)
                        .padding(.horizontal, FrilaLPGeometry.space4)
                }
            }

            // Fora do sheet Swift da origem, mas presente no protótipo Publicar.dc.html e obrigatório no contrato.
            field(String(localized: "Quem recebe o profissional no local", bundle: bundleApresentacao)) {
                FrilaLPOutlinedField {
                    TextField(
                        String(localized: "Nome de quem recebe", bundle: bundleApresentacao),
                        text: Binding(get: { vaga.responsavelLocal }, set: { vaga.responsavelLocal = $0 })
                    )
                    .textContentType(.name)
                    .submitLabel(.done)
                    .accessibilityIdentifier("campo-responsavel-frilalp")
                }
            }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FrilaLPGeometry.space8) {
            FrilaLPFieldLabel(title)
                .padding(.horizontal, FrilaLPGeometry.space4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Duas colunas; em tamanhos de acessibilidade vira uma coluna só.
    @ViewBuilder
    private func twoColumns<Leading: View, Trailing: View>(
        @ViewBuilder _ leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaLPGeometry.space24) {
                leading()
                trailing()
            }
        } else {
            HStack(alignment: .top, spacing: FrilaLPGeometry.space16) {
                leading()
                trailing()
            }
        }
    }

    private var venueCard: some View {
        HStack(spacing: FrilaLPGeometry.space12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FrilaLPGeometry.space2) {
                Text(verbatim: estabelecimento.nome)
                    .font(FrilaLPTypography.Native.fieldLabel)
                    .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                Text(verbatim: vaga.local)
                    .font(FrilaLPTypography.Native.meta)
                    .foregroundStyle(secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: FrilaLPGeometry.space8)
            Button { trocandoLocal = true } label: { Text("Trocar", bundle: bundleApresentacao) }
                .buttonStyle(FrilaLPPillButtonStyle(variant: .outline, isDark: isDark, size: .compact))
                .accessibilityLabel(Text("Trocar local", bundle: bundleApresentacao))
        }
        .padding(.leading, FrilaLPGeometry.space16)
        .padding(.trailing, FrilaLPGeometry.space12)
        .padding(.vertical, FrilaLPGeometry.space12)
        .background(
            RoundedRectangle(cornerRadius: FrilaLPGeometry.radiusCard, style: .continuous)
                .fill(FrilaLPColor.dynamicGroupedSurface(isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FrilaLPGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaLPColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        )
    }

    // MARK: Barra fixa

    private var publishBar: some View {
        VStack(alignment: .leading, spacing: FrilaLPGeometry.space12) {
            if let restantes = segundosRestantes {
                sendingContent(remaining: restantes)
                    .transition(.opacity)
            } else {
                editingContent
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, FrilaLPGeometry.screenGutter)
        .padding(.top, FrilaLPGeometry.space14)
        .padding(.bottom, FrilaLPGeometry.space8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            FrilaLPColor.dynamicGroupedSurface(isDark: isDark)
                .opacity(0.94)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FrilaLPColor.dynamicHairline(isDark: isDark))
                .frame(height: 1)
        }
        .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: segundosRestantes != nil)
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: FrilaLPGeometry.space12) {
            Text(verbatim: formulario.resumo)
                .font(FrilaLPTypography.Native.summary)
                .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: FrilaLPGeometry.space16) {
                VStack(alignment: .leading, spacing: FrilaLPGeometry.space2) {
                    Text(verbatim: FrilaLPMoney.total(cents: formulario.totalCentavos))
                        .font(FrilaLPTypography.Native.tickerTotal)
                        .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(formulario.totalCentavos)))
                        .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: formulario.totalCentavos)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(verbatim: formulario.detalhamento)
                        .font(FrilaLPTypography.Native.meta)
                        .foregroundStyle(secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Total \(FrilaLPMoney.spoken(cents: formulario.totalCentavos))", bundle: bundleApresentacao))
                .accessibilityValue(Text("\(formulario.posicoes) de \(FrilaLPMoney.spoken(cents: formulario.valorCentavos))", bundle: bundleApresentacao))

                Spacer(minLength: 0)

                Button(action: comecarEnvio) { Text("Publicar vaga", bundle: bundleApresentacao) }
                    .buttonStyle(FrilaLPPillButtonStyle(variant: .ink, isDark: isDark, size: .prominent))
                    .opacity(bloqueio == nil ? 1 : 0.4)
                    .disabled(bloqueio != nil || vaga.restaurandoPublicacao)
                    .accessibilityIdentifier("publicar-vaga-frilalp")
            }

            if let problema = bloqueio ?? formulario.erroDaPublicacao {
                Label {
                    Text(verbatim: problema)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .font(FrilaLPTypography.Native.note)
                .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                .accessibilityIdentifier("erro-publicacao-frilalp")
            } else {
                Text("Quem aceitar primeiro fica com a vaga, sem você precisar aprovar.", bundle: bundleApresentacao)
                    .font(FrilaLPTypography.Native.note)
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sendingContent(remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: FrilaLPGeometry.space12) {
            HStack(alignment: .center, spacing: FrilaLPGeometry.space16) {
                VStack(alignment: .leading, spacing: FrilaLPGeometry.space2) {
                    Text("Enviando a vaga", bundle: bundleApresentacao)
                        .font(FrilaLPTypography.Native.summary)
                        .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                    Text("Vai para os profissionais em \(remaining) s", bundle: bundleApresentacao)
                        .font(FrilaLPTypography.Native.tickerNote)
                        .foregroundStyle(secondary)
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: remaining)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(action: desfazerEnvio) { Text("Desfazer", bundle: bundleApresentacao) }
                    .buttonStyle(FrilaLPPillButtonStyle(variant: .outline, isDark: isDark, size: .prominent))
                    .accessibilityIdentifier("desfazer-publicacao-frilalp")
            }
            FrilaLPShiftSendProgress(duration: Double(FormularioPublicarVagaFrilaLP.janelaDeDesfazerSegundos), reduceMotion: reduceMotion)
            Text(verbatim: formulario.resumo)
                .font(FrilaLPTypography.Native.note)
                .foregroundStyle(secondary)
        }
    }

    // MARK: Ações

    private func selecionar(_ escolha: FrilaLPShiftDayChoice) {
        withAnimation(FrilaMovimento.animacao(FrilaLPMotion.chipGliderSpring, reduzir: reduceMotion)) {
            formulario.escolher(escolha)
        }
    }

    private func selecionarData(_ data: Date) {
        withAnimation(FrilaMovimento.animacao(FrilaLPMotion.chipGliderSpring, reduzir: reduceMotion)) {
            formulario.escolherData(data)
        }
    }

    private func tentarCancelar() {
        if editou {
            confirmandoDescarte = true
        } else {
            aoCancelar?()
        }
    }

    private func comecarEnvio() {
        esconderTeclado()
        guard formulario.podeComecarEnvio() else { return }
        segundosRestantes = FormularioPublicarVagaFrilaLP.janelaDeDesfazerSegundos
        tarefaDeEnvio = Task { @MainActor in
            for segundo in stride(from: FormularioPublicarVagaFrilaLP.janelaDeDesfazerSegundos, to: 0, by: -1) {
                segundosRestantes = segundo
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            let publicada = await formulario.publicar()
            segundosRestantes = nil
            if publicada { publicou += 1 }
        }
    }

    private func desfazerEnvio() {
        tarefaDeEnvio?.cancel()
        tarefaDeEnvio = nil
        segundosRestantes = nil
    }

    private func esconderTeclado() {
        keyboardObserver.dismissKeyboard()
    }
}

// MARK: - Progresso do envio

/// Barra que enche durante a janela de Desfazer. Movimento constante, por isso linear.
struct FrilaLPShiftSendProgress: View {
    @Environment(\.colorScheme) private var colorScheme
    let duration: Double
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        let isDark = colorScheme == .dark
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FrilaLPColor.dynamicControlFill(isDark: isDark))
                Capsule()
                    .fill(FrilaLPColor.dynamicSelectionFill(isDark: isDark))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(FrilaMovimento.animacao(.linear(duration: duration), reduzir: reduceMotion)) {
                progress = 1
            }
        }
    }
}

// MARK: - Outra data

struct FrilaLPShiftOtherDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let now: Date
    let onSelect: (Date) -> Void
    @State private var selection: Date

    init(now: Date, initial: Date, onSelect: @escaping (Date) -> Void) {
        self.now = now
        self.onSelect = onSelect
        self._selection = State(initialValue: initial)
    }

    private var range: ClosedRange<Date> {
        let start = FrilaLPShiftCalendar.brasilia.startOfDay(for: now)
        return start...FrilaLPShiftCalendar.date(byAddingDays: 60, to: now)
    }

    var body: some View {
        NavigationStack {
            DatePicker(selection: $selection, in: range, displayedComponents: .date) {
                Text("Data do turno", bundle: bundleApresentacao)
            }
            .datePickerStyle(.graphical)
            .environment(\.locale, Locale(identifier: "pt_BR"))
            .environment(\.calendar, FrilaLPShiftCalendar.brasilia)
            .environment(\.timeZone, FrilaLPShiftCalendar.brasilia.timeZone)
            .padding(.horizontal, FrilaLPGeometry.screenGutter)
            .navigationTitle(Text("Outra data", bundle: bundleApresentacao))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancelar", bundle: bundleApresentacao) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSelect(selection)
                        dismiss()
                    } label: {
                        Text("OK", bundle: bundleApresentacao)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Trocar local

/// Na origem, a lista vem dos locais do cadastro. No app a vaga sai sempre do estabelecimento
/// que publica, então a lista tem um item só.
struct FrilaLPShiftVenuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let estabelecimento: Estabelecimento
    let endereco: String

    var body: some View {
        let isDark = colorScheme == .dark
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: FrilaLPGeometry.space12) {
                            VStack(alignment: .leading, spacing: FrilaLPGeometry.space2) {
                                Text(verbatim: estabelecimento.nome)
                                    .font(FrilaLPTypography.Native.fieldLabel)
                                    .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                                Text(verbatim: endereco)
                                    .font(FrilaLPTypography.Native.meta)
                                    .foregroundStyle(FrilaLPColor.dynamicSecondaryText(isDark: isDark))
                            }
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                        }
                        .frame(minHeight: FrilaLPGeometry.hitboxMinimum)
                    }
                    .accessibilityAddTraits(.isSelected)
                } footer: {
                    Text("Os locais vêm do cadastro do estabelecimento, cada um com o ponto confirmado no mapa.", bundle: bundleApresentacao)
                }
            }
            .navigationTitle(Text("Trocar local", bundle: bundleApresentacao))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancelar", bundle: bundleApresentacao) }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
