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

/// Cronograma visual compartilhado pela seta e pela roda; não altera o valor do campo.
struct CadeiaDoDominio {
    struct Bloco {
        let texto: String
        let inicio: Double
        let duracao: Double
        func progresso(em tempo: Double) -> Double {
            CadeiaDoDominio.curva((tempo - inicio) / duracao, x1: 0.22, x2: 0.36)
        }
    }
    let blocos: [Bloco]
    let duracao: Double

    init(restante: String) {
        let partes = restante.split(separator: ".", omittingEmptySubsequences: false)
            .enumerated().compactMap { indice, parte -> String? in
                let texto = (indice == 0 ? "" : ".") + parte
                return texto.isEmpty ? nil : texto
            }
        let quantidade = partes.count
        guard quantidade > 0 else { blocos = []; duracao = 0; return }
        duracao = quantidade == 1 ? 0.20 : 0.40 + 0.08 * Double(quantidade - 2)
        let primeiraDuracao = quantidade > 2 ? 0.16 : 0.18
        let janela = duracao - (quantidade == 1 ? 0.20 : 0.22)
        let ultimo = Self.curva(Double(quantidade - 1) / Double(quantidade), x1: 0.42, x2: 0.58, y1: 0)
        blocos = partes.enumerated().map { indice, parte in
            let fracao = quantidade == 1 ? 0 : Double(indice) / Double(quantidade - 1)
            let inicio = quantidade == 1 ? 0 : janela * Self.curva(Double(indice) / Double(quantidade),
                x1: 0.42, x2: 0.58, y1: 0) / ultimo
            return Bloco(texto: parte, inicio: inicio,
                         duracao: quantidade == 1 ? 0.20 : primeiraDuracao + (0.22 - primeiraDuracao) * fracao)
        }
    }

    /// Resolve x da Bézier e retorna y; serve ao ritmo de conjunto e à entrada de cada bloco.
    private static func curva(_ progresso: Double, x1: Double, x2: Double, y1: Double = 1) -> Double {
        guard progresso > 0 else { return 0 }
        guard progresso < 1 else { return 1 }
        var inferior = 0.0
        var superior = 1.0
        for _ in 0..<24 {
            let t = (inferior + superior) / 2
            let x = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            if x < progresso { inferior = t } else { superior = t }
        }
        let t = (inferior + superior) / 2
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t + t * t * t
    }
}
