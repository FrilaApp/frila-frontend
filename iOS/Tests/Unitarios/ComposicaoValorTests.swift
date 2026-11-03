@testable import FrilaApresentacao
import Testing
import CoreText
import UIKit
import SwiftUI
import FrilaDados
import FrilaDominio

@Suite("Composição de valor LOG-016")
struct ComposicaoValorTests {
    @Test("Preserva o texto formatado, com e sem centavos", arguments: [
        ("R$ 280", "280", ""), ("R$ 45,50", "45", ",50"),
        ("R$ 1.250,00", "1.250", ",00"), ("R$\u{00A0}120,00", "120", ",00")
    ])
    func partes(texto: String, inteiro: String, centavos: String) {
        let partes = FrilaPartesValor(texto)
        #expect(partes.moeda == "R$")
        #expect(partes.inteiro == inteiro)
        #expect(partes.centavos == centavos)
    }
    @Test("Jost 600 embutida contém todos os glifos da composição")
    @MainActor
    func fonteSemFallback() throws {
        FontesFrila.registrar()
        let fonte = try #require(UIFont(name: "JostRoman-SemiBold", size: 26))
        #expect(fonte.fontName == "JostRoman-SemiBold")
        let caracteres = Array("0123456789R$,. ".utf16)
        var glifos = [CGGlyph](repeating: 0, count: caracteres.count)
        #expect(CTFontGetGlyphsForCharacters(fonte as CTFont, caracteres, &glifos, caracteres.count))
        #expect(glifos.allSatisfy { $0 != 0 })
    }
    @Test("Quatro dígitos cabem na barra e no resumo em claro e escuro")
    @MainActor
    func encaixeECapturas() async throws {
        let api = ApiClienteEmMemoria()
        let aberta = try #require(try await api.vagasAbertas(.todas).first)
        let base = try await api.detalheDaVaga(id: aberta.id)
        let vaga = Vaga(id: base.id, estabelecimento: base.estabelecimento, funcao: base.funcao,
                        periodo: base.periodo, local: base.local, regiaoAdministrativa: base.regiaoAdministrativa,
                        ponto: base.ponto, valor: Dinheiro(centavos: 125000), posicoes: 2, posicoesAbertas: 2,
                        inclusos: base.inclusos, responsavelLocal: base.responsavelLocal,
                        modo: .urgencia, estado: base.estado, publicadoEm: base.publicadoEm)
        let texto = FormatadorFrila().dinheiro(vaga.valor)
        let leitura = FrilaMoney.spoken(cents: vaga.valor.centavos)
        let largura: CGFloat = 402
        for tamanho: CGFloat in [26, 22] {
            let preco = UIHostingController(rootView: FrilaPriceTag(texto: texto, tamanho: tamanho))
            let referencia = UIHostingController(rootView: FrilaPriceTag(texto: "R$ 120,00", tamanho: tamanho))
            let limite = CGSize(width: largura, height: 200)
            let medida = preco.sizeThatFits(in: limite)
            #expect(abs(medida.height - referencia.sizeThatFits(in: limite).height) < 1,
                    "O preço de quatro dígitos mantém a altura de uma linha")
            let disponivel = tamanho == 26 ? largura - 32 - 160 - 24 : (largura - 64 - 16) / 2
            #expect(medida.width <= disponivel, "O preço cabe sem truncar a coluna nem empurrar o botão")
        }
        for escuro in [false, true] {
            let conteudo = VStack(alignment: .leading, spacing: 24) {
                FrilaResumoVaga(quando: "Amanhã", horario: "21h56 às 01h56", valor: texto,
                                valorAcessibilidade: leitura, local: "Local sintético", distancia: nil,
                                preenchidas: 0, total: 2, inicio: nil, fim: nil, abrirMapa: {})
                AreaDeCandidatura(viewModel: CandidaturaViewModel(vaga: vaga, api: api), candidatar: { _ in })
                    .environment(AvisosDoDetalhe())
            }
            .padding(16)
            .frame(width: largura)
            .background(FrilaCor.fundo)
            .environment(\.colorScheme, escuro ? .dark : .light)
            let renderizador = ImageRenderer(content: conteudo)
            renderizador.scale = 2
            let imagem = try #require(renderizador.uiImage)
            let destino = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("LOG-016-quatro-digitos-\(escuro ? "escuro" : "claro").png")
            try #require(imagem.pngData()).write(to: destino)
            print("LOG-016 captura: \(destino.path)")
        }
    }

}
