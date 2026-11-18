import FrilaDominio
import SwiftUI

/// O código de chegada na tela do turno da casa: 6 dígitos grandes legíveis, contagem regressiva da
/// validade emitida pelo servidor e estados informativos de chegada e encerramento.
/// Renova automaticamente no zero do relógio monotônico. Nesta primeira etapa, não inclui QR code.
///
/// Desenho (R6): o código é o dado principal do cartão. Fica numa caixa de preenchimento neutro, centralizado, no
/// maior tamanho de texto do sistema, e é o único lugar do app com dígitos tabulares. O cartão é um bloco próprio da
/// tela do turno, sem laranja: quem avança é o "Confirmar presença" ancorado embaixo.
public struct CartaoDoCodigoDaCasa: View {
    private typealias Textos = TextosDoCheckinPorCodigoCasa

    public let viewModel: CodigoDaCasaViewModel

    public init(viewModel: CodigoDaCasaViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: Textos.titulo)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cartao-codigo-da-casa")
        .task {
            await viewModel.carregar()
            var segundos = 0
            // Passo a cada segundo com relógio monotônico e verificação periódica de confirmação.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                segundos += 1
                await viewModel.passo()
                if segundos % 5 == 0 {
                    await viewModel.verificarConfirmacao()
                }
            }
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .carregando:
            apoio(Textos.carregando)
        case .semCodigoParaEsteCheckin:
            AvisoFrila(verbatim: Textos.semCodigoParaEsteCheckin, tom: .informativo)
                .accessibilityIdentifier("codigo-da-casa-sem-codigo-para-o-checkin")
        case let .mostrando(codigo):
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text(verbatim: Textos.explicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                // 6 dígitos grandes legíveis em AX5 (uma linha que encolhe até 40% em vez de quebrar os dígitos).
                Text(verbatim: codigo)
                    .font(Font.largeTitle.weight(.semibold).monospacedDigit())
                    .tracking(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FrilaEspaco.grupo)
                    .padding(.horizontal, FrilaEspaco.bloco)
                    .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous))
                    .accessibilityLabel(Text(verbatim: Textos.codigoPorExtenso(codigo)))
                    .accessibilityIdentifier("codigo-da-casa")
                if viewModel.renovando {
                    apoio(Textos.gerandoOutro).frame(maxWidth: .infinity)
                } else {
                    Text(verbatim: Textos.validade(CodigoDaCasaViewModel.formatar(segundos: viewModel.segundosRestantes)))
                        .font(FrilaTipo.apoio.monospacedDigit())
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("validade-do-codigo-da-casa")
                }
            }
        case .foraDaJanela:
            AvisoFrila(verbatim: Textos.foraDaJanela, tom: .informativo)
                .accessibilityIdentifier("codigo-da-casa-fora-da-janela")
        case .encerrado:
            AvisoFrila(verbatim: Textos.encerrado, tom: .informativo)
                .accessibilityIdentifier("codigo-da-casa-encerrado")
        case .falhou:
            // O erro da ação fica logo acima do botão que tenta de novo.
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                MensagemJuntoAoBotao(verbatim: Textos.falhou)
                    .accessibilityIdentifier("codigo-da-casa-falhou")
                BotaoSecundario(verbatim: Textos.tentarDeNovo) {
                    Task { await viewModel.tentarDeNovo() }
                }
                .accessibilityIdentifier("tentar-codigo-da-casa")
            }
        case .indisponivel, .jaVerificado:
            EmptyView()
        }
    }

    /// Texto de espera, sem indicador girando: o texto já diz o que está acontecendo.
    private func apoio(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}
