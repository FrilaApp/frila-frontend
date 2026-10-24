import CoreText
import Foundation
import SwiftUI
import UIKit

public final class MarcadorApresentacao: NSObject {}
public let bundleApresentacao = Bundle(for: MarcadorApresentacao.self)

/// Cores do Hi-Fi do Fabrício (FrilaLowPhase). Cada token do `DesignSystem.xcassets` é o mesmo RGB de
/// uma função do `FrilaColor` (`Primitivas/FrilaColorDesignTokens.swift`); `ParidadeDeCoresDesignTests`
/// prova a igualdade. As telas antigas leem daqui; o Estúdio lê do `FrilaColor` com `isDark:`.
/// Botão principal e pílulas neutras são a tinta (`dynamicTextInk`); a seleção da marca usa a terracota
/// escura (`primarySelection`); a terracota viva (`marca`) é acento e botão de destaque, nunca fundo de tela.
public enum FrilaCor {
    private static let recursos = bundleApresentacao
    /// Botão principal e pílula neutra ativa (`dynamicTextInk`): #090908 no claro, branco no escuro.
    public static let primaria = Color("BrandPrimary", bundle: recursos)
    /// Texto sobre `primaria`: a tela (`dynamicCanvas`).
    public static let sobrePrimaria = Color("BrandOnPrimary", bundle: recursos)
    /// Terracota de seleção (`primarySelection`, #C9470F): filtro ativo, escolha confirmada.
    public static let selecao = Color("BrandSelection", bundle: recursos)
    /// Texto sobre `selecao`: branco nos dois modos (`dynamicBrandSolidText`).
    public static let sobreSelecao = Color("BrandOnSelection", bundle: recursos)
    /// Tela (`dynamicCanvas`): branco no claro, #111111 no escuro.
    public static let fundo = Color("Surface", bundle: recursos)
    /// A cortina UIKit usa o mesmo fundo das telas SwiftUI, inclusive no modo escuro.
    static let fundoUIKit = UIColor(named: "Surface", in: recursos, compatibleWith: nil) ?? .systemBackground
    /// Cartões e folhas sobre a tela (`dynamicFormCardSurface`): #FAFAFA / #171717.
    public static let superficie = Color("SurfaceElevated", bundle: recursos)
    /// Preenchimento dos campos de formulário (`dynamicFormFieldSurface`).
    public static let superficieDoCampo = Color("FieldSurface", bundle: recursos)
    /// Fio de 1 pt dos campos (`dynamicFormFieldBorder`): 3:1 sobre a tela e sobre o cartão.
    public static let bordaDoCampo = Color("FieldBorder", bundle: recursos)
    public static let texto = Color("TextPrimary", bundle: recursos)
    /// O mesmo token para o UIKit, pelo catálogo: segue claro e escuro sozinho.
    static let textoUIKit = UIColor(named: "TextPrimary", in: recursos, compatibleWith: nil) ?? .label
    /// Texto de apoio (`dynamicFormTextMuted`, #6B6B6B): 5,1:1 sobre o cartão; o `dynamicTextMuted` da origem (#767571) ficava em 4,4:1.
    public static let textoSecundario = Color("TextSecondary", bundle: recursos)
    public static let sucesso = Color("Success", bundle: recursos)
    public static let alerta = Color("Warning", bundle: recursos)
    public static let perigo = Color("Danger", bundle: recursos)
    /// Terracota da marca (`dynamicBrandAccent`, #EA5A36). Acento e botão de destaque do Estúdio (texto grande); nunca texto corrido.
    public static let marca = Color("BrandAccent", bundle: recursos)
    /// Preenchimento de controle e de aviso neutro (`dynamicInputBg`).
    public static let controle = Color("ControlFill", bundle: recursos)
    /// Fio de 1 pt de cartões e divisórias (`dynamicHairline`).
    public static let divisoria = Color("Hairline", bundle: recursos)
    /// Contorno de chip inativo e botão de contorno (`dynamicBorder`). Campo usa `bordaDoCampo`.
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

/// Raios do Hi-Fi (`FrilaGeometry`): 8 aninhado, 14 campo, 16 cartão, 24 folha; botões são sempre cápsula.
public enum FrilaRaio {
    /// Elemento aninhado dentro de um cartão (`radiusNested`).
    public static let pequeno: CGFloat = FrilaGeometry.radiusNested
    /// Campo de formulário (`radiusInput`).
    public static let entrada: CGFloat = FrilaGeometry.radiusInput
    public static let medio: CGFloat = FrilaGeometry.radiusInput
    /// Cartão (`radiusCard`).
    public static let cartao: CGFloat = FrilaGeometry.radiusCard
    /// Avisos e blocos de informação: o mesmo raio do cartão.
    public static let aviso: CGFloat = FrilaGeometry.radiusCard
    public static let grande: CGFloat = FrilaGeometry.radiusCard
    /// Topo das folhas (`radiusSheet`).
    public static let folha: CGFloat = FrilaGeometry.radiusSheet
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

/// Tipografia. Os papéis das telas leem a escala Minor Third da origem (`FrilaTypeScaleStep`: 11/13/15/18/22/26/32)
/// e as specs do paradigma Swiss (`FrilaTypography`: display, title, placard, entity, body, caption, micro, metric),
/// sempre com Dynamic Type (`FrilaFonteDoSistema.fonte` mede pelo estilo mais próximo). A Bricolage Grotesque é a voz
/// das perguntas e respostas dos formulários (`FrilaFormType`); números e dinheiro ficam sempre em SF Pro.
public enum FrilaTipo {
    /// Título da tela fora da barra: display 32 heavy, tracking −0.8 (`FrilaTypography.display`).
    public static let tituloGrande = FrilaTypography.display
    /// Cabeçalho de seção ("Abertas", "Seus dados"): title 22 bold (`FrilaTypography.title`).
    public static let secao = FrilaTypography.title
    /// Título da placa aberta (função no detalhe da vaga): titleLarge 26 bold, tracking −0.5,
    /// o degrau da escala mais próximo do título de 28 pt do detalhe da origem.
    public static let tituloDoDetalhe = FrilaTypography.titleLarge
    /// Subtítulo abaixo do título da tela: placard 18 medium.
    public static let subtituloDaTela = FrilaTypography.placard
    /// Rótulo do campo: SF Pro Semibold 13 (`FrilaFormType.fieldLabel`), como nos campos do Estúdio.
    public static let rotuloDoCampo = FrilaFormType.fieldLabel.font
    /// Texto digitado no campo: SF Pro Regular 17 (`FrilaFormType.input`).
    public static let valorDoCampo = FrilaFormType.input.font
    /// Rótulo de chip e filtro: caption 13 bold.
    public static let chip = FrilaTypography.captionBold
    /// Título do cartão (placa de museu): placard 18 medium.
    public static let tituloDoCartao = FrilaTypography.placard
    /// Corpo de leitura: body 15 regular.
    public static let corpo = FrilaTypography.body
    /// Meta e apoio (linhas de dados, legendas): caption 13 regular.
    public static let meta = FrilaTypography.caption
    /// Aviso neutro ou contextual: apoio 15 regular (`FrilaFormType.support`).
    public static let aviso = FrilaFormType.support.font
    /// Nota de rodapé e ajuda: caption 13 regular.
    public static let nota = FrilaTypography.caption
    /// Linha de destaque (nome da casa, resumo): entity 15 bold (`FrilaTypography.entity`).
    public static let resumo = FrilaTypography.entity
    /// Preço fora da etiqueta (`FrilaPriceTag`): métrica compacta 18 bold, dígitos tabulares.
    public static let preco = FrilaTypography.metricCompact.monospacedDigit()
    /// Título de estado (vazio, erro, concluído): title 22 bold.
    public static let tituloDeEstado = FrilaTypography.title
    /// Título de folha: placard 18 medium.
    public static let tituloDaFolha = FrilaTypography.placard
    /// Rótulo do botão grande (52 pt): SF Pro Bold 18, o `prominent` da origem.
    public static let botao = FrilaTypography.sans(size: FrilaTypeScaleStep.placard.pointSize, weight: .bold)
    /// Rótulo do botão padrão (44 pt) e dos chips: SF Pro Semibold 15 (`FrilaTypography.button`).
    public static let botaoPadrao = FrilaTypography.button

    /// Pergunta do formulário: Bricolage Bold 26 (`FrilaFormType.question`), acompanha `.title`.
    public static var pergunta: Font { FrilaFormType.question.dynamicFont }
    /// Resposta escolhida no formulário: Bricolage Bold 17 (`FrilaFormType.answer`), acompanha `.body`.
    public static var respostaEscolhida: Font { FrilaFormType.answer.dynamicFont }
    /// Contexto da resposta: Bricolage Regular 17 (`FrilaFormType.answerContext`), acompanha `.body`.
    public static var contextoDaResposta: Font { FrilaFormType.answerContext.dynamicFont }
    /// Microrrótulo em caixa alta (use com `.textCase(.uppercase)` e `.tracking(0.8)`): `FrilaFormType.microLabel`.
    public static let microRotulo = FrilaFormType.microLabel.font
}

/// Registra as fontes do bundle no processo, uma vez. Se falhar, o `Font.custom` cai na fonte do sistema.
/// Bricolage Grotesque (OFL 1.1, `Resources/Fonts`): Regular, Medium, Bold e ExtraBold, os quatro pesos do Hi-Fi.
public enum FontesFrila {
    public static let nomes = ["BricolageGrotesque-Regular", "BricolageGrotesque-Medium", "BricolageGrotesque-Bold", "BricolageGrotesque-ExtraBold"]

    static let registradas: Void = {
        for nome in nomes {
            guard let url = bundleApresentacao.url(forResource: nome, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    public static func registrar() {
        _ = registradas
    }
}

/// Ponto único para controle de animações respeitando a preferência de Reduzir Movimento (#71.4).
/// Quando `reduzir` é verdadeiro, retorna `nil` para que a transição ocorra de forma imediata sem deslocamento.
public enum FrilaMovimento {
    /// Compressão padrão para botões ao pressionar (0,96): `FrilaMotion.pressScaleButton`.
    public static let pressScaleBotao: CGFloat = FrilaMotion.pressScaleButton
    /// Compressão tátil para chips e pílulas compactas (0,94): `FrilaMotion.pressScaleChip`.
    public static let pressScaleChip: CGFloat = FrilaMotion.pressScaleChip
    /// Mola tátil dos botões (350/25): `FrilaMotion.tactileSpring`.
    public static let molaTatil: Animation = FrilaMotion.tactileSpring
    /// Mola dos chips (380/24): `FrilaMotion.chipPressSpring`.
    public static let molaTatilChip: Animation = FrilaMotion.chipPressSpring

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
    /// Cartão da origem (`FrilaOpportunityCard`): fundo do canvas, raio 16 contínuo, fio de 1 pt e sombra sutil.
    func cartaoFrila() -> some View {
        modifier(CartaoFrilaModificador())
    }

    /// Aplica o sistema Beautiful Shadows com três camadas coordenadas (rim, key, ambient).
    /// Sem sombra nos cartões com fio de 1 pt; sombra calibrada para folhas e docas.
    func elevacaoFrila(_ elevacao: FrilaElevacao) -> some View {
        modifier(ModificadorElevacaoFrila(elevacao))
    }

    /// Aplica fundo com material translúcido nativo do SwiftUI para efeito de vidro seguro no iOS 17+ (DP-02).
    @ViewBuilder
    func vidroFrila(_ material: Material = FrilaMaterial.padrao, raio: CGFloat = FrilaRaio.folha) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: raio, style: .continuous))
        } else {
            background(material, in: RoundedRectangle(cornerRadius: raio, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: raio, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        }
    }
}

/// Anatomia do cartão da origem, lendo o tema para a sombra (`FrilaShadowElevation.subtle`).
private struct CartaoFrilaModificador: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(FrilaGeometry.space20)
            .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .frilaShadow(.subtle, isDark: colorScheme == .dark)
    }
}
