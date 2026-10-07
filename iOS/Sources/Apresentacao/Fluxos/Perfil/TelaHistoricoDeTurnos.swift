import FrilaDominio
import SwiftUI

/// Histórico de turnos (#23): período, formato e Exportar. Design provisório, só com os tokens e
/// componentes do sistema de design, para trocar quando vier a alta fidelidade da v1.1.
public struct TelaHistoricoDeTurnos: View {
    @State private var model: HistoricoDeTurnosViewModel
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private static let idDoResultado = "historico-resultado"

    public init(api: any ApiCliente, estabelecimentoID: UUID? = nil) {
        _model = State(initialValue: HistoricoDeTurnosViewModel(api: api, estabelecimentoID: estabelecimentoID))
    }

    init(model: HistoricoDeTurnosViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollViewReader { rolagem in
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    Text(verbatim: TextosHistoricoDeTurnos.explicacao)
                        .font(.callout)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    secaoPeriodo
                    secaoFormato
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        BotaoPrimario(verbatim: TextosHistoricoDeTurnos.exportar, carregando: model.estaCarregando) {
                            Task { await model.exportar() }
                        }
                        .disabled(model.periodo == nil)
                        .accessibilityHint(Text(verbatim: TextosHistoricoDeTurnos.dicaExportar))
                        .accessibilityIdentifier("historico-exportar")
                        // O respiro de baixo faz a rolagem parar com folga acima da barra de abas.
                        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) { resultado }
                            .padding(.bottom, FrilaEspaco.medio)
                            .id(Self.idDoResultado)
                    }
                }
                .padding(FrilaEspaco.medio)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            // No iPhone SE o aviso nasce abaixo da dobra, atrás da barra de abas: a tela rola até ele.
            .onChange(of: model.estado) { _, novo in
                guard novo == .semTurnos || novo.ehErro else { return }
                if reduzirMovimento {
                    rolagem.scrollTo(Self.idDoResultado, anchor: .bottom)
                } else {
                    withAnimation { rolagem.scrollTo(Self.idDoResultado, anchor: .bottom) }
                }
            }
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosHistoricoDeTurnos.titulo))
        .navigationBarTitleDisplayMode(.inline)
        // Sem fundo, a barra inline deixava o texto da rolagem passar por trás do Voltar e do título.
        .toolbarBackground(FrilaCor.fundo, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: Bindable(model).mostrarFolhaCompartilhamento, onDismiss: {
            model.folhaCompartilhamentoFechada()
        }) {
            if let url = model.arquivoParaCompartilhar {
                FolhaCompartilhamento(url: url) { concluida in
                    model.atividadeCompartilhamentoConcluida(concluida: concluida)
                }
            }
        }
        .onChange(of: model.estado) { _, novo in anunciar(novo) }
    }

    // MARK: Período

    private var secaoPeriodo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosHistoricoDeTurnos.periodo)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            // Os três numa linha; no iPhone SE, dois e um; no maior texto, um por linha.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: FrilaEspaco.pequeno) { esteMes; mesPassado; intervalo }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    HStack(spacing: FrilaEspaco.pequeno) { esteMes; mesPassado }
                    intervalo
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) { esteMes; mesPassado; intervalo }
            }
            if model.atalho == .intervalo {
                seletorDeData(TextosHistoricoDeTurnos.de, selecao: inicio, faixa: ...model.fimEscolhido, identificador: "historico-de")
                seletorDeData(TextosHistoricoDeTurnos.ate, selecao: fim, faixa: ...model.agora, identificador: "historico-ate")
            }
            if let periodo = model.periodo {
                Text(verbatim: TextosHistoricoDeTurnos.resumo(de: Self.texto(periodo.de), ate: Self.texto(periodo.ate)))
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("historico-resumo-periodo")
            } else {
                AvisoFrila(verbatim: model.excedeLimite ? TextosHistoricoDeTurnos.intervaloMaximoExcedido : TextosHistoricoDeTurnos.periodoInvalido, tom: .alerta)
                    .accessibilityIdentifier("historico-periodo-invalido")
            }
        }
        .disabled(model.estaCarregando)
    }

    private var esteMes: some View {
        FiltroPill(verbatim: TextosHistoricoDeTurnos.esteMes, selecionado: model.atalho == .esteMes) { model.escolher(.esteMes) }
            .accessibilityIdentifier("historico-este-mes")
    }

    private var mesPassado: some View {
        FiltroPill(verbatim: TextosHistoricoDeTurnos.mesPassado, selecionado: model.atalho == .mesPassado) { model.escolher(.mesPassado) }
            .accessibilityIdentifier("historico-mes-passado")
    }

    private var intervalo: some View {
        FiltroPill(verbatim: TextosHistoricoDeTurnos.intervalo, selecionado: model.atalho == .intervalo) { model.escolher(.intervalo) }
            .accessibilityIdentifier("historico-intervalo")
    }

    /// O rótulo fica fora do seletor para acompanhar o Dynamic Type inteiro; o seletor compacto
    /// para em `accessibility1`, como em Publicar vaga. Os dias são os de São Paulo.
    private func seletorDeData(
        _ titulo: String,
        selecao: Binding<Date>,
        faixa: PartialRangeThrough<Date>,
        identificador: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo).font(.subheadline)
            DatePicker(titulo, selection: selecao, in: faixa, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .environment(\.timeZone, FormatadorFrila.fuso)
                .environment(\.locale, FormatadorFrila.locale)
                .accessibilityIdentifier(identificador)
        }
    }

    private var inicio: Binding<Date> {
        Binding(get: { model.inicioEscolhido }, set: { model.escolher(inicio: $0) })
    }

    private var fim: Binding<Date> {
        Binding(get: { model.fimEscolhido }, set: { model.escolher(fim: $0) })
    }

    // MARK: Formato

    private var secaoFormato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosHistoricoDeTurnos.formato)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                // O controle segmentado do sistema não acompanha o Dynamic Type: nos tamanhos de
                // acessibilidade os formatos viram pílulas, como as do período.
                HStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(FormatoExportacao.allCases, id: \.self) { formato in
                        FiltroPill(verbatim: formato.rawValue.uppercased(), selecionado: model.formato == formato) {
                            model.escolher(formato: formato)
                        }
                        .accessibilityIdentifier("historico-formato-\(formato.rawValue)")
                    }
                }
            } else {
                Picker(selection: Binding(get: { model.formato }, set: { model.escolher(formato: $0) })) {
                    ForEach(FormatoExportacao.allCases, id: \.self) { formato in
                        Text(verbatim: formato.rawValue.uppercased()).tag(formato)
                    }
                } label: {
                    Text(verbatim: TextosHistoricoDeTurnos.formato)
                }
                .pickerStyle(.segmented)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityIdentifier("historico-formato")
            }
        }
        .disabled(model.estaCarregando)
    }

    // MARK: Resultado

    @ViewBuilder
    private var resultado: some View {
        switch model.estado {
        case .semTurnos:
            AvisoFrila(verbatim: TextosHistoricoDeTurnos.semTurnos, tom: .informativo)
                .accessibilityIdentifier("historico-sem-turnos")
        case let .erro(mensagem, repetivel):
            AvisoFrila(verbatim: mensagem, tom: .erro)
                .accessibilityIdentifier("historico-erro")
            if repetivel {
                BotaoSecundario(verbatim: TextosHistoricoDeTurnos.tentarNovamente) {
                    Task { await model.exportar() }
                }
                .accessibilityIdentifier("historico-tentar-novamente")
            }
        case .ocioso, .carregando:
            EmptyView()
        }
    }

    /// O VoiceOver ouve o que mudou sem precisar procurar o aviso na tela.
    private func anunciar(_ estado: HistoricoDeTurnosViewModel.Estado) {
        let texto: String? = switch estado {
        case .carregando: TextosHistoricoDeTurnos.gerando
        case .semTurnos: TextosHistoricoDeTurnos.semTurnos
        case let .erro(mensagem, _): mensagem
        case .ocioso: nil
        }
        if let texto { AccessibilityNotification.Announcement(texto).post() }
    }

    private static func texto(_ dia: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", dia.dia, dia.mes, dia.ano)
    }
}
