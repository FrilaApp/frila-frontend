import Foundation
import Testing

/// Teste automatizado de contraste WCAG 2.1 AA dos tokens de design (Design System).
///
/// Hi-Fi, Fase 2 (24/10/2026): os valores dos tokens passaram a ser os do `FrilaColor` do FrilaLowPhase
/// (`ParidadeDeCoresDesignTests` prova a igualdade) e entraram `BrandSelection`, `BrandOnSelection`,
/// `FieldSurface` e `FieldBorder`. Os pares abaixo cresceram de propósito, para cobrir os tokens novos;
/// nenhum limite foi afrouxado.
///
/// Avalia matematicamente todas as combinações semânticas de cor de `Resources/DesignSystem.xcassets`
/// em modo claro e escuro pela fórmula canônica do W3C (WCAG 2.1 Critério 1.4.3 para texto e
/// Critério 1.4.11 para componentes de interface e ícones).
///
/// Regras de corte WCAG AA:
/// - Texto normal (< 18 pt regular ou < 14 pt bold): razão mínima de 4,5:1
/// - Texto grande (>= 18 pt regular ou >= 14 pt bold) ou componente de interface/ícone: razão mínima de 3,0:1
/// - Elementos puramente decorativos ou controles desabilitados: isentos pela norma WCAG.
@Suite("Contraste WCAG AA dos Tokens do Design System")
struct ContrasteDesignTokensTests {

    struct CorSRGB: Sendable {
        let r: Double
        let g: Double
        let b: Double
        let alpha: Double

        /// Luminância relativa sRGB calculada conforme a fórmula W3C WCAG 2.1:
        /// L = 0.2126 * R + 0.7152 * G + 0.0722 * B
        var luminanciaRelativa: Double {
            func linearizar(_ canal: Double) -> Double {
                canal <= 0.04045 ? (canal / 12.92) : pow((canal + 0.055) / 1.055, 2.4)
            }
            let rLin = linearizar(r)
            let gLin = linearizar(g)
            let bLin = linearizar(b)
            return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
        }

        /// Razão de contraste entre duas cores: (L1 + 0.05) / (L2 + 0.05) onde L1 >= L2.
        func razaoDeContraste(contra outra: CorSRGB) -> Double {
            let l1 = self.luminanciaRelativa
            let l2 = outra.luminanciaRelativa
            let maisClaro = max(l1, l2)
            let maisEscuro = min(l1, l2)
            return (maisClaro + 0.05) / (maisEscuro + 0.05)
        }
    }

    enum TipoDeUso: Sendable {
        /// Texto normal do app (WCAG 1.4.3: mínimo 4,5:1)
        case textoNormal
        /// Texto grande, componente de UI, foco ou ícone essencial (WCAG 1.4.11 / 1.4.3: mínimo 3,0:1)
        case componenteOuIcone
        /// Elemento puramente decorativo ou controle inativo (isento sob WCAG)
        case decorativoOuInativo

        var razaoMinimaAA: Double? {
            switch self {
            case .textoNormal: return 4.5
            case .componenteOuIcone: return 3.0
            case .decorativoOuInativo: return nil
            }
        }
    }

    struct ParSemantico: Sendable {
        let nome: String
        let tokenFrente: String
        let tokenFundo: String
        let tipo: TipoDeUso
        let justificativa: String
    }

    // MARK: - Catálogo de Pares Semânticos Usados no Frila

    /// Pares normativos de texto sobre superfícies utilizados nas telas do app.
    static let paresDeTextoEmUso: [ParSemantico] = [
        ParSemantico(
            nome: "Texto principal sobre fundo agrupado",
            tokenFrente: "TextPrimary",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Títulos de tela e textos fora de cartões."
        ),
        ParSemantico(
            nome: "Texto principal sobre cartão elevado",
            tokenFrente: "TextPrimary",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Títulos de cartões, texto de campos de entrada e folhas."
        ),
        ParSemantico(
            nome: "Texto principal sobre preenchimento de controle",
            tokenFrente: "TextPrimary",
            tokenFundo: "ControlFill",
            tipo: .textoNormal,
            justificativa: "Mensagens textuais em AvisoFrila e pílulas neutras."
        ),
        ParSemantico(
            nome: "Texto secundário sobre fundo agrupado",
            tokenFrente: "TextSecondary",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Subtítulos de seção, metadados fora de cartões."
        ),
        ParSemantico(
            nome: "Texto secundário sobre cartão elevado",
            tokenFrente: "TextSecondary",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Linhas de apoio, notas de rodapé de cartões e placeholders."
        ),
        ParSemantico(
            nome: "Texto secundário sobre preenchimento de controle",
            tokenFrente: "TextSecondary",
            tokenFundo: "ControlFill",
            tipo: .textoNormal,
            justificativa: "Metadados sobre fundos de chip e tags de estado."
        ),
        ParSemantico(
            nome: "Texto claro sobre botão principal",
            tokenFrente: "BrandOnPrimary",
            tokenFundo: "BrandPrimary",
            tipo: .textoNormal,
            justificativa: "BotaoPrimario e pílulas de filtro ativas."
        ),
        ParSemantico(
            nome: "Texto claro sobre botão de perigo",
            tokenFrente: "BrandOnPrimary",
            tokenFundo: "Danger",
            tipo: .textoNormal,
            justificativa: "Botão de confirmação definitiva em TelaExclusaoDeConta."
        ),
        ParSemantico(
            nome: "Ação de texto/link primária sobre fundo agrupado",
            tokenFrente: "BrandPrimary",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Botões de contorno e links diretamente sobre o fundo."
        ),
        ParSemantico(
            nome: "Ação de texto/link primária sobre cartão elevado",
            tokenFrente: "BrandPrimary",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Botões de contorno e ações dentro de cartões."
        ),
        ParSemantico(
            nome: "Texto de sucesso sobre fundo agrupado",
            tokenFrente: "Success",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Mensagens e rótulos de status positivo na tela."
        ),
        ParSemantico(
            nome: "Texto de sucesso sobre cartão elevado",
            tokenFrente: "Success",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Selos de reputação, confirmação de presença em cartões."
        ),
        ParSemantico(
            nome: "Texto de alerta sobre fundo agrupado",
            tokenFrente: "Warning",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Avisos de pendência ou turno aguardando sobre o fundo."
        ),
        ParSemantico(
            nome: "Texto de alerta sobre cartão elevado",
            tokenFrente: "Warning",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Avisos de fila offline ou prazos dentro de cartões."
        ),
        ParSemantico(
            nome: "Texto de perigo sobre fundo agrupado",
            tokenFrente: "Danger",
            tokenFundo: "Surface",
            tipo: .textoNormal,
            justificativa: "Mensagens de erro e alertas de cancelamento sobre o fundo."
        ),
        ParSemantico(
            nome: "Texto de perigo sobre cartão elevado",
            tokenFrente: "Danger",
            tokenFundo: "SurfaceElevated",
            tipo: .textoNormal,
            justificativa: "Rótulo de capsulaDestrutiva e mensagens de erro de formulário."
        ),
        ParSemantico(
            nome: "Texto principal sobre superfície de campo",
            tokenFrente: "TextPrimary",
            tokenFundo: "FieldSurface",
            tipo: .textoNormal,
            justificativa: "Valor digitado em CampoFrila, CampoCodigo e campos do Estúdio."
        ),
        ParSemantico(
            nome: "Texto secundário sobre superfície de campo",
            tokenFrente: "TextSecondary",
            tokenFundo: "FieldSurface",
            tipo: .textoNormal,
            justificativa: "Placeholder e apoio dentro dos campos."
        ),
        ParSemantico(
            nome: "Texto claro sobre seleção da marca",
            tokenFrente: "BrandOnSelection",
            tokenFundo: "BrandSelection",
            tipo: .textoNormal,
            justificativa: "FiltroPill ativa e RespostaSimNao escolhida (terracota de seleção da origem, #C9470F)."
        )
    ]

    /// Pares de componentes gráficos, ícones essenciais e elementos com requisitos de 3,0:1.
    static let paresDeComponenteEmUso: [ParSemantico] = [
        ParSemantico(
            nome: "Ícone/acento de marca sobre fundo agrupado",
            tokenFrente: "BrandAccent",
            tokenFundo: "Surface",
            tipo: .componenteOuIcone,
            justificativa: "Ícone e marca terracota pontual (#EA5A36) sobre o fundo."
        ),
        ParSemantico(
            nome: "Ícone/acento de marca sobre cartão elevado",
            tokenFrente: "BrandAccent",
            tokenFundo: "SurfaceElevated",
            tipo: .componenteOuIcone,
            justificativa: "Destaque gráfico e ícone de marca dentro de cartões."
        ),
        ParSemantico(
            nome: "Ícone/texto grande claro sobre acento de marca",
            tokenFrente: "BrandOnPrimary",
            tokenFundo: "BrandAccent",
            tipo: .componenteOuIcone,
            justificativa: "Ícone ou glifo sobre pílula com fundo terracota em SearchCapsule."
        ),
        ParSemantico(
            nome: "Contorno de campo sobre fundo agrupado",
            tokenFrente: "FieldBorder",
            tokenFundo: "Surface",
            tipo: .componenteOuIcone,
            justificativa: "Fio de 1 pt dos campos (`dynamicFormFieldBorder`) diretamente sobre a tela."
        ),
        ParSemantico(
            nome: "Contorno de campo sobre cartão elevado",
            tokenFrente: "FieldBorder",
            tokenFundo: "SurfaceElevated",
            tipo: .componenteOuIcone,
            justificativa: "Fio dos campos dentro de cartões e folhas."
        ),
        ParSemantico(
            nome: "Contorno de campo sobre a própria superfície do campo",
            tokenFrente: "FieldBorder",
            tokenFundo: "FieldSurface",
            tipo: .componenteOuIcone,
            justificativa: "O fio precisa se distinguir do preenchimento do campo."
        ),
        ParSemantico(
            nome: "Seleção da marca sobre fundo agrupado",
            tokenFrente: "BrandSelection",
            tokenFundo: "Surface",
            tipo: .componenteOuIcone,
            justificativa: "Pílula ativa e contorno de escolha sobre a tela."
        ),
        ParSemantico(
            nome: "Seleção da marca sobre cartão elevado",
            tokenFrente: "BrandSelection",
            tokenFundo: "SurfaceElevated",
            tipo: .componenteOuIcone,
            justificativa: "Pílula ativa dentro de cartões."
        )
    ]

    // MARK: - Leitura de Tokens do DesignSystem.xcassets

    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private struct AssetContents: Decodable {
        struct CorItem: Decodable {
            struct Aparência: Decodable {
                let appearance: String
                let value: String
            }
            struct CorInfo: Decodable {
                let components: [String: String]?
            }
            let appearances: [Aparência]?
            let color: CorInfo
        }
        let colors: [CorItem]
    }

    private static func carregarTokensDoCatalogo() throws -> [String: (claro: CorSRGB, escuro: CorSRGB)] {
        let xcassets = raiz.appending(path: "Resources").appending(path: "DesignSystem.xcassets")
        let itens = try FileManager.default.contentsOfDirectory(at: xcassets, includingPropertiesForKeys: nil)

        var catalogo: [String: (claro: CorSRGB, escuro: CorSRGB)] = [:]

        for item in itens where item.pathExtension == "colorset" {
            let nome = item.deletingPathExtension().lastPathComponent
            let jsonURL = item.appendingPathComponent("Contents.json")
            guard FileManager.default.fileExists(atPath: jsonURL.path) else { continue }
            let data = try Data(contentsOf: jsonURL)
            let asset = try JSONDecoder().decode(AssetContents.self, from: data)

            var corClara: CorSRGB?
            var corEscura: CorSRGB?

            for c in asset.colors {
                guard let comps = c.color.components,
                      let rStr = comps["red"], let r = Double(rStr),
                      let gStr = comps["green"], let g = Double(gStr),
                      let bStr = comps["blue"], let b = Double(bStr) else { continue }
                let alpha = comps["alpha"].flatMap(Double.init) ?? 1.0
                let cor = CorSRGB(r: r, g: g, b: b, alpha: alpha)

                let ehEscuro = c.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } ?? false
                if ehEscuro {
                    corEscura = cor
                } else {
                    corClara = cor
                }
            }

            if let clara = corClara, let escura = corEscura {
                catalogo[nome] = (clara, escura)
            }
        }
        return catalogo
    }

    // MARK: - Testes Unitários de Regressão

    @Test("Encontra e carrega todos os 18 tokens de cor em DesignSystem.xcassets")
    func carregaTokensDoDesignSystem() throws {
        let tokens = try Self.carregarTokensDoCatalogo()
        let esperados = [
            "BrandAccent", "BrandOnPrimary", "BrandOnSelection", "BrandPrimary", "BrandSelection",
            "ControlBorder", "ControlFill", "Danger", "FieldBorder", "FieldSurface", "Hairline",
            "SheetGrabber", "Success", "Surface", "SurfaceElevated", "TextPrimary", "TextSecondary", "Warning"
        ]
        for esperado in esperados {
            #expect(tokens[esperado] != nil, "Token \(esperado) ausente em DesignSystem.xcassets")
        }
        #expect(tokens.count == 18, "Token novo? Registre-o aqui e nos pares, com a razão no PR.")
    }

    @Test("Todos os pares normativos de texto atendem ao mínimo de 4,5:1 (WCAG AA) em claro e escuro")
    func paresDeTextoCumpremWCAGAA() throws {
        let tokens = try Self.carregarTokensDoCatalogo()
        var falhas: [String] = []

        for par in Self.paresDeTextoEmUso {
            guard let frente = tokens[par.tokenFrente], let fundo = tokens[par.tokenFundo] else {
                falhas.append("Tokens não encontrados para o par: \(par.nome)")
                continue
            }

            let razaoClaro = frente.claro.razaoDeContraste(contra: fundo.claro)
            let razaoEscuro = frente.escuro.razaoDeContraste(contra: fundo.escuro)

            if razaoClaro < 4.5 {
                falhas.append("[\(par.tokenFrente) sobre \(par.tokenFundo)] Modo Claro: \(String(format: "%.2f", razaoClaro)):1 < 4.5:1 (\(par.nome))")
            }
            if razaoEscuro < 4.5 {
                falhas.append("[\(par.tokenFrente) sobre \(par.tokenFundo)] Modo Escuro: \(String(format: "%.2f", razaoEscuro)):1 < 4.5:1 (\(par.nome))")
            }
        }

        #expect(falhas.isEmpty, "Pares de texto com contraste abaixo de 4,5:1: \(falhas)")
    }

    @Test("Todos os componentes essenciais e ícones atendem ao mínimo de 3,0:1 (WCAG AA) em claro e escuro")
    func paresDeComponenteCumpremWCAGAA() throws {
        let tokens = try Self.carregarTokensDoCatalogo()
        var falhas: [String] = []

        for par in Self.paresDeComponenteEmUso {
            guard let frente = tokens[par.tokenFrente], let fundo = tokens[par.tokenFundo] else {
                falhas.append("Tokens não encontrados para o par: \(par.nome)")
                continue
            }

            let razaoClaro = frente.claro.razaoDeContraste(contra: fundo.claro)
            let razaoEscuro = frente.escuro.razaoDeContraste(contra: fundo.escuro)

            if razaoClaro < 3.0 {
                falhas.append("[\(par.tokenFrente) sobre \(par.tokenFundo)] Modo Claro: \(String(format: "%.2f", razaoClaro)):1 < 3.0:1 (\(par.nome))")
            }
            if razaoEscuro < 3.0 {
                falhas.append("[\(par.tokenFrente) sobre \(par.tokenFundo)] Modo Escuro: \(String(format: "%.2f", razaoEscuro)):1 < 3.0:1 (\(par.nome))")
            }
        }

        #expect(falhas.isEmpty, "Componentes ou ícones com contraste abaixo de 3,0:1: \(falhas)")
    }

    @Test("Guarda estrita das exceções e restrições de uso: BrandAccent é apenas acento e não texto corrido")
    func guardaDeExcecoesERestricoesDeDesign() throws {
        let tokens = try Self.carregarTokensDoCatalogo()
        let marca = try #require(tokens["BrandAccent"])
        let surface = try #require(tokens["Surface"])
        let surfaceElevated = try #require(tokens["SurfaceElevated"])

        let razaoMarcaSurfaceClaro = marca.claro.razaoDeContraste(contra: surface.claro)
        let razaoMarcaSuperficieClaro = marca.claro.razaoDeContraste(contra: surfaceElevated.claro)

        // Comprova que BrandAccent passa como componente/ícone (>= 3,0:1) no tema claro:
        #expect(razaoMarcaSurfaceClaro >= 3.0, "BrandAccent sobre Surface deve passar para componente (>= 3,0:1)")
        #expect(razaoMarcaSuperficieClaro >= 3.0, "BrandAccent sobre SurfaceElevated deve passar para componente (>= 3,0:1)")

        // Comprova e documenta matematicamente que BrandAccent no claro cai abaixo de 4,5:1
        // (por isso a diretriz em DesignTokens.swift proíbe seu uso como texto corrido de tela/cartão):
        #expect(razaoMarcaSurfaceClaro < 4.5, "BrandAccent sobre Surface deve registrar reprovação se avaliado como texto normal")
        #expect(razaoMarcaSuperficieClaro < 4.5, "BrandAccent sobre SurfaceElevated deve registrar reprovação se avaliado como texto normal")

        // No modo escuro, BrandAccent atinge contraste suficiente tanto para componente quanto para texto:
        let razaoMarcaSurfaceEscuro = marca.escuro.razaoDeContraste(contra: surface.escuro)
        let razaoMarcaSuperficieEscuro = marca.escuro.razaoDeContraste(contra: surfaceElevated.escuro)
        #expect(razaoMarcaSurfaceEscuro >= 4.5)
        #expect(razaoMarcaSuperficieEscuro >= 4.5)
    }

    @Test("Puxador de folhas modais (SheetGrabber) está documentado como elemento puramente decorativo")
    func sheetGrabberIsentoPorSerDecorativo() throws {
        let tokens = try Self.carregarTokensDoCatalogo()
        let puxador = try #require(tokens["SheetGrabber"])
        let surfaceElevated = try #require(tokens["SurfaceElevated"])

        let razaoClaro = puxador.claro.razaoDeContraste(contra: surfaceElevated.claro)
        let razaoEscuro = puxador.escuro.razaoDeContraste(contra: surfaceElevated.escuro)

        // Razão abaixo de 3:1 é tolerada pelo WCAG 1.4.11 exclusivamente porque o puxador
        // é puramente decorativo e possui .accessibilityHidden(true) no componente SwiftUI.
        #expect(razaoClaro < 3.0)
        #expect(razaoEscuro < 3.0)
    }
}
