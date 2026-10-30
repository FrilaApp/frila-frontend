@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
import Testing
import UIKit

@Suite("Valor na escala do rodapé LOG-019")
struct BarraAceitarTurnoTamanhoTests {
    @Test("R$ 1.250,00 cabe sem truncar na largura útil do SE")
    @MainActor
    func quatroDigitosNoSE() async throws {
        FontesFrila.registrar()
        let tamanho = FrilaTypeScaleStep.display.pointSize
        let larguraUtil: CGFloat = 375 - 32
        let preco = FrilaPriceTag(texto: "R$ 1.250,00", tamanho: tamanho, peso: .bold, compactarAltura: true)
        let limite = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 200)
        let medida = UIHostingController(rootView: preco).sizeThatFits(in: limite)
        let referencia = UIHostingController(rootView: FrilaPriceTag(texto: "R$ 120,00", tamanho: tamanho, peso: .bold, compactarAltura: true))
            .sizeThatFits(in: limite)
        let semCompactar = UIHostingController(rootView: FrilaPriceTag(texto: "R$ 1.250,00", tamanho: tamanho, peso: .bold))
            .sizeThatFits(in: limite)
        let ganho = semCompactar.height - medida.height
        print("LOG-019 rodada3b caixa: semCompactar=\(semCompactar), compacta=\(medida), ganho=\(ganho)")
        #expect(ganho >= 8, "A compactação só permanece se economizar ao menos 8 pt")
        #expect(medida.width <= larguraUtil, "A largura natural cabe nos 343 pt sem compressão")
        #expect(abs(medida.height - referencia.height) < 1, "O preço mantém uma única linha")
        print("LOG-019 rodada3b 32 pt, quatro dígitos: natural=\(medida), disponível=\(larguraUtil), folga=\(larguraUtil - medida.width)")

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
            .padding(.vertical, 8)
            .frame(width: 375)
            .background(FrilaCor.fundo)
            .environment(\.colorScheme, .light)
        let alturaBarra = UIHostingController(rootView: barra).sizeThatFits(in: CGSize(width: 375, height: 800)).height
        print("LOG-019 rodada3b barra1250 SE altura=\(alturaBarra)")
        let renderizador = ImageRenderer(content: barra)
        renderizador.scale = 2
        let imagem = try #require(renderizador.uiImage)
        let destino = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LOG-019b-SE-quatro-digitos-700.png")
        try #require(imagem.pngData()).write(to: destino)
        print("LOG-019 rodada3b 32 pt captura SE: \(destino.path)")
    }
}
