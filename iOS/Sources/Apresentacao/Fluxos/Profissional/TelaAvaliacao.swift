import FrilaDominio
import SwiftUI

public struct TelaAvaliacao: View {
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
        .accessibilityIdentifier("tela-avaliacao")
    }

    private var cabecalho: some View {
        Text(verbatim: viewModel.pergunta)
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pergunta-avaliacao")
    }

    private var cartaoExplicacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Label {
                Text(verbatim: viewModel.explicacao)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } icon: {
                Image(systemName: "hand.thumbsup.fill")
                    .foregroundStyle(FrilaCor.primaria)
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
        }
    }

    @ViewBuilder
    private var botaoDeAcao: some View {
        if !viewModel.jaAvaliado {
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
