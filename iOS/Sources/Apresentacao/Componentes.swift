import FrilaDominio
import SwiftUI

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
                else { titulo.font(FrilaTipo.botao).multilineTextAlignment(.center) }
            }
            .padding(.horizontal, FrilaEspaco.grande)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            // Sem isto o estilo `.plain` só recebe toque perto do texto: o frame é
            // transparente e a borda do botão não responde (medido no catálogo, #139).
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrilaCor.sobrePrimaria)
        // Pílula escura do MidFi (`selectionFill`), 52 pt.
        .background(FrilaCor.primaria, in: Capsule())
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
            titulo.font(FrilaTipo.botao).multilineTextAlignment(.center)
                .padding(.horizontal, FrilaEspaco.grande)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .contentShape(Capsule())
        }
            .buttonStyle(.plain)
            .foregroundStyle(FrilaCor.texto)
            // Botão de contorno do MidFi: superfície clara com fio de controle.
            .background(FrilaCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
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
            .background(FrilaCor.superficie, in: Capsule())
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
        TextField(text: $texto, prompt: titulo) { titulo }
            .textFieldStyle(.plain)
            .font(FrilaTipo.valorDoCampo)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            .accessibilityLabel(titulo)
            .accessibilityHint(Text(verbatim: erroDeCampo ?? ""))
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
            .font(.title2.monospacedDigit())
            .multilineTextAlignment(.center)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(minHeight: 56)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            .accessibilityHint(erroDeCampo.map { Text(verbatim: $0) } ?? Text("Digite os seis números enviados para seu e-mail", bundle: bundleApresentacao))
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
            .foregroundStyle(selecionado ? FrilaCor.sobrePrimaria : FrilaCor.texto)
            .background(selecionado ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
            // Chip de 32 pt visíveis dentro de um alvo de 44 pt.
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                Text(verbatim: Self.descricao(reputacao)).font(FrilaTipo.nota.weight(.semibold)).foregroundStyle(FrilaCor.texto)
            } icon: {
                Image(systemName: reputacao.semHistorico ? "person.crop.circle.badge.questionmark" : "person.badge.shield.checkmark")
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            if reputacao.semHistorico {
                Text(String(localized: "Ainda não há turnos considerados.", bundle: bundleApresentacao))
                    .font(FrilaTipo.nota)
            } else {
                if let comparecimento = Self.descricaoComparecimento(reputacao) {
                    Text(verbatim: comparecimento).font(FrilaTipo.nota)
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
        .font(.callout)
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

    private var cor: Color { switch tom { case .informativo: FrilaCor.texto; case .alerta: FrilaCor.alerta; case .erro: FrilaCor.perigo } }
    private var fundo: Color { tom == .informativo ? FrilaCor.controle : cor.opacity(0.12) }
    private var icone: String { switch tom { case .informativo: "info.circle.fill"; case .alerta: "exclamationmark.triangle.fill"; case .erro: "xmark.octagon.fill" } }
}


public struct CartaoVaga: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var larguraDoIcone: CGFloat = 24
    private let vaga: VagaNaLista
    private let formatador = FormatadorFrila()
    public init(_ vaga: VagaNaLista) { self.vaga = vaga }

    public var body: some View {
        // Cartão de turno do MidFi (`FrilaShiftCard`): cabeçalho, linhas com ícone, fio e reputação.
        VStack(alignment: .leading, spacing: FrilaEspaco.faixa) {
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
                // O contrato traz o local como texto; o app mostra como vem, sem tentar extrair bairro.
                linha("mappin.and.ellipse") { Text(verbatim: "\(distancia), \(vaga.local)") }
                if !inclusos.isEmpty {
                    linha("checkmark.circle") { Text(verbatim: inclusos) }
                }
                linha("person.2") { Text("\(vaga.posicoesAbertas) posições abertas", bundle: bundleApresentacao) }
            }
            Rectangle().fill(FrilaCor.divisoria).frame(height: 1).accessibilityHidden(true)
            SeloReputacao(vaga.estabelecimento.reputacao)
        }
        .font(FrilaTipo.meta)
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rotuloDeAcessibilidade)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: vaga.funcao.nome).font(FrilaTipo.resumo)
            Text(verbatim: vaga.estabelecimento.nome)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valor: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: FrilaEspaco.fio) {
            Text(verbatim: formatador.dinheiro(vaga.valor)).font(FrilaTipo.preco).monospacedDigit()
            Text("por turno", bundle: bundleApresentacao).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private func linha(_ icone: String, @ViewBuilder texto: () -> Text) -> some View {
        Label {
            texto().fixedSize(horizontal: false, vertical: true)
        } icon: {
            // Coluna de largura fixa: o texto das linhas começa no mesmo ponto, qualquer que seja o ícone.
            Image(systemName: icone).foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: larguraDoIcone)
        }
    }

    public var rotuloDeAcessibilidade: String {
        var partes = [
            String(localized: "Vaga de \(vaga.funcao.nome)", bundle: bundleApresentacao),
            vaga.estabelecimento.nome,
            formatador.intervalo(vaga.periodo),
            formatador.dinheiro(vaga.valor),
            "a \(distancia)",
            vaga.local
        ]
        if !inclusos.isEmpty {
            partes.append(inclusos)
        }
        partes.append(SeloReputacao.descricao(vaga.estabelecimento.reputacao))
        if let comparecimento = SeloReputacao.descricaoComparecimento(vaga.estabelecimento.reputacao) { partes.append(comparecimento) }
        partes.append(String(localized: "\(vaga.posicoesAbertas) posições abertas", bundle: bundleApresentacao))
        return partes.joined(separator: ", ")
    }

    private var distancia: String {
        formatador.distancia(vaga.distanciaKm)
    }

    private var inclusos: String {
        var itens: [String] = []
        if vaga.inclusos.refeicao { itens.append(String(localized: "Refeição", bundle: bundleApresentacao)) }
        if vaga.inclusos.transporte { itens.append(String(localized: "Transporte", bundle: bundleApresentacao)) }
        return itens.joined(separator: " · ")
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(resposta == valor ? FrilaCor.sobrePrimaria : FrilaCor.texto)
        .background(resposta == valor ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
        .overlay(Capsule().strokeBorder(resposta == valor ? Color.clear : FrilaCor.borda, lineWidth: 1))
        .accessibilityLabel(Text(titulo, bundle: bundleApresentacao))
        .accessibilityValue(Text(resposta == valor ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao))
        .accessibilityAddTraits(resposta == valor ? .isSelected : [])
        .accessibilityIdentifier(valor ? "resposta-sim" : "resposta-nao")
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
            titulo.font(FrilaTipo.tituloDaFolha).accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .padding(FrilaEspaco.grande)
        .background(FrilaCor.superficie)
    }
}
