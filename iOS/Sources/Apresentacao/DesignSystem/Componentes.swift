import FrilaDominio
import SwiftUI

/// Estilo tátil canônico para botões do Frila (escala 0,96, mola interpolante 350/25).
/// Com Reduzir Movimento ativo: sem escala (1,0 imediato), mantendo atenuação de opacidade (0,92).
public struct EstiloBotaoTatil: ButtonStyle {
    public let reduceMotion: Bool
    public let scale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var envReduceMotion

    public init(reduceMotion: Bool = false, scale: CGFloat = FrilaMovimento.pressScaleBotao) {
        self.reduceMotion = reduceMotion
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = reduceMotion || envReduceMotion
        configuration.label
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? scale : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                FrilaMovimento.animacao(FrilaMovimento.molaTatil, reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

/// Estilo tátil para chips e pílulas compactas (escala 0,94, mola 380/24).
/// Garante que o alvo de toque permaneça ≥ 44 pt no layout do container.
/// Com Reduzir Movimento ativo: sem escala (1,0 imediato), mantendo atenuação de opacidade (0,92).
public struct EstiloChipTatil: ButtonStyle {
    public let reduceMotion: Bool
    public let scale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var envReduceMotion

    public init(reduceMotion: Bool = false, scale: CGFloat = FrilaMovimento.pressScaleChip) {
        self.reduceMotion = reduceMotion
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = reduceMotion || envReduceMotion
        configuration.label
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? scale : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                FrilaMovimento.animacao(FrilaMovimento.molaTatilChip, reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension ButtonStyle where Self == EstiloBotaoTatil {
    static var tatil: EstiloBotaoTatil { EstiloBotaoTatil() }
    static func tatil(reduceMotion: Bool = false, scale: CGFloat = FrilaMovimento.pressScaleBotao) -> EstiloBotaoTatil {
        EstiloBotaoTatil(reduceMotion: reduceMotion, scale: scale)
    }
}

public extension ButtonStyle where Self == EstiloChipTatil {
    static var chipTatil: EstiloChipTatil { EstiloChipTatil() }
    static func chipTatil(reduceMotion: Bool = false, scale: CGFloat = FrilaMovimento.pressScaleChip) -> EstiloChipTatil {
        EstiloChipTatil(reduceMotion: reduceMotion, scale: scale)
    }
}

public struct BotaoPrimario: View {
    private let titulo: Text
    private let carregando: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        self.carregando = carregando
        self.acao = acao
    }

    public init(verbatim titulo: String, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = Text(verbatim: titulo)
        self.carregando = carregando
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            Group {
                if carregando { ProgressView().tint(FrilaCor.sobrePrimaria) }
                else {
                    titulo
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, FrilaEspaco.grande)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(FrilaCor.sobrePrimaria)
            // Pílula `.ink` da origem (`dynamicTextInk`), 52 pt (`buttonHeightProminent`).
            .background(FrilaCor.primaria, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .disabled(carregando)
        // Enquanto carrega, o conteúdo é só o indicador: sem isto o botão perde o nome no VoiceOver.
        .accessibilityLabel(titulo)
        .accessibilityValue(carregando ? Text("Carregando", bundle: bundleApresentacao) : Text(verbatim: ""))
    }
}

public struct BotaoSecundario: View {
    private let titulo: Text
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, acao: @escaping () -> Void) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        self.acao = acao
    }

    public init(verbatim titulo: String, acao: @escaping () -> Void) {
        self.titulo = Text(verbatim: titulo)
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            titulo
                .font(FrilaTipo.botao)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, FrilaEspaco.grande)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .foregroundStyle(FrilaCor.texto)
                // Botão `.outline` da origem: sem preenchimento, fio de 1 pt (`dynamicBorder`).
                .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
    }
}

public extension View {
    /// Rótulo de ação destrutiva do MidFi (cancelar turno, ligar para a emergência, excluir conta):
    /// cápsula de contorno vermelho sobre a superfície, com a altura dos botões grandes.
    func capsulaDestrutiva() -> some View {
        font(FrilaTipo.botao)
            .multilineTextAlignment(.center)
            .foregroundStyle(FrilaCor.perigo)
            .padding(.horizontal, FrilaEspaco.grande)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .overlay(Capsule().strokeBorder(FrilaCor.perigo, lineWidth: 1.5))
            .contentShape(Capsule())
    }
}

public struct CampoFrila: View {
    @Environment(\.erroDeCampoFrila) private var erroDeCampo
    private let titulo: Text
    @Binding private var texto: String

    public init(_ titulo: LocalizedStringKey, texto: Binding<String>) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        _texto = texto
    }

    public init(verbatim titulo: String, texto: Binding<String>) {
        self.titulo = Text(verbatim: titulo)
        _texto = texto
    }

    public var body: some View {
        TextField(text: $texto, prompt: titulo.foregroundStyle(FrilaCor.textoSecundario)) { titulo }
            .textFieldStyle(.plain)
            .font(FrilaTipo.valorDoCampo)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            // Campo da origem (`FrilaJobFormLabeledField`): superfície e fio próprios, raio 14.
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
            .accessibilityLabel(titulo)
            .modifier(ErroLidoComoValor(texto: texto, erro: erroDeCampo))
    }
}

public struct CaixaDoCampoFrila: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
            )
    }
}

public extension View {
    func caixaDoCampoFrila() -> some View {
        modifier(CaixaDoCampoFrila())
    }
}


/// Faz o erro do campo ser lido como parte do valor ("texto, Erro: mensagem") e não como dica,
/// que o VoiceOver pode omitir. Sem erro, o campo mantém o valor padrão do sistema.
struct ErroLidoComoValor: ViewModifier {
    let texto: String
    let erro: String?

    static func valor(texto: String, erro: String?) -> String? {
        guard let erro, !erro.isEmpty else { return nil }
        let prefixo = String(localized: "Erro: ", bundle: bundleApresentacao)
        return texto.isEmpty ? prefixo + erro : "\(texto), \(prefixo)\(erro)"
    }

    func body(content: Content) -> some View {
        if let valor = Self.valor(texto: texto, erro: erro) {
            content.accessibilityValue(Text(verbatim: valor))
        } else {
            content
        }
    }
}

public struct CampoCodigo: View {
    @Environment(\.erroDeCampoFrila) private var erroDeCampo
    @Binding private var codigo: String

    public init(codigo: Binding<String>) { _codigo = codigo }

    public var body: some View {
        TextField(text: $codigo, prompt: Text("Código de acesso", bundle: bundleApresentacao)) {
            Text("Código de acesso", bundle: bundleApresentacao)
        }
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(FrilaTipo.secao.monospacedDigit())
            .multilineTextAlignment(.center)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
            .accessibilityHint(Text("Digite os seis números enviados para seu e-mail", bundle: bundleApresentacao))
            .modifier(ErroLidoComoValor(texto: codigo, erro: erroDeCampo))
    }
}

public struct FiltroPill: View {
    private let titulo: Text
    private let selecionado: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, selecionado: Bool, acao: @escaping () -> Void) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        self.selecionado = selecionado
        self.acao = acao
    }

    public init(verbatim titulo: String, selecionado: Bool, acao: @escaping () -> Void) {
        self.titulo = Text(verbatim: titulo)
        self.selecionado = selecionado
        self.acao = acao
    }

    public static func valorAcessibilidade(selecionado: Bool) -> String {
        selecionado ? String(localized: "filtro ativo", bundle: bundleApresentacao) : ""
    }

    public var body: some View {
        Button(action: acao) {
            HStack(spacing: FrilaEspaco.minimo) {
                if selecionado {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                titulo.font(selecionado ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.meta.weight(.medium))
            }
            .padding(.horizontal, FrilaEspaco.faixa)
            .frame(minHeight: FrilaMetrica.alturaDoChip)
            // Filtro ativo na terracota de seleção da origem (`FrilaFilterChip`); inativo sobre a superfície com fio.
            .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
            .background(selecionado ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
            // Garante área de toque mínima de 44 pt (Apple HIG / FrilaMetrica.alvoMinimo) com chip visual de 32 pt.
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.chipTatil)
        .accessibilityAddTraits(selecionado ? .isSelected : [])
        .accessibilityValue(Self.valorAcessibilidade(selecionado: selecionado))
    }
}

public struct SeloReputacao: View {
    private let reputacao: Reputacao
    public init(_ reputacao: Reputacao) { self.reputacao = reputacao }

    public static func descricao(_ reputacao: Reputacao) -> String {
        guard !reputacao.semHistorico else { return String(localized: "Sem histórico", bundle: bundleApresentacao) }
        return String(localized: "\(reputacao.positivas) de \(reputacao.total) chamariam de novo", bundle: bundleApresentacao)
    }

    public static func descricaoComparecimento(_ reputacao: Reputacao) -> String? {
        guard !reputacao.semHistorico, reputacao.turnosConsiderados > 0 else { return nil }
        if reputacao.turnosConsiderados == 1 {
            return String(localized: "Compareceu a \(reputacao.turnosRealizados) de \(reputacao.turnosConsiderados) turno", bundle: bundleApresentacao)
        }
        return String(localized: "Compareceu a \(reputacao.turnosRealizados) de \(reputacao.turnosConsiderados) turnos", bundle: bundleApresentacao)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Label {
                Text(verbatim: Self.descricao(reputacao))
                    .font(FrilaTipo.nota.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: reputacao.semHistorico ? "person.crop.circle.badge.questionmark" : "person.badge.shield.checkmark")
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            if reputacao.semHistorico {
                Text(String(localized: "Ainda não há turnos considerados.", bundle: bundleApresentacao))
                    .font(FrilaTipo.nota)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let comparecimento = Self.descricaoComparecimento(reputacao) {
                    Text(verbatim: comparecimento)
                        .font(FrilaTipo.nota)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // Reputação do MidFi: neutra, sem verde; o número em semibold carrega o destaque.
        .foregroundStyle(FrilaCor.textoSecundario)
        .accessibilityElement(children: .combine)
    }
}

public struct AvisoFrila: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Environment(\.locale) private var locale

    public enum Tom: Equatable, Sendable { case informativo, alerta, erro }
    private let conteudo: ConteudoDoAnuncio
    private let tom: Tom

    public init(_ texto: String.LocalizationValue, tom: Tom = .informativo) {
        self.conteudo = .localizado(texto)
        self.tom = tom
    }

    public init(verbatim: String, tom: Tom = .informativo) {
        self.conteudo = .literal(verbatim)
        self.tom = tom
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Image(systemName: icone)
                        .foregroundStyle(cor)
                        .accessibilityHidden(true)
                    textoView
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                    Image(systemName: icone)
                        .foregroundStyle(cor)
                        .accessibilityHidden(true)
                    textoView
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: Self.rotuloAcessibilidade(texto: String(textoResolvido.characters), tom: tom)))
        .modifier(AnunciarAoAparecer(anuncio: .init(texto: String(textoResolvido.characters), tom: tom)))
        .font(FrilaTipo.aviso)
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        // Bloco de aviso do MidFi: raio 16; o neutro usa o preenchimento de controle, os outros o tom da cor.
        .background(fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
    }

    public static func prefixo(tom: Tom) -> String {
        switch tom {
        case .alerta:
            return String(localized: "Alerta: ", bundle: bundleApresentacao)
        case .erro:
            return String(localized: "Erro: ", bundle: bundleApresentacao)
        case .informativo:
            return ""
        }
    }

    public static func rotuloAcessibilidade(texto: String, tom: Tom) -> String {
        "\(prefixo(tom: tom))\(texto)"
    }

    private var textoResolvido: AttributedString { conteudo.resolver(locale: locale) }
    private var textoView: Text { conteudo.texto(locale: locale) }

    private var cor: Color { FrilaCor.texto }
    private var fundo: Color { FrilaCor.controle }
    private var icone: String { switch tom { case .informativo: "info.circle.fill"; case .alerta: "exclamationmark.triangle.fill"; case .erro: "xmark.octagon.fill" } }
}


public struct CartaoVaga: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let vaga: VagaNaLista
    private let formatador = FormatadorFrila()
    public init(_ vaga: VagaNaLista) { self.vaga = vaga }

    public var body: some View {
        // Placa de museu da origem (`FrilaOpportunityCard`): entidade em caixa alta, título, grade de
        // dados entre dois fios, valor em métrica compacta; reputação fecha o cartão.
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) { cabecalho; valor }
            } else {
                // Lado a lado quando cabem numa linha; empilhados nos tamanhos grandes, em que o HStack
                // quebrava a função no meio da palavra ("Gar-çom") para caber ao lado do valor.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: FrilaEspaco.compacto) { cabecalho; Spacer(minLength: 0); valor }
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) { cabecalho; valor }
                }
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                linha("clock") { Text(verbatim: formatador.intervalo(vaga.periodo)) }
                linha("mappin") { Text(verbatim: localizacao) }
                linha("checkmark") { Text(verbatim: textoBeneficios) }
                linha("person") { Text(verbatim: posicoesTexto) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FrilaEspaco.pequeno)
            .overlay(alignment: .top) { fio }
            .overlay(alignment: .bottom) { fio }
            reputacaoEstabelecimento
        }
        .font(FrilaTipo.meta)
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rotuloDeAcessibilidade)
    }

    private var fio: some View {
        Rectangle().fill(FrilaCor.divisoria).frame(height: 1).accessibilityHidden(true)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: vaga.estabelecimento.nome)
                .font(FrilaTipo.resumo)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: vaga.funcao.nome)
                .font(FrilaTipo.tituloDoCartao)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valor: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: FrilaEspaco.fio) {
            Text(verbatim: formatador.dinheiro(vaga.valor)).font(FrilaTipo.preco).monospacedDigit()
            Text("por pessoa", bundle: bundleApresentacao).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rotuloAcessibilidadeValor)
    }

    public var rotuloAcessibilidadeValor: String {
        FrilaMoney.spoken(cents: vaga.valor.centavos, por: "pessoa")
    }

    private func linha(_ icone: String, @ViewBuilder texto: () -> Text) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: 16)
                .accessibilityHidden(true)

            texto()
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localizacao: String {
        let regiaoLimpa = vaga.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        let regiaoOuLocal = regiaoLimpa.isEmpty ? vaga.local : regiaoLimpa
        return "\(distancia), \(regiaoOuLocal)"
    }

    private var textoBeneficios: String {
        switch (vaga.inclusos.refeicao, vaga.inclusos.transporte) {
        case (true, true):
            return String(localized: "Refeição e transporte inclusos", bundle: bundleApresentacao)
        case (true, false):
            return String(localized: "Refeição inclusa, sem transporte", bundle: bundleApresentacao)
        case (false, true):
            return String(localized: "Sem refeição, transporte incluso", bundle: bundleApresentacao)
        case (false, false):
            return String(localized: "Sem refeição nem transporte", bundle: bundleApresentacao)
        }
    }

    private var posicoesTexto: String {
        if vaga.posicoesAbertas == 1 {
            return String(localized: "1 posição aberta", bundle: bundleApresentacao)
        } else {
            return String(localized: "\(vaga.posicoesAbertas) posições abertas", bundle: bundleApresentacao)
        }
    }

    @ViewBuilder
    private var reputacaoEstabelecimento: some View {
        let reputacao = vaga.estabelecimento.reputacao
        if reputacao.semHistorico {
            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text("Ainda sem avaliações.", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                (Text("\(reputacao.positivas) de \(reputacao.total)", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                + Text(" avaliações indicam que trabalhariam lá de novo", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reputacaoTexto: String {
        let reputacao = vaga.estabelecimento.reputacao
        if reputacao.semHistorico {
            return String(localized: "Ainda sem avaliações.", bundle: bundleApresentacao)
        } else {
            return String(localized: "\(reputacao.positivas) de \(reputacao.total) avaliações indicam que trabalhariam lá de novo", bundle: bundleApresentacao)
        }
    }

    public var rotuloDeAcessibilidade: String {
        let partes = [
            String(localized: "Vaga de \(vaga.funcao.nome)", bundle: bundleApresentacao),
            vaga.estabelecimento.nome,
            formatador.intervalo(vaga.periodo),
            rotuloAcessibilidadeValor,
            "a \(localizacao)",
            textoBeneficios,
            posicoesTexto,
            reputacaoTexto
        ]
        return partes.joined(separator: ", ")
    }

    private var distancia: String {
        formatador.distancia(vaga.distanciaKm)
    }
}

public struct RespostaSimNao: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding private var resposta: Bool?
    private let rotuloAcessibilidade: Text

    public init(resposta: Binding<Bool?>, rotuloAcessibilidade: LocalizedStringKey = "Chamaria de novo?") {
        self._resposta = resposta
        self.rotuloAcessibilidade = Text(rotuloAcessibilidade, bundle: bundleApresentacao)
    }

    public init(resposta: Binding<Bool?>, verbatim rotuloAcessibilidade: String) {
        self._resposta = resposta
        self.rotuloAcessibilidade = Text(verbatim: rotuloAcessibilidade)
    }

    public var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FrilaEspaco.pequeno))
            : AnyLayout(HStackLayout(spacing: FrilaEspaco.pequeno))
        layout {
            escolha("Sim", valor: true, icone: "hand.thumbsup.fill")
            escolha("Não", valor: false, icone: "hand.thumbsdown.fill")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rotuloAcessibilidade)
    }

    public static func exibeCheckmark(opcao: Bool, resposta: Bool?) -> Bool {
        opcao == resposta
    }

    private func escolha(_ titulo: LocalizedStringKey, valor: Bool, icone: String) -> some View {
        Button { resposta = valor } label: {
            HStack(spacing: FrilaEspaco.minimo) {
                if Self.exibeCheckmark(opcao: valor, resposta: resposta) {
                    Image(systemName: "checkmark")
                        .accessibilityIdentifier(valor ? "icone-checkmark-sim" : "icone-checkmark-nao")
                }
                Label {
                    Text(titulo, bundle: bundleApresentacao)
                } icon: {
                    Image(systemName: icone)
                }
            }
            .font(FrilaTipo.botao)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(resposta == valor ? FrilaCor.sobreSelecao : FrilaCor.texto)
            .background(resposta == valor ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(resposta == valor ? Color.clear : FrilaCor.borda, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .accessibilityLabel(Text(titulo, bundle: bundleApresentacao))
        .accessibilityValue(FrilaAcessibilidade.textoSelecao(selecionado: resposta == valor))
        .accessibilityAddTraits(resposta == valor ? .isSelected : [])
        .accessibilityIdentifier(valor ? "resposta-sim" : "resposta-nao")
    }
}

public enum FrilaAcessibilidade {
    public static func valorSelecao(selecionado: Bool) -> String {
        selecionado
            ? String(localized: "Selecionado", bundle: bundleApresentacao)
            : String(localized: "Não selecionado", bundle: bundleApresentacao)
    }

    public static func textoSelecao(selecionado: Bool) -> Text {
        Text(selecionado ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao)
    }
}

public struct FolhaFrila<Conteudo: View>: View {
    private let titulo: Text
    @ViewBuilder private let conteudo: () -> Conteudo
    public init(_ titulo: LocalizedStringKey, @ViewBuilder conteudo: @escaping () -> Conteudo) { self.titulo = Text(titulo, bundle: bundleApresentacao); self.conteudo = conteudo }
    public init(verbatim titulo: String, @ViewBuilder conteudo: @escaping () -> Conteudo) { self.titulo = Text(verbatim: titulo); self.conteudo = conteudo }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Capsule().fill(FrilaCor.puxador).frame(width: 36, height: 5).frame(maxWidth: .infinity).accessibilityHidden(true)
            titulo
                .font(FrilaTipo.tituloDaFolha)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .padding(FrilaEspaco.grande)
        .background(FrilaCor.superficie)
        .elevacaoFrila(.folha)
    }
}

public extension FrilaMoney {
    static func spoken(_ valor: Dinheiro, por unidade: String? = nil) -> String {
        spoken(cents: valor.centavos, por: unidade)
    }
}

public extension FormatadorFrila {
    func dinheiroFalado(_ valor: Dinheiro, por unidade: String? = nil) -> String {
        FrilaMoney.spoken(cents: valor.centavos, por: unidade)
    }
}
