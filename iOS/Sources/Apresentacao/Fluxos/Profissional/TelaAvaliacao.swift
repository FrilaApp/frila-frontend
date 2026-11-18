import FrilaDominio
import SwiftUI

/// Avaliação do turno (T5 do protótipo): a pergunta é o título da tela, a escolha Sim ou Não vem logo abaixo, com nada
/// marcado, e a nota de apoio fica num cartão. O app grava um voto por lado do turno, então o envio é o botão primário
/// ancorado no pé, com o resultado em tinta acima dele; depois de gravada, a resposta não troca.
public struct TelaAvaliacao: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: AvaliacaoTurnoViewModel

    public init(viewModel: AvaliacaoTurnoViewModel) {
        self.viewModel = viewModel
    }

    public init(
        turnoID: UUID,
        contaID: UUID,
        turno: Turno? = nil,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        armazenamento: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        pergunta: String? = nil,
        explicacao: String? = nil
    ) {
        self.init(viewModel: AvaliacaoTurnoViewModel(
            turnoID: turnoID,
            contaID: contaID,
            turno: turno,
            api: api,
            fila: fila,
            armazenamento: armazenamento,
            relogio: relogio,
            pergunta: pergunta,
            explicacao: explicacao
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
                areaDeEscolha
                cartaoExplicacao
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .rodapeAncorado {
            avisosDeEstado
            botaoDeAcao
        }
        .navigationTitle(Text(verbatim: TextosDoProfissional.Avaliacao.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await viewModel.carregar() }
        }
        .accessibilityIdentifier("tela-avaliacao")
    }

    private var cabecalho: some View {
        Text(verbatim: viewModel.pergunta)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pergunta-avaliacao")
    }

    private var cartaoExplicacao: some View {
        Text(verbatim: viewModel.explicacao)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("explicacao-avaliacao")
    }

    private var areaDeEscolha: some View {
        EscolhaSimNao(resposta: $viewModel.resposta, rotuloDaPergunta: viewModel.pergunta)
            .disabled(viewModel.jaAvaliado || viewModel.salvando)
    }

    /// O resultado do envio, em tinta e logo acima do botão que o disparou (DESIGN.md, "Mensagem junto ao botão").
    @ViewBuilder
    private var avisosDeEstado: some View {
        if viewModel.jaAvaliado && !viewModel.sucesso {
            MensagemJuntoAoBotao(verbatim: TextosDoProfissional.Avaliacao.erroJaRegistrada)
                .accessibilityIdentifier("aviso-ja-avaliado")
        }

        if let sucesso = viewModel.mensagemDeSucesso {
            MensagemJuntoAoBotao(verbatim: sucesso)
                .accessibilityIdentifier("aviso-sucesso-avaliacao")
        }

        if let erro = viewModel.mensagemDeErro {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("aviso-erro-avaliacao")
            if viewModel.recusaDaFila != nil {
                BotaoSecundario("Fechar") { Task { await viewModel.fecharAvisoDaFila() } }
                    .accessibilityIdentifier("fechar-aviso-avaliacao-recusada")
            }
        }
    }

    @ViewBuilder
    private var botaoDeAcao: some View {
        if viewModel.sucesso {
            BotaoPrimario(
                verbatim: TextosDoProfissional.Avaliacao.botaoConcluir
            ) {
                dismiss()
            }
            .accessibilityIdentifier("botao-concluir-avaliacao")
        } else if !viewModel.jaAvaliado {
            if viewModel.resposta == nil {
                Text(verbatim: TextosDoProfissional.Avaliacao.dicaEscolhaResposta)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dica-escolha-resposta-avaliacao")
            }

            BotaoPrimario(
                verbatim: TextosDoProfissional.Avaliacao.botaoEnviar,
                carregando: viewModel.salvando
            ) {
                Task {
                    _ = await viewModel.salvar()
                }
            }
            .disabled(viewModel.resposta == nil || viewModel.salvando)
            .accessibilityIdentifier("botao-enviar-avaliacao")
        }
    }
}

/// A escolha binária do protótipo (T5): dois botões lado a lado, de 48 pt, com o visual do botão secundário; o marcado
/// vira o chip marcado (tinta com texto branco e um visto). Nada vem marcado, e as opções são exclusivas. Com texto
/// grande os botões ficam um sobre o outro. Desligada (resposta já gravada), a escolha continua legível.
private struct EscolhaSimNao: View {
    @Binding var resposta: Bool?
    let rotuloDaPergunta: String
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        let layout = tamanhoDoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FrilaEspaco.item))
            : AnyLayout(HStackLayout(spacing: FrilaEspaco.item))
        layout {
            opcao("Sim", valor: true)
            opcao("Não", valor: false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: rotuloDaPergunta))
    }

    private func opcao(_ titulo: LocalizedStringKey, valor: Bool) -> some View {
        let marcada = resposta == valor
        let forma = FrilaForma.capsulaQueCresce()
        return Button { resposta = valor } label: {
            HStack(spacing: FrilaEspaco.junto) {
                if marcada {
                    Image(systemName: "checkmark")
                        .accessibilityIdentifier(valor ? "icone-checkmark-sim" : "icone-checkmark-nao")
                }
                Text(titulo, bundle: bundleApresentacao)
            }
            .font(FrilaTipo.rotuloSecundario)
            .multilineTextAlignment(.center)
            .padding(.horizontal, FrilaEspaco.bloco)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(marcada ? FrilaCor.sobreSelecao : FrilaCor.texto)
            .background(marcada ? FrilaCor.selecao : FrilaCor.superficie, in: forma)
            .overlay(forma.strokeBorder(marcada ? Color.clear : FrilaCor.borda, lineWidth: 1))
            .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento, somenteOpacidade: true), value: resposta)
            .contentShape(forma)
        }
        .buttonStyle(SemEfeitoDeEstilo())
        .accessibilityLabel(Text(titulo, bundle: bundleApresentacao))
        .accessibilityValue(FrilaAcessibilidade.textoSelecao(selecionado: marcada))
        .accessibilityAddTraits(marcada ? .isSelected : [])
        .accessibilityIdentifier(valor ? "resposta-sim" : "resposta-nao")
    }
}

/// O botão sem estilo próprio: o desenho é todo do rótulo, e desligado ele não esmaece (a resposta gravada segue legível).
private struct SemEfeitoDeEstilo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
