import Foundation

/// Separa a composição visual sem decidir quando exibir centavos.
struct FrilaPartesValor {
    let moeda: String
    let inteiro: String
    let centavos: String
    let prefixo: String
    let sufixo: String

    init(_ texto: String) {
        guard let simbolo = texto.range(of: "R$") else {
            moeda = ""
            inteiro = texto
            centavos = ""
            prefixo = ""
            sufixo = ""
            return
        }
        moeda = "R$"
        prefixo = String(texto[..<simbolo.lowerBound])
        let restante = texto[simbolo.upperBound...].drop(while: { $0.isWhitespace })
        let numero = restante.prefix(while: { $0.isNumber || ".,-−".contains($0) })
        let partes = numero.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        inteiro = partes.first.map(String.init) ?? ""
        centavos = partes.count == 2 ? "," + partes[1] : ""
        sufixo = String(restante.dropFirst(numero.count))
    }
}
