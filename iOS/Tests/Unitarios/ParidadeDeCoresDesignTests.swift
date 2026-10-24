import Foundation
@testable import FrilaApresentacao
import SwiftUI
import Testing
import UIKit

/// Hi-Fi, Fase 2: as cores de `Resources/DesignSystem.xcassets` (`FrilaCor`, lidas pelo app e pelo UIKit)
/// são as mesmas do `FrilaColor` da origem FrilaLowPhase (`Primitivas/FrilaColorDesignTokens.swift`).
/// Um lugar só: quem mudar um valor precisa mudar os dois, e este teste diz qual.
@Suite("Paridade entre DesignSystem.xcassets e FrilaColor")
struct ParidadeDeCoresDesignTests {
    struct Par: Sendable {
        let token: String
        let origem: String
        let cor: @Sendable (_ escuro: Bool) -> Color
    }

    static let pares: [Par] = [
        Par(token: "Surface", origem: "dynamicCanvas") { FrilaColor.dynamicCanvas(isDark: $0) },
        Par(token: "SurfaceElevated", origem: "dynamicFormCardSurface") { FrilaColor.dynamicFormCardSurface(isDark: $0) },
        Par(token: "TextPrimary", origem: "dynamicTextPrimary") { FrilaColor.dynamicTextPrimary(isDark: $0) },
        Par(token: "TextSecondary", origem: "dynamicFormTextMuted") { FrilaColor.dynamicFormTextMuted(isDark: $0) },
        Par(token: "BrandPrimary", origem: "dynamicTextInk") { FrilaColor.dynamicTextInk(isDark: $0) },
        Par(token: "BrandOnPrimary", origem: "dynamicCanvas") { FrilaColor.dynamicCanvas(isDark: $0) },
        Par(token: "ControlFill", origem: "dynamicInputBg") { FrilaColor.dynamicInputBg(isDark: $0) },
        Par(token: "Hairline", origem: "dynamicHairline") { FrilaColor.dynamicHairline(isDark: $0) },
        Par(token: "ControlBorder", origem: "dynamicBorder") { FrilaColor.dynamicBorder(isDark: $0) },
        Par(token: "BrandAccent", origem: "dynamicBrandAccent") { FrilaColor.dynamicBrandAccent(isDark: $0) },
        Par(token: "BrandSelection", origem: "primarySelection") { _ in FrilaColor.primarySelection },
        Par(token: "BrandOnSelection", origem: "dynamicBrandSolidText") { FrilaColor.dynamicBrandSolidText(isDark: $0) },
        Par(token: "FieldSurface", origem: "dynamicFormFieldSurface") { FrilaColor.dynamicFormFieldSurface(isDark: $0) },
        Par(token: "FieldBorder", origem: "dynamicFormFieldBorder") { FrilaColor.dynamicFormFieldBorder(isDark: $0) },
        Par(token: "Success", origem: "dynamicVerified") { FrilaColor.dynamicVerified(isDark: $0) },
        Par(token: "Warning", origem: "dynamicWarningText") { FrilaColor.dynamicWarningText(isDark: $0) },
        Par(token: "Danger", origem: "dynamicError") { FrilaColor.dynamicError(isDark: $0) }
    ]

    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private struct Contents: Decodable {
        struct Item: Decodable {
            struct Aparencia: Decodable { let appearance: String; let value: String }
            struct Cor: Decodable { let components: [String: String] }
            let appearances: [Aparencia]?
            let color: Cor
        }
        let colors: [Item]
    }

    /// Componentes do colorset em 0...255, arredondados como o Xcode grava (3 casas).
    private static func doCatalogo(_ token: String, escuro: Bool) throws -> [Int] {
        let url = raiz.appending(path: "Resources/DesignSystem.xcassets/\(token).colorset/Contents.json")
        let contents = try JSONDecoder().decode(Contents.self, from: Data(contentsOf: url))
        let item = try #require(contents.colors.first { item in
            let ehEscuro = item.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } ?? false
            return ehEscuro == escuro
        }, "\(token) sem variante \(escuro ? "escura" : "clara")")
        return try ["red", "green", "blue"].map { canal in
            let valor = try #require(item.color.components[canal].flatMap(Double.init))
            return Int((valor * 255).rounded())
        }
    }

    private static func daOrigem(_ cor: Color) -> [Int] {
        let componentes = UIColor(cor).cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? []
        return componentes.prefix(3).map { Int(($0 * 255).rounded()) }
    }

    @Test("Cada token do xcassets tem o mesmo RGB da função correspondente do FrilaColor, no claro e no escuro",
          arguments: pares.map(\.token))
    @MainActor
    func tokenIgualAOrigem(token: String) throws {
        let par = try #require(Self.pares.first { $0.token == token })
        for escuro in [false, true] {
            let catalogo = try Self.doCatalogo(token, escuro: escuro)
            let origem = Self.daOrigem(par.cor(escuro))
            #expect(catalogo == origem, "\(token) (\(escuro ? "escuro" : "claro")) = \(catalogo); FrilaColor.\(par.origem) = \(origem)")
        }
    }
}
