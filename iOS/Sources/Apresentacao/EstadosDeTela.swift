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
    private let titulo: LocalizedStringKey
    private let mensagem: LocalizedStringKey
    public init(_ titulo: LocalizedStringKey, mensagem: LocalizedStringKey) { self.titulo = titulo; self.mensagem = mensagem }
    public var body: some View { MensagemDeEstado(icone: "tray", titulo: titulo, mensagem: mensagem) }
}

public struct EstadoCarregando: View {
    public init() {}
    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) { ProgressView(); Text("Carregando…").foregroundStyle(FrilaCor.textoSecundario) }
            .frame(maxWidth: .infinity, minHeight: 160)
            .accessibilityElement(children: .combine)
    }
}

public struct EstadoErro: View {
    private let mensagem: LocalizedStringKey
    private let tentarNovamente: () -> Void
    public init(_ mensagem: LocalizedStringKey, tentarNovamente: @escaping () -> Void) { self.mensagem = mensagem; self.tentarNovamente = tentarNovamente }
    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) {
            MensagemDeEstado(icone: "exclamationmark.triangle", titulo: "Algo deu errado", mensagem: mensagem)
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
    let titulo: LocalizedStringKey
    let mensagem: LocalizedStringKey
    var body: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone).font(.largeTitle).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
            Text(titulo).font(.headline)
            Text(mensagem).font(.body).foregroundStyle(FrilaCor.textoSecundario).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}
