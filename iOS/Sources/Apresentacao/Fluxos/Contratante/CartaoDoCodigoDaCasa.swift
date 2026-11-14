import FrilaDominio
import SwiftUI

/// O código de chegada na tela do turno da casa: 6 dígitos grandes legíveis, contagem regressiva da
/// validade emitida pelo servidor e estados informativos de chegada e encerramento.
/// Renova automaticamente no zero do relógio monotônico. Nesta primeira etapa, não inclui QR code.
public struct CartaoDoCodigoDaCasa: View {
    private typealias Textos = TextosDoCheckinPorCodigoCasa

    public let viewModel: CodigoDaCasaViewModel

    public init(viewModel: CodigoDaCasaViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: Textos.titulo)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            progresso(Textos.carregando)
        case .semCodigoParaEsteCheckin:
            AvisoFrila(verbatim: Textos.semCodigoParaEsteCheckin, tom: .informativo)
                .accessibilityIdentifier("codigo-da-casa-sem-codigo-para-o-checkin")
        case let .mostrando(codigo):
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: Textos.explicacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                // 6 dígitos grandes legíveis em AX5 (uma linha que encolhe até 40% em vez de quebrar os dígitos).
                Text(verbatim: codigo)
                    .font(FrilaTipo.valorEmDestaque.monospacedDigit())
                    .tracking(4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(verbatim: Textos.codigoPorExtenso(codigo)))
                    .accessibilityIdentifier("codigo-da-casa")
                if viewModel.renovando {
                    progresso(Textos.gerandoOutro)
                } else {
                    Text(verbatim: Textos.validade(CodigoDaCasaViewModel.formatar(segundos: viewModel.segundosRestantes)))
                        .font(FrilaTipo.meta.monospacedDigit())
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
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                AvisoFrila(verbatim: Textos.falhou, tom: .erro)
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

    private func progresso(_ texto: String) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            ProgressView()
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
