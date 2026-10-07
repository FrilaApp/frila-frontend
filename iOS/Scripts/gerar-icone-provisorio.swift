#!/usr/bin/env swift

// Ícone provisório do TestFlight interno (#203); o desenho final vem do cartão 169.
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

let raiz = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    .deletingLastPathComponent().deletingLastPathComponent()

func cor(_ token: String) throws -> CGColor {
    let arquivo = raiz.appendingPathComponent("Resources/DesignSystem.xcassets/\(token).colorset/Contents.json")
    let catalogo = try JSONSerialization.jsonObject(with: Data(contentsOf: arquivo)) as! [String: Any]
    let cores = catalogo["colors"] as! [[String: Any]]
    let clara = cores.first { $0["appearances"] == nil }!["color"] as! [String: Any]
    let componentes = clara["components"] as! [String: String]
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components:
        ["red", "green", "blue", "alpha"].map { CGFloat(Double(componentes[$0]!)!) })!
}

// BrandOnPrimary é a cor de texto sobre BrandPrimary (FrilaCor.sobrePrimaria).
let fundo = try cor("BrandPrimary")
let texto = try cor("BrandOnPrimary")
let lado = 1024
let contexto = CGContext(data: nil, width: lado, height: lado, bitsPerComponent: 8,
    bytesPerRow: lado * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
contexto.setFillColor(fundo)
contexto.fill(CGRect(x: 0, y: 0, width: lado, height: lado))

let letra = NSAttributedString(string: "F", attributes: [
    .font: NSFont.systemFont(ofSize: 720, weight: .bold),
    .foregroundColor: NSColor(cgColor: texto)!
])
let linha = CTLineCreateWithAttributedString(letra)
let limites = CTLineGetBoundsWithOptions(linha, .useGlyphPathBounds)
contexto.textPosition = CGPoint(x: 512 - limites.midX, y: 512 - limites.midY)
CTLineDraw(linha, contexto)

let destino = raiz.appendingPathComponent("Resources/App.xcassets/AppIcon.appiconset/AppIcon.png")
let png = CGImageDestinationCreateWithURL(destino as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(png, contexto.makeImage()!, nil)
guard CGImageDestinationFinalize(png) else { fatalError("Não foi possível gravar o ícone") }
print("Ícone opaco 1024 × 1024: \(destino.path)")
