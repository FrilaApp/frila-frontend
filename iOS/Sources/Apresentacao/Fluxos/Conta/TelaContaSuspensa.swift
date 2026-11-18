import FrilaDominio
import SwiftUI

/// Conta suspensa (#105): o estado da suspensão, a contestação e, no fim, as ações de conta. O Fabrício não desenhou
/// esta tela: extrapolada do sistema da entrada (título em Prodigy, botão primário ancorado embaixo, o formulário com o
/// rótulo acima, as ações de risco como ação discreta no fim e sem cor de alerta).
public struct TelaContaSuspensa: View {
    @State private var mostrarConfirmacaoDeSaida = false
    @Bindable private var viewModel: ContaSuspensaViewModel
    @State private var exportarModel: ExportarDadosViewModel
    @FocusState private var focoNoRelato: Bool
    private let api: any ApiCliente

    public init(viewModel: ContaSuspensaViewModel, api: any ApiCliente) {
        self.viewModel = viewModel
        self.api = api
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }

    public var body: some View {
        conteudoDaTela
            .frilaKeyboardDismissScope()
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    /// Enquanto a contestação pode ser aberta ou enviada, o botão dela fica ancorado embaixo. Com o protocolo gravado
    /// (ou a contestação já aberta no servidor), não há ação que avance: sem rodapé.
    private var contestacaoEmAberto: Bool {
        viewModel.protocolo == nil && !viewModel.bloqueadoPor409
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    Text(verbatim: TextosContaSuspensa.titulo)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    avisoCabecalho
                    secaoMotivoESuspensao
                    secaoContestacao
                    secaoAcoes
                }
                .padding(.top, FrilaEspaco.item)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.secao)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            // O identificador da tela fica só na rolagem: no conjunto, ele trocaria o dos botões do rodapé.
            .accessibilityIdentifier("tela-conta-suspensa")
            .rodapeAncoradoQuando(contestacaoEmAberto) { rodape }
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.carregar() }
        }
    }

    private var avisoCabecalho: some View {
        AvisoFrila(verbatim: TextosContaSuspensa.avisoPrincipal, tom: .alerta)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("aviso-conta-suspensa")
    }

    private var secaoMotivoESuspensao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotuloDeSecao(TextosContaSuspensa.secaoMotivo)

            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: TextosContaSuspensa.motivoTitulo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: viewModel.motivo.isEmpty ? "—" : viewModel.motivo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("texto-motivo-suspensao")

            if let data = viewModel.dataSuspensao {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: TextosContaSuspensa.desdeTitulo)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    Text(verbatim: formatarData(data))
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("texto-data-suspensao")
            }

            Text(verbatim: TextosContaSuspensa.prazoAnaliseDescricao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cartaoFrila()
    }

    private func rotuloDeSecao(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var secaoContestacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotuloDeSecao(TextosContaSuspensa.secaoContestacao)

            if let explicacao409 = viewModel.avisoExplicacao409 {
                AvisoFrila(verbatim: explicacao409, tom: .alerta)
                    .accessibilityIdentifier("aviso-contestacao-ja-aberta")
            }

            if let protocolo = viewModel.protocolo {
                cartaoProtocolo(protocolo)
            } else if viewModel.bloqueadoPor409 {
                EmptyView()
            } else if viewModel.mostrarFormularioContestacao {
                formularioContestacao
            }

            // Com o botão ancorado embaixo, o erro vai junto dele; sem rodapé (protocolo gravado), fica aqui.
            if !contestacaoEmAberto, let erro = viewModel.mensagemErro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("aviso-erro-contestacao")
            }
        }
    }

    private func cartaoProtocolo(_ protocolo: Protocolo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Label {
                Text(verbatim: viewModel.emAnalise ? TextosContaSuspensa.emAnalise : TextosContaSuspensa.protocoloTitulo)
                    .font(FrilaTipo.rotuloSecundario)
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .foregroundStyle(FrilaCor.texto)
            .accessibilityIdentifier(viewModel.emAnalise ? "status-em-analise" : "status-contestacao-enviada")

            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: TextosContaSuspensa.protocoloNumero)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: protocolo.ocorrenciaID.uuidString)
                    .font(FrilaTipo.corpo.monospaced())
                    .foregroundStyle(FrilaCor.texto)
                    .speechSpellsOutCharacters(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("protocolo-contestacao")

            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: TextosContaSuspensa.protocoloData)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarData(protocolo.criadaEm))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: TextosContaSuspensa.prazoRespostaTitulo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("prazo-resposta-contestacao")

            Text(verbatim: viewModel.mensagemDoProtocolo)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, FrilaEspaco.junto)
                .accessibilityIdentifier("mensagem-protocolo-contestacao")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    /// O rótulo visível acima do campo é da tela; o campo é uma caixa de várias linhas, com a dica dentro.
    private var formularioContestacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosContaSuspensa.labelRelato)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosContaSuspensa.promptRelato).foregroundStyle(FrilaCor.textoSecundario),
                axis: .vertical
            ) {
                Text(verbatim: TextosContaSuspensa.labelRelato)
            }
            .lineLimit(4...8)
            .textFieldStyle(.plain)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .caixaDoCampoFrila(emFoco: focoNoRelato)
            .focused($focoNoRelato)
            .accessibilityIdentifier("campo-relato-contestacao")
            .frilaFormField(id: "contestacao-relato", isFocused: focoNoRelato, onDismiss: { focoNoRelato = false })

            HStack(spacing: FrilaEspaco.item) {
                if viewModel.relatoValido {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityIdentifier("icone-relato-valido-contestacao")
                }
                Text(verbatim: TextosContaSuspensa.dicaRelato)
                    .font(FrilaTipo.legenda)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10")
                    .font(FrilaTipo.legenda.monospacedDigit())
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-contestacao")
                    .accessibilityLabel(Text(verbatim: viewModel.relatoValido ? TextosContaSuspensa.relatoValidoAcessibilidade : "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10"))
            }
        }
    }

    /// Ancorado embaixo: o erro da contestação, o botão que avança (um só laranja) e, no formulário, o Cancelar.
    @ViewBuilder
    private var rodape: some View {
        if let erro = viewModel.mensagemErro {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("aviso-erro-contestacao")
        }
        if viewModel.mostrarFormularioContestacao {
            BotaoPrimario(
                verbatim: TextosContaSuspensa.botaoEnviar,
                carregando: viewModel.enviandoContestacao
            ) {
                Task { await viewModel.enviarContestacao() }
            }
            .accessibilityIdentifier("botao-enviar-contestacao")

            BotaoSecundario(verbatim: TextosContaSuspensa.cancelar) {
                viewModel.cancelarFormularioContestacao()
            }
            .accessibilityIdentifier("botao-cancelar-contestacao")
        } else {
            BotaoPrimario(verbatim: TextosContaSuspensa.botaoContestar) {
                viewModel.abrirFormularioContestacao()
            }
            .accessibilityIdentifier("botao-contestar-suspensao")
        }
    }

    /// Exportar não é risco; excluir e sair são ações discretas, no fim, uma por linha.
    private var secaoAcoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotuloDeSecao(TextosContaSuspensa.secaoAcoes)

            ItemExportarDados(viewModel: exportarModel, identificador: "conta-suspensa-exportar-dados")

            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    TelaExclusaoDeConta(
                        viewModel: ExclusaoDeContaViewModel(
                            api: api,
                            aoConcluir: viewModel.executarSair
                        )
                    )
                } label: {
                    Text(verbatim: TextosContaSuspensa.excluir)
                }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityIdentifier("conta-suspensa-excluir-conta")

                Button {
                    mostrarConfirmacaoDeSaida = true
                } label: {
                    Text(verbatim: TextosContaSuspensa.sair)
                }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityIdentifier("conta-suspensa-sair")
            }
            .padding(.top, FrilaEspaco.item)
        }
    }

    private func formatarData(_ data: Date) -> String {
        let formatador = DateFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.timeZone = FormatadorFrila.fuso
        formatador.dateFormat = "dd/MM/yyyy"
        return formatador.string(from: data)
    }

    private func formatarDataCivil(_ data: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", data.dia, data.mes, data.ano)
    }

    /// Mesmo padrão da exclusão de conta: título rolável e ações fixas, Cancelar primeiro. Sair é ação de risco: no
    /// desenho do botão secundário, sem vermelho.
    private var confirmacaoDeSaida: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, FrilaEspaco.grupo)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.grupo)
        }
        .rodapeAncorado {
            BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                mostrarConfirmacaoDeSaida = false
            }
            .accessibilityIdentifier("botao-cancelar-saida-dialogo")

            Button(role: .destructive) {
                mostrarConfirmacaoDeSaida = false
                viewModel.executarSair()
            } label: {
                Text("Sair", bundle: bundleApresentacao)
                    .capsulaDestrutiva()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botao-confirmar-saida-dialogo")
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    /// O rodapé ancorado só enquanto há ação que avança; sem ela, a tela fica sem a barra de baixo.
    @ViewBuilder
    func rodapeAncoradoQuando<Conteudo: View>(_ ativo: Bool, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        if ativo {
            rodapeAncorado(conteudo)
        } else {
            self
        }
    }
}
