import Foundation

/// Sinônimos canônicos e resolução de funções (CD-T04, CD-T05, RN44).
public enum ResolucaoDeFuncoes {
    /// Mapeamento de sinônimos conhecidos normalizados para o nome canônico da função (CD-T04 / CD-T05).
    public static let sinonimosPadrao: [String: String] = [
        "diarista": "faxina residencial",
        "faxineira": "faxina residencial",
        "limpeza residencial": "faxina residencial",
        "faxina": "faxina residencial",
        "passadeira": "passadeira",
        "passar roupa": "passadeira",
        "faxina comercial": "faxina comercial (escritorio)",
        "limpeza comercial": "faxina comercial (escritorio)",
        "faxina escritorio": "faxina comercial (escritorio)",
        "churrasqueiro": "churrasqueiro",
        "churrasqueira": "churrasqueiro",
        "churrasco": "churrasqueiro",
        "cozinheiro de festa": "cozinheiro de festa",
        "cozinheira de festa": "cozinheiro de festa",
        "cozinheiro de eventos": "cozinheiro de festa",
        "auxiliar de festa": "auxiliar de festa",
        "ajudante de festa": "auxiliar de festa",
        "garconete": "garcom",
        "garcom": "garcom"
    ]

    /// Sem acento, sem diferença de caixa e sem espaços nas pontas, para comparar e buscar.
    public static func normalizar(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Resolve até 5 funções candidatas pelo termo digitado (por sinônimo e por nome), sem duplicar (RN44 / CD-T04).
    public static func resolver(termo: String, em funcoes: [Funcao], sinonimos: [String: String] = sinonimosPadrao) -> [Funcao] {
        let consulta = normalizar(termo)
        guard consulta.count >= 2 else { return [] }

        var encontradas: [Funcao] = []
        var idsAdicionados: Set<UUID> = []

        // 1. Busca por sinônimo exato ou substring do sinônimo
        if let canonico = sinonimos[consulta] ?? sinonimos.first(where: { $0.key.contains(consulta) || consulta.contains($0.key) })?.value {
            let canonicoNorm = normalizar(canonico)
            for f in funcoes where normalizar(f.nome) == canonicoNorm || normalizar(f.nome).contains(canonicoNorm) {
                if !idsAdicionados.contains(f.id) {
                    encontradas.append(f)
                    idsAdicionados.insert(f.id)
                }
            }
        }

        // 2. Busca por nome da função ou grupo de busca
        for f in funcoes {
            let nomeNorm = normalizar(f.nome)
            let grupoNorm = f.grupoBusca.map(normalizar)
            if nomeNorm.contains(consulta) || grupoNorm?.contains(consulta) == true {
                if !idsAdicionados.contains(f.id) {
                    encontradas.append(f)
                    idsAdicionados.insert(f.id)
                }
            }
        }

        return Array(encontradas.prefix(5))
    }
}
