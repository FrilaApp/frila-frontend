import FrilaDominio
import SwiftUI

public struct BotaoPrimario: View {
    private let titulo: LocalizedStringKey
    private let carregando: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.carregando = carregando
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            Group {
                if carregando { ProgressView().tint(FrilaCor.sobrePrimaria) }
                else { Text(titulo).font(.headline) }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
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
        Button(action: acao) { Text(titulo).font(.headline).frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo) }
            .buttonStyle(.plain)
            .foregroundStyle(FrilaCor.primaria)
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.primaria, lineWidth: 1.5))
    }
}

public struct CampoFrila: View {
    private let titulo: LocalizedStringKey
    @Binding private var texto: String

    public init(_ titulo: LocalizedStringKey, texto: Binding<String>) {
        self.titulo = titulo
        _texto = texto
    }

    public var body: some View {
        TextField(titulo, text: $texto)
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
            .frame(minHeight: 56)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .accessibilityHint("Digite os seis números enviados para seu e-mail")
    }
}

public struct FiltroPill: View {
    private let titulo: LocalizedStringKey
    private let selecionado: Bool
    private let acao: () -> Void

    public init(_ titulo: LocalizedStringKey, selecionado: Bool, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.selecionado = selecionado
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            Text(titulo).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: FrilaMetrica.alvoMinimo)
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

    public var body: some View {
        Label(reputacao.descricao(), systemImage: reputacao.semHistorico ? "person.crop.circle.badge.questionmark" : "hand.thumbsup.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(reputacao.semHistorico ? FrilaCor.textoSecundario : FrilaCor.sucesso)
            .accessibilityElement(children: .combine)
    }
}

public struct AvisoFrila: View {
    public enum Tom { case informativo, alerta, erro }
    private let texto: LocalizedStringKey
    private let tom: Tom

    public init(_ texto: LocalizedStringKey, tom: Tom = .informativo) { self.texto = texto; self.tom = tom }

    public var body: some View {
        Label(texto, systemImage: icone)
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
            HStack(alignment: .firstTextBaseline) {
                Text(vaga.funcao.nome).font(.headline)
                Spacer()
                Text(formatador.dinheiro(vaga.valor)).font(.headline).foregroundStyle(FrilaCor.primaria)
            }
            Text(vaga.estabelecimento.nome).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
            Label(formatador.intervalo(vaga.periodo), systemImage: "calendar")
            Label(vaga.local, systemImage: "mappin.and.ellipse")
            Text("\(vaga.posicoesAbertas) vagas abertas").font(.caption)
        }
        .font(.subheadline)
        .foregroundStyle(FrilaCor.texto)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vaga de \(vaga.funcao.nome), \(vaga.estabelecimento.nome), \(formatador.intervalo(vaga.periodo)), \(formatador.dinheiro(vaga.valor))")
    }
}

public struct RespostaSimNao: View {
    @Binding private var resposta: Bool?
    public init(resposta: Binding<Bool?>) { _resposta = resposta }

    public var body: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            escolha("Sim", valor: true, icone: "hand.thumbsup.fill")
            escolha("Não", valor: false, icone: "hand.thumbsdown.fill")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chamaria de novo?")
    }

    private func escolha(_ titulo: LocalizedStringKey, valor: Bool, icone: String) -> some View {
        Button { resposta = valor } label: {
            Label(titulo, systemImage: icone).frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
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
