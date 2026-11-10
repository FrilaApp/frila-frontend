import SwiftUI
import Testing
import UIKit
@testable import FrilaApresentacao

/// Achado na prova da L5 (09/11/2026): em AX5, um botão em `Capsule()` com rótulo de várias linhas vira um círculo e o
/// texto vaza para fora, porque o raio da cápsula é a metade do menor lado e cresce com a altura. Os controles de
/// toque usam `FrilaForma.capsulaQueCresce` (raio fixo na metade da altura mínima). O teste desenha o controle em AX5 com
/// um rótulo longo e confere um pixel da borda esquerda, a 30% da altura: com a cápsula ele cai fora do botão.
@Suite("Forma dos botões e chips em AX5: o rótulo longo não corta nem vaza")
@MainActor
struct FormaDosBotoesAX5Tests {
    private static let rotuloLongo = "Republicar as posições que ficaram sem ninguém para o mesmo dia"

    private struct Imagem {
        let largura: Int
        let altura: Int
        private let bytes: [UInt8]

        init?(_ cg: CGImage) {
            largura = cg.width
            altura = cg.height
            var dados = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let desenhado = dados.withUnsafeMutableBytes { buffer -> Bool in
                guard let contexto = CGContext(
                    data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
                    bytesPerRow: cg.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                contexto.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                return true
            }
            guard desenhado else { return nil }
            bytes = dados
        }

        func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * largura + x) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }
    }

    private func desenhar(_ vista: some View, fundo: Color, ax5: Bool) throws -> Imagem {
        let conteudo = vista
            .frame(width: 320)
            .background(fundo)
            .environment(\.dynamicTypeSize, ax5 ? .accessibility5 : .large)
            .environment(\.colorScheme, .light)
        let renderizador = ImageRenderer(content: conteudo)
        renderizador.scale = 1
        let cg = try #require(renderizador.uiImage?.cgImage, "o controle não renderizou")
        return try #require(Imagem(cg))
    }

    // MARK: Botão primário (a ação, laranja)

    private func eLaranja(_ p: (r: Int, g: Int, b: Int)) -> Bool { p.r > 220 && (80...130).contains(p.g) && p.b < 40 }
    private func ePreto(_ p: (r: Int, g: Int, b: Int)) -> Bool { p.r < 30 && p.g < 30 && p.b < 30 }
    private func eBranco(_ p: (r: Int, g: Int, b: Int)) -> Bool { p.r > 235 && p.g > 235 && p.b > 235 }

    @Test("Botão primário em AX5 com rótulo longo: a borda esquerda segue preenchida, o botão não vira círculo")
    func primarioEmAX5() throws {
        let imagem = try desenhar(BotaoPrimario(verbatim: Self.rotuloLongo) {}, fundo: .black, ax5: true)
        #expect(imagem.altura > 104, "o rótulo longo em AX5 quebra em várias linhas (altura \(imagem.altura))")
        let borda = imagem.pixel(x: 3, y: Int(Double(imagem.altura) * 0.3))
        #expect(eLaranja(borda), "borda esquerda a 30% da altura devia ser laranja, e é \(borda): a forma virou círculo")
    }

    @Test("Botão primário no tamanho padrão continua cápsula: o canto é arredondado e a lateral cheia")
    func primarioNoTamanhoPadrao() throws {
        let imagem = try desenhar(BotaoPrimario(verbatim: "Aceitar turno") {}, fundo: .black, ax5: false)
        #expect(ePreto(imagem.pixel(x: 1, y: 1)), "o canto de uma cápsula é arredondado")
        #expect(eLaranja(imagem.pixel(x: 3, y: imagem.altura / 2)), "a lateral, na meia altura, é do botão")
    }

    // MARK: Botão secundário (superfície branca com fio)

    @Test("Botão secundário em AX5 com rótulo longo: a borda esquerda segue dentro da forma")
    func secundarioEmAX5() throws {
        let imagem = try desenhar(BotaoSecundario(verbatim: Self.rotuloLongo) {}, fundo: .black, ax5: true)
        #expect(imagem.altura > 104, "altura \(imagem.altura)")
        let borda = imagem.pixel(x: 4, y: Int(Double(imagem.altura) * 0.3))
        #expect(eBranco(borda), "borda esquerda a 30% da altura devia ser a superfície branca, e é \(borda)")
    }

    // MARK: Chip de filtro (a tinta quando marcado)

    @Test("Chip de filtro marcado em AX5 com rótulo longo: a borda esquerda segue dentro do chip")
    func chipEmAX5() throws {
        let imagem = try desenhar(FiltroPill(verbatim: Self.rotuloLongo, selecionado: true) {}, fundo: .white, ax5: true)
        #expect(imagem.altura > 80, "altura \(imagem.altura)")
        let borda = imagem.pixel(x: 3, y: Int(Double(imagem.altura) * 0.5))
        #expect(!eBranco(borda), "a borda esquerda, na meia altura, devia ser o chip (tinta), e é \(borda)")
    }

    // MARK: A forma

    @Test("A forma que cresce mantém o raio na metade da altura mínima, qualquer que seja a altura")
    func formaMantemORaio() {
        let baixa = FrilaForma.capsulaQueCresce().path(in: CGRect(x: 0, y: 0, width: 300, height: 52))
        let alta = FrilaForma.capsulaQueCresce().path(in: CGRect(x: 0, y: 0, width: 300, height: 200))
        // O ponto (10, 60) fica na lateral reta da forma alta (raio 26) e fora da cápsula de 200 pt (raio 100).
        #expect(alta.contains(CGPoint(x: 10, y: 60)))
        #expect(!Capsule().path(in: CGRect(x: 0, y: 0, width: 300, height: 200)).contains(CGPoint(x: 10, y: 60)))
        // Na altura mínima as duas coincidem no canto: (4, 4) está fora das duas.
        #expect(!baixa.contains(CGPoint(x: 4, y: 4)))
        #expect(!Capsule().path(in: CGRect(x: 0, y: 0, width: 300, height: 52)).contains(CGPoint(x: 4, y: 4)))
    }
}
