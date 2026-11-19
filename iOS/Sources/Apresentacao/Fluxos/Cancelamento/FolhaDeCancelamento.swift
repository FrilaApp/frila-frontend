import FrilaDominio
import SwiftUI

/// A folha que pede o motivo e avisa o efeito antes de cancelar, igual para os dois lados (#20; T4b do protótipo).
/// Sem motivo, o botão não habilita. Depois da resposta, mostra o desfecho e só deixa fechar.
/// O título, a consequência, o motivo em lista de escolha única com visto e os botões ancorados no pé: o "Confirmar" é o
/// primário (em conferência até haver motivo) e o "Voltar", o secundário. Sem vermelho: a consequência vem escrita.
public struct FolhaDeCancelamento: View {
    @Bindable private var viewModel: CancelamentoViewModel
    private let fechar: () -> Void
    @FocusState private var focoNosDetalhes: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(viewModel: CancelamentoViewModel, fechar: @escaping () -> Void) {
        self.viewModel = viewModel
        self.fechar = fechar
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    Text(verbatim: TextosDoCancelamento.titulo(lado: viewModel.lado, alvo: viewModel.alvo))
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    switch viewModel.estado {
                    case .pronto, .enviando, .falha:
                        formulario
                    case let .concluido(desfecho):
                        desfechoView(desfecho)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: FrilaEspaco.item) { rodape }
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.grupo)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .modifier(RodapeAncoradoForaDeAX { rodape })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focoNosDetalhes = false
                    } label: {
                        Text(verbatim: TextosDoCancelamento.ok)
                    }
                    .accessibilityLabel(Text(verbatim: TextosDoCancelamento.recolherTeclado))
                    .accessibilityIdentifier("recolher-teclado")
                }
            }
        }
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
        .frilaKeyboardDismissScope()
        .accessibilityIdentifier("folha-de-cancelamento")
        .interactiveDismissDisabled(viewModel.estado == .enviando)
    }

    @ViewBuilder private var formulario: some View {
        AvisoFrila(verbatim: viewModel.aviso, tom: viewModel.contaComoFalta ? .alerta : .informativo)
            .accessibilityIdentifier("aviso-do-cancelamento")

        FrilaGrupoDeLinhas(verbatim: TextosDoCancelamento.motivoTitulo, linhasComIcone: false) {
            ForEach(viewModel.motivos) { motivo in
                opcao(motivo)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("motivos-do-cancelamento")

        if let motivo = viewModel.motivo {
            // O rótulo do campo é o mesmo do título: obrigatório em "Outro motivo", opcional nos demais.
            let rotulo = motivo.exigeDetalhes ? TextosDoCancelamento.detalhesObrigatorios : TextosDoCancelamento.detalhesTitulo
            let prompt = motivo.exigeDetalhes ? Text(verbatim: TextosDoCancelamento.placeholderDetalhes).foregroundStyle(FrilaCor.textoSecundario) : nil
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: rotulo)
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                TextField(text: $viewModel.detalhes, prompt: prompt, axis: .vertical) {
                    Text(verbatim: rotulo)
                }
                .lineLimit(2...5)
                .focused($focoNosDetalhes)
                .textFieldStyle(.plain)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .caixaDoCampoFrila(emFoco: focoNosDetalhes)
                .accessibilityIdentifier("detalhes-do-cancelamento")
                .frilaFormField(id: "cancelamento-detalhes", isFocused: focoNosDetalhes, onDismiss: { focoNosDetalhes = false })
            }
        } else {
            Text(verbatim: TextosDoCancelamento.motivoObrigatorio)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("motivo-obrigatorio")
        }
    }

    /// A falha da ação, em tinta e logo acima dos botões, e os botões: o "Confirmar" (primário) e o "Voltar" (secundário);
    /// depois do desfecho, só o "Fechar".
    @ViewBuilder private var rodape: some View {
        switch viewModel.estado {
        case .pronto, .enviando, .falha:
            if case let .falha(mensagem) = viewModel.estado {
                MensagemJuntoAoBotao(verbatim: mensagem)
                    .accessibilityLabel(Text(verbatim: AvisoFrila.rotuloAcessibilidade(texto: mensagem, tom: .erro)))
                    .accessibilityIdentifier("falha-do-cancelamento")
            }
            BotaoPrimario(verbatim: TextosDoCancelamento.confirmar, carregando: viewModel.estado == .enviando) {
                Task { await viewModel.confirmar() }
            }
            .disabled(!viewModel.podeConfirmar || viewModel.estado == .enviando)
            .accessibilityIdentifier("confirmar-cancelamento")

            BotaoSecundario(verbatim: TextosDoCancelamento.voltar, acao: fechar)
                .disabled(viewModel.estado == .enviando)
                .accessibilityIdentifier("voltar-do-cancelamento")
        case .concluido:
            BotaoPrimario(verbatim: TextosDoCancelamento.fechar, acao: fechar)
                .accessibilityIdentifier("fechar-cancelamento")
        }
    }

    /// Uma linha de escolha única: o visto em tinta só na escolhida, sem cor e sem fundo de cor.
    private func opcao(_ motivo: MotivoDeCancelamento) -> some View {
        let escolhido = viewModel.motivo == motivo
        return FrilaLinhaDeOpcao(titulo: TextosDoCancelamento.motivo(motivo), remate: .marcada(escolhido)) {
            viewModel.motivo = motivo
        }
        .accessibilityValue(FrilaAcessibilidade.textoSelecao(selecionado: escolhido))
        .accessibilityIdentifier("motivo-\(motivo.rawValue)")
    }

    @ViewBuilder private func desfechoView(_ desfecho: DesfechoDoCancelamento) -> some View {
        AvisoFrila(verbatim: TextosDoCancelamento.desfecho(desfecho, lado: viewModel.lado), tom: .informativo)
            .accessibilityIdentifier("desfecho-do-cancelamento")
        if case let .posicao(resultado) = desfecho, viewModel.lado == .profissional {
            Text(verbatim: resultado.falta ? TextosDoProfissional.Turnos.cancelamentoComFalta : TextosDoProfissional.Turnos.cancelamentoSemFalta)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("falta-do-cancelamento")
        }
    }
}

/// Botão de cancelamento (turno, posição ou vaga): ação discreta, sublinhada, no fim da tela e longe do botão primário.
/// O toque só abre a folha de cancelamento, nos dois lados; quem cancela é o "Confirmar" da folha.
public struct BotaoDeCancelamento: View {
    private let titulo: String
    private let acao: () -> Void

    public init(titulo: String, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            Text(verbatim: titulo)
        }
        .buttonStyle(.frilaAcaoDiscreta)
    }
}
