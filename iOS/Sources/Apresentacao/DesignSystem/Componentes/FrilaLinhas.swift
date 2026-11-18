import SwiftUI

/// Componentes de linha do sistema do Fabrício (`GrupoDeLinhas`, `LinhaDeOpcao`, `LinhaDeDado` e
/// `EstiloDeLinhaTocavel` do redesign; D-DS-18). Levam o prefixo `Frila` porque a Conta já tem um
/// `GrupoDeLinhas` próprio, de lista aberta entre fios.

/// As medidas das linhas de um `FrilaGrupoDeLinhas`, que a divisória usa para se alinhar ao texto.
public enum FrilaMedidaDeLinha {
    /// A margem interna do cartão, dos dois lados.
    public static let margem = FrilaEspaco.bloco
    /// A área quadrada do ícone, antes do Dynamic Type.
    public static let areaDoIcone: CGFloat = 40
    /// Da área do ícone até o texto. Com o glifo de 24 pt centrado em 40, o vão visível fica em 16.
    public static let espacoAteOTexto = FrilaEspaco.item
}

/// Cartão de grupo: linhas num cartão em `superficie`, raio 16, contorno em `borda`, sem sombra, com uma divisória de
/// 1 pt entre cada linha. A divisória começa onde o texto das linhas começa, não no ícone.
/// Cada vista direta do conteúdo é uma linha; para juntar duas vistas numa linha só, embrulhe-as num `VStack`.
public struct FrilaGrupoDeLinhas<Conteudo: View>: View {
    private let titulo: Text?
    private let linhasComIcone: Bool
    private let conteudo: Conteudo
    @ScaledMetric(relativeTo: .body) private var areaDoIcone = FrilaMedidaDeLinha.areaDoIcone

    public init(verbatim titulo: String? = nil, linhasComIcone: Bool = true, @ViewBuilder conteudo: () -> Conteudo) {
        self.titulo = titulo.map { Text(verbatim: $0) }
        self.linhasComIcone = linhasComIcone
        self.conteudo = conteudo()
    }

    public var body: some View {
        let forma = RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous)
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if let titulo {
                titulo
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            // `_VariadicView` é o que separa as linhas no iOS 17 (o `Group(subviews:)` é do iOS 18).
            _VariadicView.Tree(LinhasComDivisoria(recuo: recuo)) { conteudo }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FrilaCor.superficie)
                .clipShape(forma)
                .overlay(forma.strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        }
    }

    private var recuo: CGFloat {
        linhasComIcone ? FrilaMedidaDeLinha.margem + areaDoIcone + FrilaMedidaDeLinha.espacoAteOTexto : FrilaMedidaDeLinha.margem
    }
}

private struct LinhasComDivisoria: _VariadicView_MultiViewRoot {
    let recuo: CGFloat

    func body(children: _VariadicView.Children) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { linha in
                if linha.id != children.first?.id {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)
                        .padding(.leading, recuo)
                        .accessibilityHidden(true)
                }
                linha
            }
        }
    }
}

/// O glifo de 24 pt numa área de 40 × 40 das linhas de grupo. Os dois crescem com o Dynamic Type.
public struct FrilaIconeDeLinha: View {
    private let simbolo: String
    @ScaledMetric(relativeTo: .body) private var area = FrilaMedidaDeLinha.areaDoIcone

    public init(_ simbolo: String) { self.simbolo = simbolo }

    public var body: some View {
        Image(systemName: simbolo)
            .font(.title3)
            .foregroundStyle(FrilaCor.texto)
            .frame(width: area, height: area)
            .accessibilityHidden(true)
    }
}

/// O toque numa linha: a superfície pressionada atrás, sem mudar a cor do texto (D-DS-03).
public struct EstiloDeLinhaTocavel: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? FrilaCor.superficiePressionada : Color.clear)
            .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento, somenteOpacidade: true),
                       value: configuration.isPressed)
    }
}

/// Uma linha tocável de um `FrilaGrupoDeLinhas`: ícone opcional, título, subtítulo opcional e, à direita, o que a
/// linha faz. `marcada` é a escolha única (check em tinta, só quando marcada, sem laranja e sem fundo de cor);
/// `navega` é a linha que abre outra tela (seta discreta).
public struct FrilaLinhaDeOpcao: View {
    public enum Remate: Equatable, Sendable {
        case marcada(Bool)
        case navega
        case nenhum
    }

    private let icone: String?
    private let titulo: String
    private let subtitulo: String?
    private let remate: Remate
    private let acao: () -> Void

    public init(icone: String? = nil, titulo: String, subtitulo: String? = nil, remate: Remate, acao: @escaping () -> Void) {
        self.icone = icone
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.remate = remate
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            HStack(spacing: FrilaMedidaDeLinha.espacoAteOTexto) {
                if let icone { FrilaIconeDeLinha(icone) }
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: titulo)
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                    if let subtitulo, !subtitulo.isEmpty {
                        Text(verbatim: subtitulo)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                simboloDoRemate
            }
            .padding(.horizontal, FrilaMedidaDeLinha.margem)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloDeLinhaTocavel())
        .accessibilityAddTraits(remate == .marcada(true) ? .isSelected : [])
    }

    @ViewBuilder
    private var simboloDoRemate: some View {
        switch remate {
        case .marcada(true):
            Image(systemName: "checkmark")
                .font(FrilaTipo.corpo.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
        case .navega:
            Image(systemName: "chevron.forward")
                .font(FrilaTipo.apoio.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
        case .marcada(false), .nenhum:
            EmptyView()
        }
    }
}

/// Linha de dado: ícone de 20 e texto em corpo, com 8 entre os dois; o ícone fica na primeira linha.
/// O valor vai em tinta; um qualificador opcional segue na mesma frase, em `textoSecundario`.
public struct FrilaLinhaDeDado<Conteudo: View>: View {
    private let icone: String
    private let conteudo: Conteudo
    @ScaledMetric(relativeTo: .callout) private var larguraDoIcone: CGFloat = 20

    public init(icone: String, @ViewBuilder conteudo: () -> Conteudo) {
        self.icone = icone
        self.conteudo = conteudo()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
            Image(systemName: icone)
                .font(FrilaTipo.corpo.weight(.medium))
                .foregroundStyle(FrilaCor.texto)
                .frame(width: larguraDoIcone)
                .accessibilityHidden(true)
            conteudo
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
    }
}

/// Linha fina entre grupos de um cartão ou de um detalhe, com 16 acima e abaixo.
public struct FrilaDivisoria: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(FrilaCor.divisoria)
            .frame(height: 1)
            .padding(.vertical, FrilaEspaco.bloco)
            .accessibilityHidden(true)
    }
}
