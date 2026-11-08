import FrilaDominio
import SwiftUI

/// "Por que recebo vagas" (RF27), com critérios em lista aberta do Hi-Fi e o pedido de revisão.
/// A folha de Meu perfil fornece a pilha de navegação e o Fechar.
public struct TelaPorQueReceboVagas: View {
    /// Em `@State`, e não `@Bindable`: a folha de Meu perfil recria esta view a cada re-render do
    /// perfil, e o view model criado no `init` tem de sobreviver a isso para a carga da `.task`
    /// chegar à tela.
    @State private var viewModel: PorQueReceboVagasViewModel
    @FocusState private var focoNoRelato: Bool

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
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("perfil-explicacao-vagas")
                    .frame(maxWidth: .infinity, alignment: .leading)
                criterios
                secaoContestar
            }
            .padding(FrilaEspaco.medio)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
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
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityLabel(Text(verbatim: titulo))
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FrilaEspaco.medio)
        .overlay(alignment: .bottom) { DivisoriaDeLinha() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identificador)
    }

    private func linha(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nota(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.nota)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Contestar

    private var secaoContestar: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPorQueReceboVagas.secaoContestar)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityLabel(Text(verbatim: TextosPorQueReceboVagas.secaoContestar))
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let protocolo = viewModel.protocolo {
                cartaoProtocolo(protocolo)
            } else if viewModel.contestacaoJaAberta {
                AvisoFrila(verbatim: TextosPorQueReceboVagas.contestacaoJaAberta, tom: .informativo)
                    .accessibilityIdentifier("status-revisao-ja-aberta")
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
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosPorQueReceboVagas.promptRelato),
                axis: .vertical
            ) {
                Text(verbatim: TextosPorQueReceboVagas.labelRelato)
            }
            .lineLimit(4...8)
            .textFieldStyle(.plain)
            .font(FrilaTipo.valorDoCampo)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
            .focused($focoNoRelato)
            .accessibilityIdentifier("campo-relato-despacho")
            .frilaFormField(id: "despacho-relato", isFocused: focoNoRelato, onDismiss: { focoNoRelato = false })

            HStack {
                if viewModel.relatoValido {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.sucesso)
                        .accessibilityIdentifier("icone-relato-valido-despacho")
                }
                Text(verbatim: TextosPorQueReceboVagas.dicaRelato)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                Spacer()
                // V24: o 10 é o mínimo, não um limite. Acima dele o contador para em "10/10",
                // com o visto verde, em vez de "40/10", que parecia ter passado do limite.
                Text(verbatim: Self.contador(viewModel.relato))
                    .font(FrilaTipo.nota.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.sucesso : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-despacho")
                    .accessibilityLabel(Text(verbatim: viewModel.relatoValido ? TextosPorQueReceboVagas.relatoValidoAcessibilidade : Self.contador(viewModel.relato)))
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

    /// Os dois botões empilhados em todos os tamanhos: lado a lado, "Enviar pedido" já quebrava em
    /// duas linhas no tamanho padrão (V24 da conferência visual da 1.1), e em AX se estrangulavam
    /// (QA do #105 na conta suspensa).
    private var layoutDosBotoes: AnyLayout { AnyLayout(VStackLayout(spacing: FrilaEspaco.pequeno)) }

    /// Caracteres do relato até o mínimo de 10: "3/10" e, a partir dele, "10/10".
    static func contador(_ relato: String) -> String {
        "\(min(relato.trimmingCharacters(in: .whitespacesAndNewlines).count, 10))/10"
    }

    private func cartaoProtocolo(_ protocolo: Protocolo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Label {
                Text(verbatim: TextosPorQueReceboVagas.pedidoEnviado)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle")
            }
            .foregroundStyle(FrilaCor.sucesso)
            .accessibilityIdentifier("status-revisao-enviada")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.protocoloNumero)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                // V23: o UUID inteiro quebrava deixando um "3" sozinho na linha. O número que o
                // suporte usa é o curto (contrato 0.2.40), o mesmo da Ajuda no turno: "#A0000000".
                Text(verbatim: "#" + protocolo.protocoloCurto)
                    .font(FrilaTipo.meta.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("protocolo-revisao-despacho")
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.protocoloData)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: Self.formatarData(protocolo.criadaEm))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosPorQueReceboVagas.prazoRespostaTitulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: Self.formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
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
