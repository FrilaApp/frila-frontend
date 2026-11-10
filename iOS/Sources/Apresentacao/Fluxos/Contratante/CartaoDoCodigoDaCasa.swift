import FrilaDominio
import SwiftUI

/// O código de chegada na tela do turno da casa: os 6 dígitos grandes, o QR e a contagem do que resta,
/// já visíveis, sem navegação extra (desenho do check-in por código, seção 3). Renova sozinho quando vence.
struct CartaoDoCodigoDaCasa: View {
    private typealias Textos = TextosDoCheckinPorCodigo.Casa

    let viewModel: CodigoDaCasaViewModel
    private let tamanhoDoQR: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: Textos.titulo)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            conteudo
        }
        // Fica dentro do cartão "chegada" do turno: sem cartão dentro de cartão.
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cartao-codigo-da-casa")
        .task {
            await viewModel.carregar()
            // Um passo por segundo, no relógio monotônico; a contagem não anima, então Reduzir Movimento não pesa.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await viewModel.passo()
            }
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .carregando:
            progresso(Textos.carregando)
        case let .mostrando(codigo):
            Text(verbatim: Textos.explicacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            // 6 dígitos grandes, legíveis em AX5: uma linha, que encolhe até caber em vez de quebrar o número.
            Text(verbatim: codigo)
                .font(FrilaTipo.valorEmDestaque.monospacedDigit())
                .tracking(4)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(FrilaCor.texto)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(verbatim: Textos.codigoPorExtenso(codigo)))
                .accessibilityIdentifier("codigo-da-casa")
            if let qr = GeradorDeQRCode.imagem(para: codigo) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: tamanhoDoQR, height: tamanhoDoQR)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(verbatim: Textos.qrDoCodigo))
                    .accessibilityIdentifier("qr-do-codigo-da-casa")
            }
            if viewModel.renovando {
                progresso(Textos.gerandoOutro)
            } else {
                Text(verbatim: Textos.validade(CodigoDaCasaViewModel.formatar(segundos: viewModel.segundosRestantes)))
                    .font(FrilaTipo.meta.monospacedDigit())
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("validade-do-codigo-da-casa")
            }
        case .encerrado:
            AvisoFrila(verbatim: Textos.encerrado, tom: .informativo)
                .accessibilityIdentifier("codigo-da-casa-encerrado")
        case .falhou:
            AvisoFrila(verbatim: Textos.falhou, tom: .erro)
            BotaoSecundario(verbatim: Textos.tentarDeNovo) { Task { await viewModel.tentarDeNovo() } }
                .accessibilityIdentifier("tentar-codigo-da-casa")
        case .indisponivel, .jaVerificado:
            EmptyView()
        }
    }

    private func progresso(_ texto: String) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            ProgressView()
            Text(verbatim: texto).font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
