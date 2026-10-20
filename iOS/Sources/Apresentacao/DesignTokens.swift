import CoreText
import Foundation
import SwiftUI
import UIKit

public final class MarcadorApresentacao: NSObject {}
public let bundleApresentacao = Bundle(for: MarcadorApresentacao.self)

/// Cores do sistema de design do Fabrício (FrilaLowPhase, `FrilaShiftTokens` e quadros MidFi).
/// As telas seguem o tema neutro decidido para o MidFi: seleção ativa e botão principal em
/// preenchimento escuro com texto branco, superfícies brancas sobre fundo agrupado cinza.
/// A terracota da marca (`marca`) fica só como acento, nunca como fundo de tela ou de cartão.
public enum FrilaCor {
    private static let recursos = bundleApresentacao
    /// Seleção ativa e botão principal (`selectionFill`): quase preto no claro, quase branco no escuro.
    public static let primaria = Color("BrandPrimary", bundle: recursos)
    public static let sobrePrimaria = Color("BrandOnPrimary", bundle: recursos)
    /// Fundo agrupado das telas (`groupedBackground`).
    public static let fundo = Color("Surface", bundle: recursos)
    /// A cortina UIKit usa o mesmo fundo das telas SwiftUI, inclusive no modo escuro.
    static let fundoUIKit = UIColor(named: "Surface", in: recursos, compatibleWith: nil) ?? .systemBackground
    /// Cartões, campos e linhas sobre o fundo agrupado (`groupedSurface`).
    public static let superficie = Color("SurfaceElevated", bundle: recursos)
    public static let texto = Color("TextPrimary", bundle: recursos)
    /// O mesmo token para o UIKit, pelo catálogo: segue claro e escuro sozinho.
    static let textoUIKit = UIColor(named: "TextPrimary", in: recursos, compatibleWith: nil) ?? .label
    /// Texto de apoio: 4,8:1 sobre o fundo agrupado.
    public static let textoSecundario = Color("TextSecondary", bundle: recursos)
    public static let sucesso = Color("Success", bundle: recursos)
    public static let alerta = Color("Warning", bundle: recursos)
    public static let perigo = Color("Danger", bundle: recursos)
    /// Terracota da marca (#EA5A36). Só acento: ícone, marca, destaque pontual.
    public static let marca = Color("BrandAccent", bundle: recursos)
    /// Preenchimento de controle e de aviso neutro (`controlFill`).
    public static let controle = Color("ControlFill", bundle: recursos)
    /// Fio de 1 pt de cartões e divisórias.
    public static let divisoria = Color("Hairline", bundle: recursos)
    /// Contorno de chip inativo, botão de contorno e campo.
    public static let borda = Color("ControlBorder", bundle: recursos)
    /// Puxador das folhas.
    public static let puxador = Color("SheetGrabber", bundle: recursos)
}

public enum FrilaEspaco {
    /// Entre título e subtítulo de um mesmo bloco.
    public static let fio: CGFloat = 2
    public static let minimo: CGFloat = 4
    public static let pequeno: CGFloat = 8
    /// Entre cartões de uma lista e dentro de grupos.
    public static let compacto: CGFloat = 12
    /// Entre as faixas de um cartão (cabeçalho, linhas, divisória).
    public static let faixa: CGFloat = 14
    public static let medio: CGFloat = 16
    public static let grande: CGFloat = 24
    public static let enorme: CGFloat = 32
}

public enum FrilaRaio {
    public static let pequeno: CGFloat = 8
    public static let medio: CGFloat = 12
    /// Avisos e blocos de informação.
    public static let aviso: CGFloat = 16
    /// Cartões agrupados (`radiusGroupedCard`).
    public static let grande: CGFloat = 20
    /// Topo das folhas.
    public static let folha: CGFloat = 28
}

public enum FrilaMetrica {
    public static let alvoMinimo: CGFloat = 44
    public static let larguraMaximaDeLeitura: CGFloat = 680
    /// Campos e botões grandes (`fieldHeight`).
    public static let alturaDoCampo: CGFloat = 52
    /// Altura visual do chip de filtro; o toque continua com 44.
    public static let alturaDoChip: CGFloat = 32
    /// Círculo dos estados vazios e de erro.
    public static let circuloDeEstado: CGFloat = 72
}

/// Tipografia. As telas usam SF Pro pelos estilos de texto, com Dynamic Type (`FrilaTypography.Native`).
/// A Bricolage Grotesque é só a voz do formulário de publicar vaga; números e dinheiro ficam sempre em SF Pro.
public enum FrilaTipo {
    public static let tituloGrande = Font.largeTitle.bold()
    public static let subtituloDaTela = Font.title3
    public static let rotuloDoCampo = Font.headline
    public static let valorDoCampo = Font.body
    public static let chip = Font.body.weight(.semibold)
    public static let tituloDoCartao = Font.title3.weight(.semibold)
    public static let corpo = Font.body
    public static let meta = Font.subheadline
    public static let nota = Font.footnote
    public static let resumo = Font.headline
    public static let preco = Font.title3.bold()
    public static let tituloDeEstado = Font.title3.weight(.semibold)
    public static let tituloDaFolha = Font.title3.weight(.semibold)
    public static let botao = Font.headline

    /// Pergunta do formulário: Bricolage Bold 26, acompanha o estilo `.title`.
    public static var pergunta: Font { bricolage("BricolageGrotesque-Bold", tamanho: 26, relativoA: .title) }
    /// Resposta escolhida no formulário: Bricolage Bold 17, acompanha `.body`.
    public static var respostaEscolhida: Font { bricolage("BricolageGrotesque-Bold", tamanho: 17, relativoA: .body) }
    /// Contexto da resposta: Bricolage Regular 17, acompanha `.body`.
    public static var contextoDaResposta: Font { bricolage("BricolageGrotesque-Regular", tamanho: 17, relativoA: .body) }
    /// Microrrótulo em caixa alta (use com `.textCase(.uppercase)` e `.tracking(0.8)`).
    public static let microRotulo = Font.caption2.weight(.semibold)

    private static func bricolage(_ nome: String, tamanho: CGFloat, relativoA estilo: Font.TextStyle) -> Font {
        _ = FontesFrila.registradas
        return Font.custom(nome, size: tamanho, relativeTo: estilo)
    }
}

/// Registra as fontes do bundle no processo, uma vez. Se falhar, o `Font.custom` cai na fonte do sistema.
enum FontesFrila {
    static let registradas: Void = {
        for nome in ["BricolageGrotesque-Regular", "BricolageGrotesque-Bold"] {
            guard let url = bundleApresentacao.url(forResource: nome, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}

/// Ponto único para controle de animações respeitando a preferência de Reduzir Movimento (#71.4).
/// Quando `reduzir` é verdadeiro, retorna `nil` para que a transição ocorra de forma imediata sem deslocamento.
public enum FrilaMovimento {
    /// Compressão padrão para botões ao pressionar (0,96).
    public static let pressScaleBotao: CGFloat = 0.96
    /// Compressão tátil refinada para chips e pílulas compactas (0,94).
    public static let pressScaleChip: CGFloat = 0.94
    /// Mola tátil geral para botões (rigidez 350, amortecimento 25) do FrilaLowPhase.
    public static let molaTatil: Animation = .interpolatingSpring(stiffness: 350, damping: 25)
    /// Mola ultrarrápida para compressão de chips (rigidez 380, amortecimento 24).
    public static let molaTatilChip: Animation = .interpolatingSpring(stiffness: 380, damping: 24)

    public static func animacao(_ animacao: Animation = .default, reduzir: Bool) -> Animation? {
        reduzir ? nil : animacao
    }
}

/// Representação individual de uma camada de sombra dentro do sistema Beautiful Shadows (FrilaLowPhase).
public struct CamadaDeSombra: Sendable, Equatable {
    public let cor: Color
    public let raio: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(cor: Color, raio: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.cor = cor
        self.raio = raio
        self.x = x
        self.y = y
    }
}

/// Níveis de elevação em três camadas coordenadas (rim, key, ambient) do FrilaLowPhase.
/// Zero-shadow nos cartões com fio de 1 pt; sombra fraca no modo escuro; elevação sutil em folhas e docas.
public enum FrilaElevacao: String, Sendable, CaseIterable, Equatable {
    /// Zero-shadow canônico do MidFi: nenhuma sombra física (usado nos cartões com fio de 1 pt).
    case nenhuma
    /// Elevação sutil em 3 camadas (rim: 1.5pt, key: 5pt, ambient: 14pt).
    case sutil
    /// Elevação de folha modal e doca inferior em 3 camadas (rim: 2pt, key: 12pt, ambient: 28pt).
    case folha

    public func camadas(escuro: Bool) -> [CamadaDeSombra] {
        switch self {
        case .nenhuma:
            return []
        case .sutil:
            if escuro {
                return [
                    CamadaDeSombra(cor: Color.black.opacity(0.26), raio: 1.5, x: 0, y: 1),
                    CamadaDeSombra(cor: Color.black.opacity(0.20), raio: 5, x: 0, y: 2.5),
                    CamadaDeSombra(cor: Color.black.opacity(0.14), raio: 14, x: 0, y: 6)
                ]
            } else {
                return [
                    CamadaDeSombra(cor: Color.black.opacity(0.04), raio: 1.5, x: 0, y: 1),
                    CamadaDeSombra(cor: Color.black.opacity(0.03), raio: 5, x: 0, y: 2.5),
                    CamadaDeSombra(cor: Color.black.opacity(0.02), raio: 14, x: 0, y: 6)
                ]
            }
        case .folha:
            if escuro {
                // Sombra fraca no escuro, igual à regra do LowPhase
                return [
                    CamadaDeSombra(cor: Color.black.opacity(0.36), raio: 2, x: 0, y: 1),
                    CamadaDeSombra(cor: Color.black.opacity(0.24), raio: 12, x: 0, y: 6),
                    CamadaDeSombra(cor: Color.black.opacity(0.18), raio: 28, x: 0, y: 14)
                ]
            } else {
                return [
                    CamadaDeSombra(cor: Color.black.opacity(0.05), raio: 2, x: 0, y: 1),
                    CamadaDeSombra(cor: Color.black.opacity(0.06), raio: 12, x: 0, y: 6),
                    CamadaDeSombra(cor: Color.black.opacity(0.04), raio: 28, x: 0, y: 14)
                ]
            }
        }
    }
}

public struct ModificadorElevacaoFrila: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public let elevacao: FrilaElevacao

    public init(_ elevacao: FrilaElevacao) {
        self.elevacao = elevacao
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let escuro = colorScheme == .dark
        let c = elevacao.camadas(escuro: escuro)
        switch elevacao {
        case .nenhuma:
            content
        case .sutil, .folha:
            content
                .shadow(color: c[0].cor, radius: c[0].raio, x: c[0].x, y: c[0].y)
                .shadow(color: c[1].cor, radius: c[1].raio, x: c[1].x, y: c[1].y)
                .shadow(color: c[2].cor, radius: c[2].raio, x: c[2].x, y: c[2].y)
        }
    }
}

/// Formatação fonética e acessível de moeda para VoiceOver e leitor de tela (Lacuna 11).
public enum FrilaMoney {
    public static let locale = Locale(identifier: "pt_BR")

    /// Tradução fonética de valores em Real para VoiceOver.
    /// Centavos por extenso, suporte a zero, 1 real, negativos e milhares ("160 reais por hora", "1 real", "0 reais", "1.000 reais", "menos 1 real e 50 centavos").
    public static func spoken(cents: Int, por unidade: String? = nil) -> String {
        let isNegative = cents < 0
        let mag = cents.magnitude
        let reais = mag / 100
        let centavos = mag % 100

        let reaisFormatado: String
        if reais == 1 {
            reaisFormatado = "1 real"
        } else if reais == 0 {
            reaisFormatado = "0 reais"
        } else if reais >= 1000 {
            // Milhar: "1.000 reais", "2.500 reais" com separador pt-BR
            reaisFormatado = "\(reais.formatted(.number.locale(locale))) reais"
        } else {
            reaisFormatado = "\(reais) reais"
        }

        var textoPrincipal: String
        if centavos == 0 {
            textoPrincipal = reaisFormatado
        } else {
            let centavosTexto = centavos == 1 ? "1 centavo" : "\(centavos) centavos"
            if reais == 0 {
                textoPrincipal = centavosTexto
            } else {
                textoPrincipal = "\(reaisFormatado) e \(centavosTexto)"
            }
        }

        if isNegative {
            textoPrincipal = "menos \(textoPrincipal)"
        }

        if let unidade, !unidade.isEmpty {
            return "\(textoPrincipal) por \(unidade)"
        }
        return textoPrincipal
    }

    /// Conveniência aceitando reais e centavos inteiros.
    public static func spoken(reais: Int, centavos: Int = 0, por unidade: String? = nil) -> String {
        let (reaisEmCentavos, overflowMult) = reais.multipliedReportingOverflow(by: 100)
        let centavosAjustados = reais < 0 ? -abs(centavos) : centavos
        let (totalCents, overflowSoma) = reaisEmCentavos.addingReportingOverflow(centavosAjustados)

        if overflowMult || overflowSoma {
            // Em caso de overflow aritmético, devolve representação segura baseada na magnitude dos reais
            let isNegative = reais < 0
            let mag = reais.magnitude
            let texto = "\(isNegative ? "menos " : "")\(mag.formatted(.number.locale(locale))) reais"
            if let unidade, !unidade.isEmpty {
                return "\(texto) por \(unidade)"
            }
            return texto
        }

        return spoken(cents: totalCents, por: unidade)
    }
}

/// Materiais translúcidos nativos do SwiftUI para suporte seguro a vidro no iOS 17+ (DP-02).
public enum FrilaMaterial {
    public static let padrao: Material = .regularMaterial
    public static let sutil: Material = .thinMaterial
    public static let ultraSutil: Material = .ultraThinMaterial
}

public extension View {
    /// Cartão agrupado do MidFi: superfície branca, raio 20 contínuo e fio de 1 pt, sem sombra.
    func cartaoFrila() -> some View {
        padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
    }

    /// Aplica o sistema Beautiful Shadows com três camadas coordenadas (rim, key, ambient).
    /// Sem sombra nos cartões com fio de 1 pt; sombra calibrada para folhas e docas.
    func elevacaoFrila(_ elevacao: FrilaElevacao) -> some View {
        modifier(ModificadorElevacaoFrila(elevacao))
    }

    /// Aplica fundo com material translúcido nativo do SwiftUI para efeito de vidro seguro no iOS 17+ (DP-02).
    func vidroFrila(_ material: Material = FrilaMaterial.padrao, raio: CGFloat = FrilaRaio.folha) -> some View {
        background(material, in: RoundedRectangle(cornerRadius: raio, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: raio, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
    }
}
