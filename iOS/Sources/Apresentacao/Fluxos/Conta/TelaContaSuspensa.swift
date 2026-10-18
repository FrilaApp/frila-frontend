import FrilaDominio
import SwiftUI

/// Conta suspensa (#105), no estilo dos quadros "ContaContratante" e "ExcluirConta" do MidFi do Fabrício: aviso neutro, cartões agrupados e ações em linhas com chevron.
public struct TelaContaSuspensa: View {
    @Bindable private var viewModel: ContaSuspensaViewModel
    @State private var exportarModel: ExportarDadosViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let api: any ApiCliente

    public init(viewModel: ContaSuspensaViewModel, api: any ApiCliente) {
        self.viewModel = viewModel
        self.api = api
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    avisoCabecalho
                    secaoMotivoESuspensao
                    secaoContestacao
                    secaoAcoes
                }
                .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosContaSuspensa.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.carregar() }
            .accessibilityIdentifier("tela-conta-suspensa")
        }
    }

    private var avisoCabecalho: some View {
        AvisoFrila(verbatim: TextosContaSuspensa.avisoPrincipal, tom: .alerta)
            .accessibilityIdentifier("aviso-conta-suspensa")
            .accessibilityElement(children: .combine)
    }

    private var secaoMotivoESuspensao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.secaoMotivo)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.motivoTitulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: viewModel.motivo.isEmpty ? "—" : viewModel.motivo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("texto-motivo-suspensao")
            }
            .accessibilityElement(children: .combine)

            if let data = viewModel.dataSuspensao {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosContaSuspensa.desdeTitulo)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    Text(verbatim: formatarData(data))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityIdentifier("texto-data-suspensao")
                }
                .accessibilityElement(children: .combine)
            }

            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
                Text(verbatim: TextosContaSuspensa.prazoAnaliseDescricao)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(.top, FrilaEspaco.minimo)
        }
        .cartaoFrila()
    }

    @ViewBuilder
    private var secaoContestacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.secaoContestacao)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

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
            } else {
                BotaoPrimario(verbatim: TextosContaSuspensa.botaoContestar) {
                    viewModel.abrirFormularioContestacao()
                }
                .accessibilityIdentifier("botao-contestar-suspensao")
            }

            if let erro = viewModel.mensagemErro {
                AvisoFrila(verbatim: erro, tom: .erro)
                    .accessibilityIdentifier("aviso-erro-contestacao")
            }
        }
        .cartaoFrila()
    }

    private func cartaoProtocolo(_ protocolo: Protocolo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack {
                Label {
                    Text(verbatim: viewModel.emAnalise ? TextosContaSuspensa.emAnalise : TextosContaSuspensa.protocoloTitulo)
                        .font(FrilaTipo.meta.weight(.semibold))
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .foregroundStyle(FrilaCor.alerta)
                Spacer()
            }
            .accessibilityIdentifier(viewModel.emAnalise ? "status-em-analise" : "status-contestacao-enviada")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.protocoloNumero)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: protocolo.ocorrenciaID.uuidString)
                    .font(FrilaTipo.meta.monospaced())
                    .foregroundStyle(FrilaCor.texto)
                    .speechSpellsOutCharacters(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("protocolo-contestacao")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.protocoloData)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarData(protocolo.criadaEm))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.prazoRespostaTitulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("prazo-resposta-contestacao")
            }
            .accessibilityElement(children: .combine)

            Text(verbatim: viewModel.mensagemDoProtocolo)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.top, FrilaEspaco.minimo)
                .accessibilityIdentifier("mensagem-protocolo-contestacao")
        }
    }

    private var formularioContestacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.labelRelato)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosContaSuspensa.promptRelato),
                axis: .vertical
            ) {
                Text(verbatim: TextosContaSuspensa.labelRelato)
            }
            .lineLimit(4...8)
            .textFieldStyle(.plain)
            .padding(FrilaEspaco.medio)
            .font(FrilaTipo.valorDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            .accessibilityIdentifier("campo-relato-contestacao")

            HStack {
                if viewModel.relatoValido {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.sucesso)
                        .accessibilityIdentifier("icone-relato-valido-contestacao")
                }
                Text(verbatim: TextosContaSuspensa.dicaRelato)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10")
                    .font(FrilaTipo.nota.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-contestacao")
                    .accessibilityLabel(Text(verbatim: viewModel.relatoValido ? TextosContaSuspensa.relatoValidoAcessibilidade : "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10"))
            }

            layoutDosBotoes {
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
            }
        }
    }

    /// Lado a lado, os dois botões se estrangulavam nos tamanhos de acessibilidade (QA do #105).
    /// `AnyLayout` em vez de `ViewThatFits`: o botão não troca de layout quando o título vira o
    /// indicador de envio, e a auditoria do XCTest não lê as duas cópias como fonte que não escala.
    private var layoutDosBotoes: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FrilaEspaco.pequeno))
            : AnyLayout(HStackLayout(spacing: FrilaEspaco.pequeno))
    }

    private var secaoAcoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.secaoAcoes)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            ItemExportarDados(viewModel: exportarModel, identificador: "conta-suspensa-exportar-dados")

            Divider().overlay(FrilaCor.divisoria)

            NavigationLink {
                TelaExclusaoDeConta(
                    viewModel: ExclusaoDeContaViewModel(
                        api: api,
                        aoConcluir: viewModel.executarSair
                    )
                )
            } label: {
                linhaDeAcao(TextosContaSuspensa.excluir, cor: FrilaCor.perigo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("conta-suspensa-excluir-conta")

            Divider().overlay(FrilaCor.divisoria)

            Button {
                viewModel.executarSair()
            } label: {
                linhaDeAcao(TextosContaSuspensa.sair, cor: FrilaCor.texto)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("conta-suspensa-sair")
        }
        .cartaoFrila()
    }

    /// Linha de lista do MidFi: texto à esquerda, chevron em `textoSecundario` à direita, 52 pt de altura mínima.
    private func linhaDeAcao(_ titulo: String, cor: Color) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(cor)
                .multilineTextAlignment(.leading)
            Spacer(minLength: FrilaEspaco.pequeno)
            Image(systemName: "chevron.right")
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
        .contentShape(Rectangle())
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
}
