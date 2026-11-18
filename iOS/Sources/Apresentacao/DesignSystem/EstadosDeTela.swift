import SwiftUI

public enum EstadoTela<Conteudo: Sendable>: Sendable {
    case carregando
    case vazio
    case conteudo(Conteudo)
    case erro(mensagem: String)
    case offline(Conteudo?)
    case pendente(mensagem: String)
}

/// Estado vazio (DESIGN.md do protótipo; `EstadoVazio.swift` do redesign): o fato em corpo, uma dica em apoio e
/// uma ação opcional em botão secundário da largura do rótulo. Sem cartão, sem ícone e sem laranja: o vazio não decide nada.
public struct EstadoVazio: View {
    private let titulo: Text
    private let mensagem: Text
    private let acao: (rotulo: Text, executar: () -> Void)?

    public init(_ titulo: LocalizedStringKey, mensagem: LocalizedStringKey) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        self.mensagem = Text(mensagem, bundle: bundleApresentacao)
        self.acao = nil
    }

    public init(verbatim titulo: String, mensagem: String) {
        self.titulo = Text(verbatim: titulo)
        self.mensagem = Text(verbatim: mensagem)
        self.acao = nil
    }

    /// Com ação: só quando existe um próximo passo que o campo da tela não é (o limpar de uma busca já é a ação dela).
    public init(verbatim titulo: String, mensagem: String, rotuloDaAcao: String, acao: @escaping () -> Void) {
        self.titulo = Text(verbatim: titulo)
        self.mensagem = Text(verbatim: mensagem)
        self.acao = (Text(verbatim: rotuloDaAcao), acao)
    }

    public var body: some View {
        MensagemDeEstado(titulo: titulo, mensagem: mensagem, acao: acao)
    }
}

public struct EstadoCarregando: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            FrilaSkeletonBone.concentric(outerRadius: FrilaRaio.cartao, padding: 0, height: 120, isDark: isDark)
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                FrilaSkeletonBone.pill(width: 160, height: 16, isDark: isDark)
                FrilaSkeletonBone.pill(width: 240, height: 12, isDark: isDark)
            }
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Carregando…", bundle: bundleApresentacao))
    }
}

public struct EstadoErro: View {
    @Environment(\.locale) private var locale
    private let conteudo: ConteudoDoAnuncio
    private var mensagem: Text { conteudo.texto(locale: locale) }
    private let tentarNovamente: () -> Void

    public init(_ mensagem: String.LocalizationValue, tentarNovamente: @escaping () -> Void) {
        self.conteudo = .localizado(mensagem)
        self.tentarNovamente = tentarNovamente
    }

    public init(verbatim mensagem: String, tentarNovamente: @escaping () -> Void) {
        self.conteudo = .literal(mensagem)
        self.tentarNovamente = tentarNovamente
    }

    public var body: some View {
        // Erro: o que falhou e o que fazer, em tinta. Tentar de novo é botão secundário: o laranja fica para a ação
        // que avança ou compromete, e uma tela de erro não é isso.
        MensagemDeEstado(titulo: Text("Algo deu errado", bundle: bundleApresentacao),
                         mensagem: mensagem,
                         acao: (Text("Tentar novamente", bundle: bundleApresentacao), tentarNovamente))
            .modifier(AnunciarAoAparecer(anuncio: .init(texto: String(conteudo.resolver(locale: locale).characters), tom: .erro)))
    }
}

public struct EstadoOffline: View {
    public init() {}
    public var body: some View { AvisoFrila("Sem conexão. Mostrando os dados salvos neste aparelho.", tom: .alerta) }
}

public struct EstadoPendente: View {
    private let mensagem: String.LocalizationValue
    public init(_ mensagem: String.LocalizationValue) { self.mensagem = mensagem }
    public var body: some View { AvisoFrila(mensagem, tom: .informativo) }
}

private struct MensagemDeEstado: View {
    let titulo: Text
    let mensagem: Text
    var acao: (rotulo: Text, executar: () -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            // O fato e a dica são um elemento só para o leitor de tela; o botão fica à parte.
            VStack(spacing: FrilaEspaco.item) {
                titulo
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                mensagem
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            if let acao {
                Button(action: acao.executar) { acao.rotulo }
                    .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                    // Largura do rótulo; com texto grande, a largura toda, para o rótulo quebrar em vez de vazar.
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
                    .padding(.top, FrilaEspaco.bloco)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.respiro)
        .padding(.bottom, FrilaEspaco.grupo)
    }
}
