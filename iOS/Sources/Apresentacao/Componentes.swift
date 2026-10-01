import FrilaDominio
import SwiftUI

public struct BotaoPrimario: View {
    private let titulo: Text
    private let carregando: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = Text(titulo)
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
                else { titulo.font(.headline).multilineTextAlignment(.center) }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
            // Sem isto o estilo `.plain` só recebe toque perto do texto: o frame de 44 pt é
            // transparente e a borda do botão não responde (medido no catálogo, #139).
            .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrilaCor.sobrePrimaria)
        .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
        .disabled(carregando)
        .accessibilityValue(carregando ? Text("Carregando") : Text(""))
    }
}

public struct BotaoSecundario: View {
    private let titulo: LocalizedStringKey
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            Text(titulo).font(.headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
        }
            .buttonStyle(.plain)
            .foregroundStyle(FrilaCor.primaria)
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.primaria, lineWidth: 1.5))
    }
}

public struct CampoFrila: View {
    private let titulo: Text
    @Binding private var texto: String

    public init(_ titulo: LocalizedStringKey, texto: Binding<String>) {
        self.titulo = Text(titulo)
        _texto = texto
    }

    public init(verbatim titulo: String, texto: Binding<String>) {
        self.titulo = Text(verbatim: titulo)
        _texto = texto
    }

    public var body: some View {
        TextField(text: $texto, prompt: titulo) { titulo }
            .textFieldStyle(.plain)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.textoSecundario.opacity(0.35)))
            .accessibilityLabel(titulo)
    }
}

public struct CampoCodigo: View {
    @Binding private var codigo: String

    public init(codigo: Binding<String>) { _codigo = codigo }

    public var body: some View {
        TextField("Código de acesso", text: $codigo)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.title2.monospacedDigit())
            .multilineTextAlignment(.center)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(minHeight: 56)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .accessibilityHint("Digite os seis números enviados para seu e-mail")
    }
}

public struct FiltroPill: View {
    private let titulo: Text
    private let selecionado: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, selecionado: Bool, acao: @escaping () -> Void) {
        self.titulo = Text(titulo)
        self.selecionado = selecionado
        self.acao = acao
    }

    public init(verbatim titulo: String, selecionado: Bool, acao: @escaping () -> Void) {
        self.titulo = Text(verbatim: titulo)
        self.selecionado = selecionado
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            titulo.font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selecionado ? FrilaCor.sobrePrimaria : FrilaCor.texto)
        .background(selecionado ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
        .accessibilityAddTraits(selecionado ? .isSelected : [])
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
        guard !reputacao.semHistorico else { return nil }
        if reputacao.turnosConsiderados == 1 {
            return String(localized: "Compareceu a \(reputacao.turnosRealizados) de \(reputacao.turnosConsiderados) turno", bundle: bundleApresentacao)
        }
        return String(localized: "Compareceu a \(reputacao.turnosRealizados) de \(reputacao.turnosConsiderados) turnos", bundle: bundleApresentacao)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Label(Self.descricao(reputacao), systemImage: reputacao.semHistorico ? "person.crop.circle.badge.questionmark" : "hand.thumbsup.fill")
                .font(.subheadline.weight(.semibold))
            if reputacao.semHistorico {
                Text(String(localized: "Ainda não há turnos considerados.", bundle: bundleApresentacao))
                    .font(.caption)
            } else {
                if let comparecimento = Self.descricaoComparecimento(reputacao) {
                    Text(verbatim: comparecimento).font(.caption)
                }
            }
        }
        .foregroundStyle(reputacao.semHistorico ? FrilaCor.textoSecundario : FrilaCor.sucesso)
        .accessibilityElement(children: .combine)
    }
}

public struct AvisoFrila: View {
    public enum Tom { case informativo, alerta, erro }
    private enum Conteudo {
        case localizado(LocalizedStringKey)
        case literal(String)
    }
    private let conteudo: Conteudo
    private let tom: Tom

    public init(_ texto: LocalizedStringKey, tom: Tom = .informativo) {
        self.conteudo = .localizado(texto)
        self.tom = tom
    }

    public init(verbatim: String, tom: Tom = .informativo) {
        self.conteudo = .literal(verbatim)
        self.tom = tom
    }

    public var body: some View {
        Label {
            switch conteudo {
            case let .localizado(chave):
                Text(chave, bundle: bundleApresentacao)
            case let .literal(texto):
                Text(verbatim: texto)
            }
        } icon: {
            Image(systemName: icone)
        }
        .font(.callout)
        .foregroundStyle(cor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
        .accessibilityElement(children: .combine)
    }

    private var cor: Color { switch tom { case .informativo: FrilaCor.primaria; case .alerta: FrilaCor.alerta; case .erro: FrilaCor.perigo } }
    private var icone: String { switch tom { case .informativo: "info.circle.fill"; case .alerta: "exclamationmark.triangle.fill"; case .erro: "xmark.octagon.fill" } }
}


public struct CartaoVaga: View {
    private let vaga: VagaNaLista
    private let formatador = FormatadorFrila()
    public init(_ vaga: VagaNaLista) { self.vaga = vaga }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            // Lado a lado quando cabem numa linha; empilhados nos tamanhos grandes, em que o HStack
            // quebrava a função no meio da palavra ("Gar-çom") para caber ao lado do valor.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { funcao; Spacer(); valor }
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) { funcao; valor }
            }
            Text(vaga.estabelecimento.nome).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
            Label(formatador.intervalo(vaga.periodo), systemImage: "calendar")
            // O contrato traz o local como texto; o app mostra como vem, sem tentar extrair bairro.
            Label("\(distancia) · \(vaga.local)", systemImage: "mappin.and.ellipse")
            if !inclusos.isEmpty { Label(inclusos, systemImage: "checkmark.circle") }
            SeloReputacao(vaga.estabelecimento.reputacao)
            Text("\(vaga.posicoesAbertas) vagas abertas", bundle: bundleApresentacao).font(.caption)
        }
        .font(.subheadline)
        .foregroundStyle(FrilaCor.texto)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rotuloDeAcessibilidade)
    }

    private var funcao: some View { Text(vaga.funcao.nome).font(.headline) }
    private var valor: some View { Text(formatador.dinheiro(vaga.valor)).font(.headline).foregroundStyle(FrilaCor.primaria) }

    public var rotuloDeAcessibilidade: String {
        var partes = [
            String(localized: "Vaga de \(vaga.funcao.nome)"),
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
        partes.append(String(localized: "\(vaga.posicoesAbertas) vagas abertas", bundle: bundleApresentacao))
        return partes.joined(separator: ", ")
    }

    private var distancia: String {
        formatador.distancia(vaga.distanciaKm)
    }

    private var inclusos: String {
        var itens: [String] = []
        if vaga.inclusos.refeicao { itens.append(String(localized: "Refeição")) }
        if vaga.inclusos.transporte { itens.append(String(localized: "Transporte")) }
        return itens.joined(separator: " · ")
    }
}

public struct RespostaSimNao: View {
    @Binding private var resposta: Bool?
    private let rotuloAcessibilidade: LocalizedStringKey

    public init(resposta: Binding<Bool?>, rotuloAcessibilidade: LocalizedStringKey = "Chamaria de novo?") {
        self._resposta = resposta
        self.rotuloAcessibilidade = rotuloAcessibilidade
    }

    public var body: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            escolha("Sim", valor: true, icone: "hand.thumbsup.fill")
            escolha("Não", valor: false, icone: "hand.thumbsdown.fill")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rotuloAcessibilidade)
    }

    private func escolha(_ titulo: LocalizedStringKey, valor: Bool, icone: String) -> some View {
        Button { resposta = valor } label: {
            Label(titulo, systemImage: icone).frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
        }
        .buttonStyle(.plain)
        .foregroundStyle(resposta == valor ? FrilaCor.sobrePrimaria : FrilaCor.texto)
        .background(resposta == valor ? FrilaCor.primaria : FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
        .accessibilityAddTraits(resposta == valor ? .isSelected : [])
    }
}

public struct FolhaFrila<Conteudo: View>: View {
    private let titulo: LocalizedStringKey
    @ViewBuilder private let conteudo: () -> Conteudo
    public init(_ titulo: LocalizedStringKey, @ViewBuilder conteudo: @escaping () -> Conteudo) { self.titulo = titulo; self.conteudo = conteudo }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Capsule().fill(FrilaCor.textoSecundario.opacity(0.4)).frame(width: 40, height: 5).frame(maxWidth: .infinity)
            Text(titulo).font(.title2.bold())
            conteudo()
        }
        .padding(FrilaEspaco.grande)
        .background(FrilaCor.fundo)
    }
}
