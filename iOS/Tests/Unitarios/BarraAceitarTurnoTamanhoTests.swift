@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
import Testing
import UIKit

@Suite("Valor de 52 pt na barra LOG-018")
struct BarraAceitarTurnoTamanhoTests {
    @Test("R$ 1.250,00 cabe sem truncar na largura útil do SE")
    @MainActor
    func quatroDigitosNoSE() async throws {
        FontesFrila.registrar()
        let larguraUtil: CGFloat = 375 - 32
        let preco = FrilaPriceTag(texto: "R$ 1.250,00", tamanho: 52)
        let limite = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 200)
        let medida = UIHostingController(rootView: preco).sizeThatFits(in: limite)
        let referencia = UIHostingController(rootView: FrilaPriceTag(texto: "R$ 120,00", tamanho: 52))
            .sizeThatFits(in: limite)
        #expect(medida.width <= larguraUtil, "A largura natural cabe nos 343 pt sem compressão")
        #expect(abs(medida.height - referencia.height) < 1, "O preço mantém uma única linha")
        print("LOG-018 52 pt, quatro dígitos: natural=\(medida), disponível=\(larguraUtil), folga=\(larguraUtil - medida.width)")

        let api = ApiClienteEmMemoria()
        let aberta = try #require(try await api.vagasAbertas(.todas).first)
        let base = try await api.detalheDaVaga(id: aberta.id)
        let vaga = Vaga(id: base.id, estabelecimento: base.estabelecimento, funcao: base.funcao,
                        periodo: base.periodo, local: base.local, regiaoAdministrativa: base.regiaoAdministrativa,
                        ponto: base.ponto, valor: Dinheiro(centavos: 125000), posicoes: 2, posicoesAbertas: 2,
                        inclusos: base.inclusos, responsavelLocal: base.responsavelLocal,
                        modo: .urgencia, estado: base.estado, publicadoEm: base.publicadoEm)
        let modelo = CandidaturaViewModel(vaga: vaga, api: api)
        await modelo.conferirCandidatura()
        let barra = AreaDeCandidatura(viewModel: modelo, candidatar: { _ in })
            .environment(AvisosDoDetalhe())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: 375)
            .background(FrilaCor.fundo)
            .environment(\.colorScheme, .light)
        let renderizador = ImageRenderer(content: barra)
        renderizador.scale = 2
        let imagem = try #require(renderizador.uiImage)
        let destino = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LOG-018-SE-quatro-digitos-52.png")
        try #require(imagem.pngData()).write(to: destino)
        print("LOG-018 52 pt captura SE: \(destino.path)")
    }
}
