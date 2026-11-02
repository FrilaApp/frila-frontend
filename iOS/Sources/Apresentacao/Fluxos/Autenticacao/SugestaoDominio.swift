import Foundation

struct SugestaoDominio {
    static let dominios = ["gmail.com", "hotmail.com", "yahoo.com.br", "yahoo.com", "outlook.com", "icloud.com", "uol.com.br"]
    let texto: String
    let cursor: Int
    let dominio: String

    static func criar(_ texto: String, cursor: Int) -> Self? {
        guard cursor == texto.utf16.count, texto.filter({ $0 == "@" }).count == 1,
              let arroba = texto.firstIndex(of: "@"), arroba != texto.startIndex else { return nil }
        let prefixo = String(texto[texto.index(after: arroba)...]).lowercased()
        guard !prefixo.contains(where: { $0.isWhitespace }),
              let dominio = dominios.first(where: { $0.hasPrefix(prefixo) }), dominio != prefixo else { return nil }
        return Self(texto: texto, cursor: cursor, dominio: dominio)
    }

    func vizinho(_ deslocamento: Int) -> String {
        let indice = Self.dominios.firstIndex(of: dominio) ?? 0
        return Self.dominios[(indice + deslocamento % Self.dominios.count + Self.dominios.count) % Self.dominios.count]
    }

    func confirmar(_ escolhido: String, textoAtual: String, cursorAtual: Int) -> String? {
        guard textoAtual == texto, cursorAtual == cursor, Self.dominios.contains(escolhido),
              let arroba = texto.firstIndex(of: "@") else { return nil }
        let prefixo = String(texto[texto.index(after: arroba)...])
        guard escolhido.lowercased().hasPrefix(prefixo.lowercased()) else { return nil }
        return String(texto[...arroba]) + prefixo + escolhido.dropFirst(prefixo.count)
    }
}
