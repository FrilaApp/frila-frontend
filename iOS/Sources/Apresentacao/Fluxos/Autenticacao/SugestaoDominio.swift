import Foundation

/// Predição de domínio para o campo de e-mail do Login.
/// Lista provisória, ordenada por uso presumido no Brasil; o primeiro é o padrão do centro da roda.
/// Não mede frequência real dos usuários do Frila.
struct SugestaoDominio: Equatable {
    static let dominios = [
        "gmail.com", "hotmail.com", "outlook.com", "yahoo.com.br",
        "icloud.com", "yahoo.com", "uol.com.br"
    ]

    /// O que já foi digitado depois do "@", em minúsculas.
    let prefixo: String
    /// Domínios que continuam o prefixo, na ordem da lista.
    let candidatos: [String]

    /// Só há sugestão com o cursor no fim, um único "@" que não abre o texto e sem espaços depois dele.
    static func criar(texto: String, cursorNoFim: Bool) -> Self? {
        guard cursorNoFim,
              texto.filter({ $0 == "@" }).count == 1,
              let arroba = texto.firstIndex(of: "@"), arroba != texto.startIndex else { return nil }
        let prefixo = String(texto[texto.index(after: arroba)...]).lowercased()
        guard !prefixo.contains(where: { $0.isWhitespace }) else { return nil }
        let candidatos = compativeis(com: prefixo, na: dominios)
        guard candidatos.contains(where: { $0 != prefixo }) else { return nil }
        return Self(prefixo: prefixo, candidatos: candidatos)
    }

    struct PrefixoMinimo: Equatable {
        let prefixo: String
        let exigeTermino: Bool
    }

    static func compativeis(com prefixo: String, na lista: [String]) -> [String] {
        lista.filter { $0.lowercased().hasPrefix(prefixo.lowercased()) }
    }

    static func prefixosMinimos(da lista: [String]) -> [String: PrefixoMinimo] {
        Dictionary(uniqueKeysWithValues: lista.map { dominio in
            let outros = lista.filter { $0 != dominio }
            for tamanho in 1...dominio.count {
                let prefixo = String(dominio.prefix(tamanho))
                if !outros.contains(where: { $0.hasPrefix(prefixo) }) {
                    return (dominio, PrefixoMinimo(prefixo: prefixo, exigeTermino: false))
                }
            }
            return (dominio, PrefixoMinimo(prefixo: dominio, exigeTermino: true))
        })
    }

    static let identificadoresMinimos = prefixosMinimos(da: dominios)
    var prefixoUnico: Bool {
        guard let primeiro = candidatos.first,
              let minimo = Self.identificadoresMinimos[primeiro] else { return false }
        return candidatos.count == 1 && prefixo.hasPrefix(minimo.prefixo) && (!minimo.exigeTermino || prefixo == primeiro)
    }

    /// Parte do domínio que falta digitar.
    func restante(de dominio: String) -> String {
        String(dominio.dropFirst(prefixo.count))
    }

    func candidato(em posicao: Int) -> String {
        let n = candidatos.count
        return candidatos[((posicao % n) + n) % n]
    }
}

/// Limiares líquidos: oscilações não se somam e velocidade isolada não ativa a roda.
enum LimiarDaRoda {
    static func intencional(deslocamento: Double, velocidade: Double) -> Bool {
        abs(deslocamento) >= 8 || (abs(deslocamento) >= 6 && abs(velocidade) >= 160 && deslocamento * velocidade > 0)
    }
    static func resistencia(_ deslocamento: Double) -> Double {
        let excesso = max(0, abs(deslocamento) - 2)
        return (deslocamento < 0 ? -1 : 1) * 2.5 * (1 - exp(-excesso / 6))
    }
}
