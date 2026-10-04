import FrilaDominio
import SwiftUI

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
    }

    private var secaoMotivoESuspensao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.secaoMotivo)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.motivoTitulo)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: viewModel.motivo.isEmpty ? "—" : viewModel.motivo)
                    .font(.body)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("texto-motivo-suspensao")
            }

            if let data = viewModel.dataSuspensao {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosContaSuspensa.desdeTitulo)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    Text(verbatim: formatarData(data))
                        .font(.subheadline)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityIdentifier("texto-data-suspensao")
                }
            }

            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(FrilaCor.primaria)
                    .accessibilityHidden(true)
                Text(verbatim: TextosContaSuspensa.prazoAnaliseDescricao)
                    .font(.caption)
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
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

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
                    Text(verbatim: TextosContaSuspensa.emAnalise)
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .foregroundStyle(FrilaCor.alerta)
                Spacer()
            }
            .accessibilityIdentifier("status-em-analise")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.protocoloNumero)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: protocolo.ocorrenciaID.uuidString)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("protocolo-contestacao")
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.protocoloData)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarData(protocolo.criadaEm))
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.texto)
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosContaSuspensa.prazoRespostaTitulo)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrilaCor.primaria)
                    .accessibilityIdentifier("prazo-resposta-contestacao")
            }

            Text(verbatim: TextosContaSuspensa.mensagemEmAnalise)
                .font(.caption)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.top, FrilaEspaco.minimo)
        }
    }

    private var formularioContestacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosContaSuspensa.labelRelato)
                .font(.subheadline.weight(.medium))
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
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.borda))
            .accessibilityIdentifier("campo-relato-contestacao")

            HStack {
                Text(verbatim: TextosContaSuspensa.dicaRelato)
                    .font(.caption)
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
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
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            ItemExportarDados(viewModel: exportarModel, identificador: "conta-suspensa-exportar-dados")

            NavigationLink {
                TelaExclusaoDeConta(
                    viewModel: ExclusaoDeContaViewModel(
                        api: api,
                        aoConcluir: viewModel.executarSair
                    )
                )
            } label: {
                Label {
                    Text(verbatim: TextosContaSuspensa.excluir)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .accessibilityIdentifier("conta-suspensa-excluir-conta")

            Button {
                viewModel.executarSair()
            } label: {
                Label {
                    Text(verbatim: TextosContaSuspensa.sair)
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .accessibilityIdentifier("conta-suspensa-sair")
        }
        .cartaoFrila()
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
