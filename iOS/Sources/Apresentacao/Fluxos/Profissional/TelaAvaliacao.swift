import FrilaDominio
import SwiftUI

/// Avaliação do turno pelo profissional, no quadro "AvaliarLocal" do MidFi do Fabrício: pergunta em
/// título grande, resposta Sim/Não, nota de apoio em cartão e botão escuro de envio.
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
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                cabecalho
                areaDeEscolha
                cartaoExplicacao
                avisosDeEstado
                botaoDeAcao
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
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
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.minimo)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pergunta-avaliacao")
    }

    private var cartaoExplicacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Label {
                Text(verbatim: viewModel.explicacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } icon: {
                Image(systemName: "hand.thumbsup.fill")
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("explicacao-avaliacao")
    }

    private var areaDeEscolha: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            RespostaSimNao(
                resposta: $viewModel.resposta,
                verbatim: viewModel.pergunta
            )
            .disabled(viewModel.jaAvaliado || viewModel.salvando)
        }
    }

    @ViewBuilder
    private var avisosDeEstado: some View {
        if viewModel.jaAvaliado && !viewModel.sucesso {
            AvisoFrila(
                verbatim: TextosDoProfissional.Avaliacao.erroJaRegistrada,
                tom: .informativo
            )
            .accessibilityIdentifier("aviso-ja-avaliado")
        }

        if let sucesso = viewModel.mensagemDeSucesso {
            AvisoFrila(verbatim: sucesso, tom: .informativo)
                .accessibilityIdentifier("aviso-sucesso-avaliacao")
        }

        if let erro = viewModel.mensagemDeErro {
            AvisoFrila(verbatim: erro, tom: .erro)
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
            VStack(spacing: FrilaEspaco.pequeno) {
                if viewModel.resposta == nil {
                    Text(verbatim: TextosDoProfissional.Avaliacao.dicaEscolhaResposta)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .center)
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
}
