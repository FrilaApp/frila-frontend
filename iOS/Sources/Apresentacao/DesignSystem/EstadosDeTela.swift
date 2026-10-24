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
        VStack(spacing: FrilaEspaco.medio) {
            MensagemDeEstado(icone: "exclamationmark.triangle",
                             titulo: Text("Algo deu errado", bundle: bundleApresentacao),
                             mensagem: mensagem)
            // Ação de recuperação do MidFi: pílula escura.
            BotaoPrimario("Tentar novamente", acao: tentarNovamente)
        }
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
    let icone: String
    let titulo: Text
    let mensagem: Text

    var body: some View {
        // Estado Hi-Fi: ícone limpo sem círculo, título em placard e apoio em meta centralizados.
        VStack(spacing: FrilaEspaco.compacto) {
            Image(systemName: icone)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
            VStack(spacing: FrilaEspaco.minimo) {
                titulo
                    .font(FrilaTipo.tituloDoCartao)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                mensagem
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, FrilaEspaco.grande)
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}
