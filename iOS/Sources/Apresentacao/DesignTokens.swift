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
    public static func animacao(_ animacao: Animation = .default, reduzir: Bool) -> Animation? {
        reduzir ? nil : animacao
    }
}

public extension View {
    /// Cartão agrupado do MidFi: superfície branca, raio 20 contínuo e fio de 1 pt, sem sombra.
    func cartaoFrila() -> some View {
        padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
    }
}
