import CoreGraphics
import Foundation
import FrilaDominio
import ImageIO
import UniformTypeIdentifiers

/// ImageIO como `PreparadorDeFoto` (CD-M04b): aplica a orientação nos pixels, recorta o quadrado 1:1,
/// reduz para no máximo 1600 px de lado, converte para JPEG de até 5 MB e tira todo metadado. Só o
/// original sobe; a miniatura de 320 px deriva do servidor.
public struct PreparadorDeFotoDoSistema: PreparadorDeFoto {
    /// Maior lado que se decodifica antes do recorte: segura a memória com fotos de 48 MP.
    private static let ladoMaximoDeDecodificacao = 6000
    private static let qualidades: [CGFloat] = [0.85, 0.7, 0.5, 0.3]

    public init() {}

    public func preparar(original: Data, recorte: RecorteQuadrado) throws -> FotoPreparada {
        guard let fonte = CGImageSourceCreateWithData(original as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(fonte) > 0
        else { throw ErroDePreparoDaFoto.imagemInvalida }

        // `WithTransform` gira os pixels conforme a orientação gravada, que depois some com os metadados.
        let opcoes: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.ladoMaximoDeDecodificacao,
        ]
        guard let orientada = CGImageSourceCreateThumbnailAtIndex(fonte, 0, opcoes as CFDictionary),
              let area = recorte.retangulo(larguraDaImagem: orientada.width, alturaDaImagem: orientada.height),
              let cortada = orientada.cropping(to: area)
        else { throw ErroDePreparoDaFoto.imagemInvalida }

        var lado = min(cortada.width, LimitesDaFoto.ladoMaximo)
        for _ in 0..<4 {
            guard let reduzida = Self.quadrado(de: cortada, lado: lado) else { throw ErroDePreparoDaFoto.imagemInvalida }
            for qualidade in Self.qualidades {
                guard let codificada = Self.jpeg(de: reduzida, qualidade: qualidade) else { throw ErroDePreparoDaFoto.imagemInvalida }
                let limpa = LimpadorDeMetadadosJPEG.limpar(codificada)
                if limpa.count <= LimitesDaFoto.bytesMaximos { return FotoPreparada(jpeg: limpa, lado: lado) }
            }
            lado = lado * 3 / 4
            if lado < 64 { break }
        }
        throw ErroDePreparoDaFoto.grandeDemais
    }

    /// Redesenha em sRGB, sem canal alfa, sobre fundo branco: o JPEG não tem transparência.
    private static func quadrado(de imagem: CGImage, lado: Int) -> CGImage? {
        guard let espaco = CGColorSpace(name: CGColorSpace.sRGB),
              let contexto = CGContext(
                  data: nil, width: lado, height: lado, bitsPerComponent: 8, bytesPerRow: 0, space: espaco,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        contexto.fill(CGRect(x: 0, y: 0, width: lado, height: lado))
        contexto.interpolationQuality = .high
        contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: lado, height: lado))
        return contexto.makeImage()
    }

    private static func jpeg(de imagem: CGImage, qualidade: CGFloat) -> Data? {
        let dados = NSMutableData()
        guard let destino = CGImageDestinationCreateWithData(dados, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // Só a qualidade: nenhuma propriedade de metadado entra na gravação.
        CGImageDestinationAddImage(destino, imagem, [kCGImageDestinationLossyCompressionQuality: qualidade] as CFDictionary)
        guard CGImageDestinationFinalize(destino) else { return nil }
        return dados as Data
    }
}

/// O ImageIO grava um bloco Exif mínimo (dimensões e espaço de cor) mesmo sem metadado de entrada, e o
/// servidor recusa JPEG com EXIF (`midia_invalida`, `metadados`). Aqui sai todo segmento que carrega
/// metadado e fica o que decodifica a imagem: JFIF (APP0), perfil de cor ICC (APP2) e Adobe (APP14).
public enum LimpadorDeMetadadosJPEG {
    private static let marcadoresMantidos: Set<UInt8> = [0xE0, 0xE2, 0xEE]

    public static func limpar(_ jpeg: Data) -> Data {
        let bytes = [UInt8](jpeg)
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return jpeg }
        var saida: [UInt8] = [0xFF, 0xD8]
        var posicao = 2
        while posicao + 3 < bytes.count {
            guard bytes[posicao] == 0xFF else { return jpeg }
            let marcador = bytes[posicao + 1]
            if marcador == 0xFF { posicao += 1; continue }
            // Do início do scan em diante são só os dados da imagem: copia o resto como está.
            if marcador == 0xDA {
                saida.append(contentsOf: bytes[posicao...])
                return Data(saida)
            }
            let tamanho = Int(bytes[posicao + 2]) << 8 | Int(bytes[posicao + 3])
            guard tamanho >= 2, posicao + 2 + tamanho <= bytes.count else { return jpeg }
            let ehMetadado = (0xE1...0xED).contains(marcador) && marcador != 0xE2 || marcador == 0xFE
            if !ehMetadado || marcadoresMantidos.contains(marcador) {
                saida.append(contentsOf: bytes[posicao..<(posicao + 2 + tamanho)])
            }
            posicao += 2 + tamanho
        }
        return jpeg
    }

    /// Há segmento de metadado (EXIF, XMP, IPTC, comentário) no JPEG.
    public static func temMetadados(_ jpeg: Data) -> Bool {
        limpar(jpeg).count != jpeg.count
    }
}
