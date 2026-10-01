import SwiftUI

public enum EstadoTela<Conteudo: Sendable>: Sendable {
    case carregando
    case vazio
    case conteudo(Conteudo)
    case erro(mensagem: String)
    case offline(Conteudo?)
    case pendente(mensagem: String)
}

public struct EstadoVazio: View {
    private let titulo: Text
    private let mensagem: Text

    public init(_ titulo: LocalizedStringKey, mensagem: LocalizedStringKey) {
        self.titulo = Text(titulo, bundle: bundleApresentacao)
        self.mensagem = Text(mensagem, bundle: bundleApresentacao)
    }

    public init(verbatim titulo: String, mensagem: String) {
        self.titulo = Text(verbatim: titulo)
        self.mensagem = Text(verbatim: mensagem)
    }

    public var body: some View {
        MensagemDeEstado(icone: "tray", titulo: titulo, mensagem: mensagem)
    }
}

public struct EstadoCarregando: View {
    public init() {}
    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) { ProgressView(); Text("Carregando…", bundle: bundleApresentacao).foregroundStyle(FrilaCor.textoSecundario) }
            .frame(maxWidth: .infinity, minHeight: 160)
            .accessibilityElement(children: .combine)
    }
}

public struct EstadoErro: View {
    private let mensagem: Text
    private let tentarNovamente: () -> Void

    public init(_ mensagem: LocalizedStringKey, tentarNovamente: @escaping () -> Void) {
        self.mensagem = Text(mensagem, bundle: bundleApresentacao)
        self.tentarNovamente = tentarNovamente
    }

    public init(verbatim mensagem: String, tentarNovamente: @escaping () -> Void) {
        self.mensagem = Text(verbatim: mensagem)
        self.tentarNovamente = tentarNovamente
    }

    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) {
            VStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
                Text("Algo deu errado", bundle: bundleApresentacao).font(.headline)
                mensagem.font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .accessibilityElement(children: .combine)
            BotaoSecundario("Tentar novamente", acao: tentarNovamente)
        }
    }
}

public struct EstadoOffline: View {
    public init() {}
    public var body: some View { AvisoFrila("Sem conexão. Mostrando os dados salvos neste aparelho.", tom: .alerta) }
}

public struct EstadoPendente: View {
    private let mensagem: LocalizedStringKey
    public init(_ mensagem: LocalizedStringKey) { self.mensagem = mensagem }
    public var body: some View { AvisoFrila(mensagem, tom: .informativo) }
}

private struct MensagemDeEstado: View {
    let icone: String
    let titulo: Text
    let mensagem: Text

    var body: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone).font(.largeTitle).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
            titulo.font(.headline)
            mensagem.font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}
