import FrilaDominio
import SwiftUI

/// "Por que recebo vagas" (RF27): o texto aprovado, os critérios reais e o pedido de revisão do
/// despacho. Vai dentro da folha de Meu perfil, que põe a pilha de navegação e o Fechar. Design
/// provisório, com os componentes base; o definitivo vem do design.
public struct TelaPorQueReceboVagas: View {
    /// Em `@State`, e não `@Bindable`: a folha de Meu perfil recria esta view a cada re-render do
    /// perfil, e o view model criado no `init` tem de sobreviver a isso para a carga da `.task`
    /// chegar à tela.
    @State private var viewModel: PorQueReceboVagasViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(viewModel: PorQueReceboVagasViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public init(api: any ApiCliente) {
        self.init(viewModel: PorQueReceboVagasViewModel(api: api))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosPerfilConta.explicacaoVagas)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("perfil-explicacao-vagas")
                    .frame(maxWidth: .infinity, alignment: .leading)
                criterios
                secaoContestar
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.porQueRecebo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .accessibilityIdentifier("tela-por-que-recebo")
    }

    // MARK: Critérios

    @ViewBuilder
    private var criterios: some View {
        switch viewModel.estado {
        case .carregando:
            EstadoCarregando()
        case .vazio:
            EstadoVazio(verbatim: TextosPorQueReceboVagas.vazioTitulo, mensagem: TextosPorQueReceboVagas.vazioMensagem)
                .accessibilityIdentifier("criterios-vazio")
        case .semRede:
            EstadoErro(verbatim: TextosPorQueReceboVagas.erroSemRede) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("criterios-sem-rede")
        case .erro:
            EstadoErro(verbatim: TextosPorQueReceboVagas.erroCarregar) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("criterios-erro")
        case let .conteudo(criterios):
            cartao(TextosPorQueReceboVagas.secaoFuncao, identificador: "criterios-funcoes") {
                if criterios.funcoes.isEmpty {
                    linha(TextosPorQueReceboVagas.semFuncao)
                } else {
                    ForEach(criterios.funcoes) { funcao in linha(funcao.nome) }
                }
            }
            cartao(TextosPorQueReceboVagas.secaoHorarios, identificador: "criterios-horarios") {
                if criterios.disponibilidades.isEmpty {
                    linha(TextosPorQueReceboVagas.semHorarios)
                } else {
                    ForEach(criterios.disponibilidades, id: \.self) { janela in
                        linha(PorQueReceboVagasViewModel.descricao(janela))
                    }
                    nota(TextosPorQueReceboVagas.horariosExplicacao)
                }
            }
            cartao(TextosPorQueReceboVagas.secaoDistancia, identificador: "criterios-distancia") {
                linha(PorQueReceboVagasViewModel.descricaoDistancia(criterios.distanciaMaximaKm))
            }
            cartao(TextosPorQueReceboVagas.secaoEquipes, identificador: "criterios-equipes") {
                if criterios.equipesDeConfianca.isEmpty {
                    linha(TextosPorQueReceboVagas.semEquipes)
                } else {
                    ForEach(criterios.equipesDeConfianca) { equipe in linha(equipe.nome) }
                    nota(TextosPorQueReceboVagas.equipesExplicacao)
                }
            }
            cartao(TextosPorQueReceboVagas.secaoFrequencia, identificador: "criterios-frequencia") {
                linha(TextosPorQueReceboVagas.frequencia(criterios.notificacoesNoMaximoACadaMin))
            }
        }
    }

    private func cartao(_ titulo: String, identificador: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identificador)
    }

    private func linha(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(.body)
            .foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nota(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(.caption)
            .foregroundStyle(FrilaCor.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Contestar

    private var secaoContestar: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPorQueReceboVagas.secaoContestar)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if let protocolo = viewModel.protocolo {
                cartaoProtocolo(protocolo)
            } else if viewModel.mostrarFormulario {
                formulario
            } else {
                nota(TextosPorQueReceboVagas.contestarExplicacao)
                BotaoPrimario(verbatim: TextosPorQueReceboVagas.botaoContestar) {
                    viewModel.abrirFormulario()
                }
                .accessibilityIdentifier("botao-contestar-despacho")
            }

            if let erro = viewModel.mensagemErro {
                AvisoFrila(verbatim: erro, tom: .erro)
                    .accessibilityIdentifier("aviso-erro-revisao")
            }
        }
        .cartaoFrila()
    }

    private var formulario: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPorQueReceboVagas.labelRelato)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FrilaCor.texto)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosPorQueReceboVagas.promptRelato),
                axis: .vertical
            ) {
                Text(verbatim: TextosPorQueReceboVagas.labelRelato)
            }
            .lineLimit(4...8)
            .textFieldStyle(.plain)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.borda))
            .accessibilityIdentifier("campo-relato-despacho")

            HStack {
                Text(verbatim: TextosPorQueReceboVagas.dicaRelato)
                    .font(.caption)
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)/10")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
            }

            layoutDosBotoes {
                BotaoPrimario(verbatim: TextosPorQueReceboVagas.botaoEnviar, carregando: viewModel.enviando) {
                    Task { await viewModel.contestar() }
                }
                .accessibilityIdentifier("botao-enviar-revisao")

                BotaoSecundario(verbatim: TextosPorQueReceboVagas.cancelar) {
                    viewModel.cancelarFormulario()
                }
                .accessibilityIdentifier("botao-cancelar-revisao")
            }
        }
    }

    /// Lado a lado, os dois botões se estrangulam nos tamanhos de acessibilidade (QA do #105 na
    /// conta suspensa): empilham em AX, pelo mesmo `AnyLayout` de `TelaContaSuspensa`.
    private var layoutDosBotoes: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FrilaEspaco.pequeno))
            : AnyLayout(HStackLayout(spacing: FrilaEspaco.pequeno))
    }

    private func cartaoProtocolo(_ protocolo: Protocolo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Label {
                Text(verbatim: TextosPorQueReceboVagas.pedidoEnviado)
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "checkmark.circle")
            }
            .foregroundStyle(FrilaCor.sucesso)
            .accessibilityIdentifier("status-revisao-enviada")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.protocoloNumero)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: protocolo.ocorrenciaID.uuidString)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("protocolo-revisao-despacho")
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.protocoloData)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: Self.formatarData(protocolo.criadaEm))
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.texto)
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.prazoRespostaTitulo)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: Self.formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrilaCor.primaria)
                    .accessibilityIdentifier("prazo-resposta-revisao")
            }

            nota(TextosPorQueReceboVagas.mensagemEnviado)
        }
    }

    private static func formatarData(_ data: Date) -> String {
        let formatador = DateFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.timeZone = FormatadorFrila.fuso
        formatador.dateFormat = "dd/MM/yyyy"
        return formatador.string(from: data)
    }

    private static func formatarDataCivil(_ data: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", data.dia, data.mes, data.ano)
    }
}
