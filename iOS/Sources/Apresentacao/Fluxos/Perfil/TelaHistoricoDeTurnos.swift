import FrilaDominio
import SwiftUI

/// Histórico de turnos (#23).
/// Desenho do sistema do Fabrício (extrapolado: a tela não está no protótipo). Período e formato são escolha única:
/// lista com visto, não chip. O resultado da exportação (sem turnos, erro) vem em `MensagemJuntoAoBotao` logo acima do
/// "Exportar", que fica ancorado embaixo.
public struct TelaHistoricoDeTurnos: View {
    @State private var model: HistoricoDeTurnosViewModel

    public init(api: any ApiCliente, estabelecimentoID: UUID? = nil) {
        _model = State(initialValue: HistoricoDeTurnosViewModel(api: api, estabelecimentoID: estabelecimentoID))
    }

    init(model: HistoricoDeTurnosViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text(verbatim: TextosHistoricoDeTurnos.explicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                secaoPeriodo
                secaoFormato
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo)
        .rodapeAncorado { rodape }
        .navigationTitle(Text(verbatim: TextosHistoricoDeTurnos.titulo))
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaGrupoDeLinhas(verbatim: TextosHistoricoDeTurnos.periodo, linhasComIcone: false) {
                FrilaLinhaDeOpcao(titulo: TextosHistoricoDeTurnos.esteMes, remate: .marcada(model.atalho == .esteMes)) {
                    model.escolher(.esteMes)
                }
                .accessibilityIdentifier("historico-este-mes")
                FrilaLinhaDeOpcao(titulo: TextosHistoricoDeTurnos.mesPassado, remate: .marcada(model.atalho == .mesPassado)) {
                    model.escolher(.mesPassado)
                }
                .accessibilityIdentifier("historico-mes-passado")
                FrilaLinhaDeOpcao(titulo: TextosHistoricoDeTurnos.intervalo, remate: .marcada(model.atalho == .intervalo)) {
                    model.escolher(.intervalo)
                }
                .accessibilityIdentifier("historico-intervalo")
            }
            if model.atalho == .intervalo {
                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    seletorDeData(TextosHistoricoDeTurnos.de, selecao: inicio, faixa: model.faixaDe, identificador: "historico-de")
                    seletorDeData(TextosHistoricoDeTurnos.ate, selecao: fim, faixa: model.faixaAte, identificador: "historico-ate")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartaoFrila()
            }
            if let periodo = model.periodo {
                Text(verbatim: TextosHistoricoDeTurnos.resumo(de: Self.texto(periodo.de), ate: Self.texto(periodo.ate)))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("historico-resumo-periodo")
            } else {
                AvisoFrila(verbatim: model.excedeLimite ? TextosHistoricoDeTurnos.intervaloMaximoExcedido : TextosHistoricoDeTurnos.periodoInvalido, tom: .alerta)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("historico-periodo-invalido")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(model.estaCarregando)
    }

    /// O rótulo fica fora do seletor para acompanhar o Dynamic Type inteiro; o seletor compacto
    /// para em `accessibility1`, como em Publicar vaga. Os dias são os de São Paulo.
    private func seletorDeData(
        _ titulo: String,
        selecao: Binding<Date>,
        faixa: ClosedRange<Date>,
        identificador: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
            DatePicker(titulo, selection: selecao, in: faixa, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .environment(\.timeZone, FormatadorFrila.fuso)
                .environment(\.locale, FormatadorFrila.locale)
                .accessibilityIdentifier(identificador)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inicio: Binding<Date> {
        Binding(get: { model.inicioEscolhido }, set: { model.escolher(inicio: $0) })
    }

    private var fim: Binding<Date> {
        Binding(get: { model.fimEscolhido }, set: { model.escolher(fim: $0) })
    }

    // MARK: Formato

    private var secaoFormato: some View {
        FrilaGrupoDeLinhas(verbatim: TextosHistoricoDeTurnos.formato, linhasComIcone: false) {
            ForEach(FormatoExportacao.allCases, id: \.self) { formato in
                FrilaLinhaDeOpcao(titulo: formato.rawValue.uppercased(), remate: .marcada(model.formato == formato)) {
                    model.escolher(formato: formato)
                }
                .accessibilityIdentifier("historico-formato-\(formato.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historico-formato")
        .disabled(model.estaCarregando)
    }

    // MARK: Rodapé (resultado e botão)

    /// O resultado da exportação logo acima do botão que a disparou: nada de turnos, ou o erro (com tentar de novo
    /// quando vale tentar).
    @ViewBuilder
    private var rodape: some View {
        switch model.estado {
        case .semTurnos:
            MensagemJuntoAoBotao(verbatim: TextosHistoricoDeTurnos.semTurnos)
                .accessibilityIdentifier("historico-sem-turnos")
        case let .erro(mensagem, repetivel):
            MensagemJuntoAoBotao(verbatim: mensagem)
                .accessibilityIdentifier("historico-erro")
            if repetivel {
                Button { Task { await model.exportar() } } label: { Text(verbatim: TextosHistoricoDeTurnos.tentarNovamente) }
                    .buttonStyle(.frilaLink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("historico-tentar-novamente")
            }
        case .ocioso, .carregando:
            EmptyView()
        }
        BotaoPrimario(verbatim: TextosHistoricoDeTurnos.exportar, carregando: model.estaCarregando) {
            Task { await model.exportar() }
        }
        .disabled(model.periodo == nil)
        .accessibilityHint(Text(verbatim: TextosHistoricoDeTurnos.dicaExportar))
        .accessibilityIdentifier("historico-exportar")
    }

    /// O VoiceOver ouve o que mudou sem precisar procurar o aviso na tela.
    private func anunciar(_ estado: HistoricoDeTurnosViewModel.Estado) {
        let texto: String? = switch estado {
        case .carregando: TextosHistoricoDeTurnos.gerando
        case .semTurnos, .erro, .ocioso: nil
        }
        if let texto { AccessibilityNotification.Announcement(texto).post() }
    }

    private static func texto(_ dia: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", dia.dia, dia.mes, dia.ano)
    }
}
