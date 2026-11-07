import Foundation

/// Tira o código de entrada de um texto colado, que pode vir com sujeira ("Seu código: 123456").
///
/// A regra é a do campo do código: exatamente 6 números (`Character.isNumber`).
/// Espaço e traço entre números ("123 456", "123-456") fazem parte do mesmo código.
/// Se não houver exatamente um código possível, devolve `nil` e nada é preenchido.
enum ExtratorDeCodigo {
    static let tamanho: Int = 6

    static func extrair(de texto: String) -> String? {
        var grupos: [String] = []
        var atual: String = ""
        var pendente: String = ""

        for caractere in texto {
            if caractere.isNumber {
                atual += pendente
                pendente = ""
                atual.append(caractere)
            } else if ehSeparador(caractere), !atual.isEmpty {
                pendente.append(caractere)
            } else {
                if !atual.isEmpty { grupos.append(atual) }
                atual = ""
                pendente = ""
            }
        }
        if !atual.isEmpty { grupos.append(atual) }

        var candidatos: [String] = []
        for grupo in grupos {
            let digitos: String = grupo.filter { $0.isNumber }
            if digitos.count == tamanho, !candidatos.contains(digitos) {
                candidatos.append(digitos)
            }
        }
        return candidatos.count == 1 ? candidatos.first : nil
    }

    private static func ehSeparador(_ caractere: Character) -> Bool {
        caractere == "-" || caractere == " " || caractere == "\u{00A0}" || caractere == "\u{2011}"
            || caractere == "\u{2013}"
    }
}
