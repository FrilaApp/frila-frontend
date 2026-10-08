import Accessibility
import SwiftUI
import UIKit

/// Usa a mesma resolução para o texto visível e o falado, incluindo interpolação e Markdown.
enum ConteudoDoAnuncio {
    case localizado(String.LocalizationValue)
    case literal(String)

    func texto(locale: Locale) -> Text {
        switch self {
        case let .localizado(valor):
            Text(AttributedString(localized: valor, bundle: bundleApresentacao, locale: locale))
        case let .literal(texto):
            Text(verbatim: texto)
        }
    }

    func resolver(locale: Locale) -> AttributedString {
        switch self {
        case let .localizado(valor):
            AttributedString(localized: valor, bundle: bundleApresentacao, locale: locale)
        case let .literal(texto):
            AttributedString(texto)
        }
    }
}

struct AnuncioDeAcessibilidade: Equatable {
    let texto: String
    let tom: AvisoFrila.Tom

    var mensagem: AttributedString {
        var mensagem = AttributedString(texto)
        mensagem.accessibilitySpeechAnnouncementPriority = tom == .informativo ? .low : .high
        return mensagem
    }
}

/// Redesenhos e chamadas repetidas de onAppear não repetem a fala. Uma nova mensagem
/// durante a aparição é anunciada; desaparecer (inclusive retirar o erro) permite anunciá-la de novo.
struct ControleDoAnuncio {
    private var visivel = false
    private var ultimo: AnuncioDeAcessibilidade?

    mutating func aparecer(_ anuncio: AnuncioDeAcessibilidade?) -> AnuncioDeAcessibilidade? {
        visivel = true
        return atualizar(anuncio)
    }

    mutating func atualizar(_ anuncio: AnuncioDeAcessibilidade?) -> AnuncioDeAcessibilidade? {
        guard visivel else { return nil }
        guard let anuncio, !anuncio.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ultimo = nil
            return nil
        }
        guard anuncio != ultimo else { return nil }
        ultimo = anuncio
        return anuncio
    }

    mutating func desaparecer() {
        visivel = false
        ultimo = nil
    }
}

struct AnunciarAoAparecer: ViewModifier {
    let anuncio: AnuncioDeAcessibilidade?
    @State private var controle = ControleDoAnuncio()

    func body(content: Content) -> some View {
        content
            .onAppear { publicar(controle.aparecer(anuncio)) }
            .onChange(of: anuncio) { _, novo in publicar(controle.atualizar(novo)) }
            .onDisappear { controle.desaparecer() }
    }

    private func publicar(_ anuncio: AnuncioDeAcessibilidade?) {
        guard let anuncio else { return }
        AccessibilityNotification.Announcement(anuncio.mensagem).post()
    }
}

private struct ErroDeCampoFrilaKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var erroDeCampoFrila: String? {
        get { self[ErroDeCampoFrilaKey.self] }
        set { self[ErroDeCampoFrilaKey.self] = newValue }
    }
}

public extension View {
    /// Associa ao controle o erro que o formulário já exibe, sem acrescentar conteúdo visual.
    /// Os campos Frila também recebem a dica quando estão dentro de um grupo de controles.
    func erroDeCampoFrila(_ erro: String?) -> some View {
        environment(\.erroDeCampoFrila, erro)
            .accessibilityHint(Text(verbatim: erro ?? ""))
            .modifier(AnunciarAoAparecer(anuncio: erro.map { .init(texto: $0, tom: .erro) }))
    }
}
