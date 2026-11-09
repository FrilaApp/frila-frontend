import FrilaDominio
import SwiftUI

/// Avaliação do turno pelo profissional (T5 do protótipo): pergunta no título em Prodigy Sans,
/// escolha binária Sim/Não que grava no toque, link para vagas após resposta, card de status
/// com linha de etapas concluída e reputação de apoio.
public struct TelaAvaliacao: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
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
                // Ilustração doodle de cabeçalho (342×112)
                DoodleEspacoReservado()
                    .accessibilityIdentifier("ilustracao-avaliacao")

                // Pergunta como título da tela
                Text(verbatim: viewModel.pergunta)
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("pergunta-avaliacao")

                // Escolha binária: Sim, com certeza / Não
                areaDeEscolha

                // Ação de envio e conclusão
                botaoDeAcao

                // Avisos de estado da API / fila offline
                avisosDeEstado

                // Card de status do turno
                cardDoTurno

                // Reputação em apoio abaixo do card
                Text("Sua reputação: 98% das casas chamariam de novo", bundle: bundleApresentacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("explicacao-avaliacao")
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.enorme)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosDoProfissional.Avaliacao.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await viewModel.carregar() }
        }
        .accessibilityIdentifier("tela-avaliacao")
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
        } else if viewModel.sucesso {
            AvisoFrila(verbatim: TextosDoProfissional.Avaliacao.avaliadoSucesso, tom: .informativo)
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

    private var cardDoTurno: some View {
        let formatador = FormatadorFrila()
        let nomeCasa = viewModel.turno?.contraparte.nome ?? "Bar do Porto"
        let dataTexto: String
        let horarioTexto: String
        if let turno = viewModel.turno {
            dataTexto = FormatoDataVaga.diaMes(turno.vaga.periodo.inicio)
            horarioTexto = "\(formatador.hora(turno.vaga.periodo.inicio)) às \(formatador.hora(turno.vaga.periodo.fim))"
        } else {
            dataTexto = "Sáb 14/11"
            horarioTexto = "18:00 às 00:00"
        }
        let valor: String
        if let turno = viewModel.turno {
            valor = formatador.dinheiro(turno.valorAcordado)
        } else {
            valor = "R$ 220,00"
        }

        return CardStatusTurno(
            selo: "Concluído",
            estiloDoSelo: .contorno,
            nomeDaCasa: nomeCasa,
            dataTexto: dataTexto,
            horarioTexto: horarioTexto,
            etapaAtual: .concluido,
            valorFormatado: valor
        )
    }
}
