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
    private let titulo: LocalizedStringKey?
    private let mensagem: LocalizedStringKey?
    private let tituloVerbatim: String?
    private let mensagemVerbatim: String?
    public init(_ titulo: LocalizedStringKey, mensagem: LocalizedStringKey) {
        self.titulo = titulo
        self.mensagem = mensagem
        self.tituloVerbatim = nil
        self.mensagemVerbatim = nil
    }
    public init(verbatim titulo: String, mensagem: String) {
        self.titulo = nil
        self.mensagem = nil
        self.tituloVerbatim = titulo
        self.mensagemVerbatim = mensagem
    }
    public var body: some View {
        if let titulo, let mensagem {
            MensagemDeEstado(icone: "tray", titulo: titulo, mensagem: mensagem)
        } else if let tituloVerbatim, let mensagemVerbatim {
            MensagemDeEstado(icone: "tray", tituloVerbatim: tituloVerbatim, mensagemVerbatim: mensagemVerbatim)
        }
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
    private let mensagem: LocalizedStringKey?
    private let mensagemVerbatim: String?
    private let tentarNovamente: () -> Void
    public init(_ mensagem: LocalizedStringKey, tentarNovamente: @escaping () -> Void) {
        self.mensagem = mensagem
        self.mensagemVerbatim = nil
        self.tentarNovamente = tentarNovamente
    }
    public init(verbatim mensagem: String, tentarNovamente: @escaping () -> Void) {
        self.mensagem = nil
        self.mensagemVerbatim = mensagem
        self.tentarNovamente = tentarNovamente
    }
    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) {
            VStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
                Text("Algo deu errado", bundle: bundleApresentacao).font(.headline)
                if let mensagem {
                    Text(mensagem, bundle: bundleApresentacao).font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
                } else if let mensagemVerbatim {
                    Text(verbatim: mensagemVerbatim).font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
                }
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
    var titulo: LocalizedStringKey? = nil
    var mensagem: LocalizedStringKey? = nil
    var tituloVerbatim: String? = nil
    var mensagemVerbatim: String? = nil

    var body: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone).font(.largeTitle).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
            if let titulo {
                Text(titulo, bundle: bundleApresentacao).font(.headline)
            } else if let tituloVerbatim {
                Text(verbatim: tituloVerbatim).font(.headline)
            }
            if let mensagem {
                Text(mensagem, bundle: bundleApresentacao).font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
            } else if let mensagemVerbatim {
                Text(verbatim: mensagemVerbatim).font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}
