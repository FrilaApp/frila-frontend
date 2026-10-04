import Foundation
import Testing

/// Teste de guarda de design tokens (critério do cartão #139):
/// Garante que nenhuma tela ou componente defina cor ou fonte fora dos tokens
/// (`FrilaCor` e estilos dinâmicos de texto do sistema).
///
/// Falha se aparecer `Color(red:`, `Color(white:`, `Color(uiColor:`, `Color("`,
/// `UIColor(`, `.system(size:`, `Font.system(size:` ou `Font.custom` fora de `DesignTokens.swift`.
///
/// Arquivos ocupados por PRs abertos estão catalogados na lista de exceções explícitas,
/// que o Nick Fury esvazia conforme cada PR correspondente é mergeado.
@Suite("Guarda de tokens de design nas telas")
struct GuardaTokensDesignTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Exceções explícitas (arquivo: motivo), só para arquivo que tem a ocorrência e não pode ser
    /// corrigido agora. Vazia: em 04/10/2026 nenhum arquivo da Apresentação tinha ocorrência.
    static let excecoesOcupadas: [String: String] = [:]

    private static func arquivosApresentacao() throws -> [(nome: String, url: URL, linhas: [Substring])] {
        let apresentacao = raiz.appending(path: "Sources").appending(path: "Apresentacao")
        let enumerador = try #require(FileManager.default.enumerator(at: apresentacao, includingPropertiesForKeys: nil))
        return try enumerador.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "DesignTokens.swift" }
            .map { url in
                let nome = url.lastPathComponent
                let conteudo = try String(contentsOf: url, encoding: .utf8)
                return (nome, url, conteudo.split(separator: "\n", omittingEmptySubsequences: false))
            }
    }

    @Test("Encontra arquivos de código da camada Apresentação")
    func encontraArquivos() throws {
        let arquivos = try Self.arquivosApresentacao()
        #expect(arquivos.count >= 20)
    }

    @Test("Nenhuma cor ou fonte definida fora dos tokens em arquivos livres")
    func coresEFontesExclusivamentePorTokens() throws {
        let padroesProibidos: [(nome: String, regex: Regex<AnyRegexOutput>)] = [
            ("Color(red:", try Regex(#"Color\s*\(\s*red:"#)),
            ("Color(white:", try Regex(#"Color\s*\(\s*white:"#)),
            ("Color(uiColor:", try Regex(#"Color\s*\(\s*uiColor:"#)),
            ("Color(\"", try Regex(#"Color\s*\(\s*""#)),
            ("UIColor(", try Regex(#"UIColor\s*\("#)),
            (".system(size:", try Regex(#"\.system\s*\(\s*size:"#)),
            ("Font.system(size:", try Regex(#"Font\.system\s*\(\s*size:"#)),
            ("Font.custom(", try Regex(#"Font\.custom\s*\("#)),
            ("Cor literal do sistema", try Regex(#"\.(foregroundStyle|foregroundColor|background)\s*\(\s*\.(red|green|blue|orange|yellow|pink|purple|teal|indigo|mint|cyan)\b"#))
        ]

        var violacoesEmArquivosLivres: [String] = []

        let arquivos = try Self.arquivosApresentacao()
        for arquivo in arquivos {
            if Self.excecoesOcupadas[arquivo.nome] != nil {
                continue
            }
            for (indice, linha) in arquivo.linhas.enumerated() {
                let linhaLimpa = linha.trimmingCharacters(in: .whitespaces)
                if linhaLimpa.hasPrefix("//") || linhaLimpa.hasPrefix("/*") {
                    continue
                }
                for padrao in padroesProibidos {
                    if linha.contains(padrao.regex) {
                        violacoesEmArquivosLivres.append("\(arquivo.nome):\(indice + 1) [\(padrao.nome)]: \(linhaLimpa)")
                    }
                }
            }
        }

        #expect(violacoesEmArquivosLivres.isEmpty, "Cores ou fontes fora dos tokens em arquivos livres: \(violacoesEmArquivosLivres)")
    }
}
