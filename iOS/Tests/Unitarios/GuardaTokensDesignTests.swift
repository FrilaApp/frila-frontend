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

    /// Lista de exceções explícitas (arquivo + motivo) para arquivos ocupados por PRs abertos.
    /// O Nick Fury remove cada entrada após o merge do PR correspondente (#139).
    static let excecoesOcupadas: [String: String] = [
        "Componentes.swift": "Ocupado pelo PR #110 (auditoria de acessibilidade)",
        "TelaExclusaoDeConta.swift": "Ocupado pelo PR #110 (auditoria de acessibilidade)",
        "CortinaDePrivacidade.swift": "Ocupado pelo PR #112 (auditoria de segurança)",
        "ExportarDadosViewModel.swift": "Ocupado pelo PR #112 (auditoria de segurança)",
        "TelaHistoricoDeTurnos.swift": "Ocupado pelo PR #106 (histórico e exportação)",
        "PerfisDaConta.swift": "Ocupado pelo PR #106 (histórico e exportação)",
        "HistoricoDeTurnosViewModel.swift": "Ocupado pelo PR #106 (histórico e exportação)",
        "TextosHistoricoDeTurnos.swift": "Ocupado pelo PR #106 (histórico e exportação)",
        "TelaMeuTurno.swift": "Ocupado pelo PR #103 e branch #39",
        "PublicarVaga.swift": "Ocupado pelos PRs #73 e #103",
        "RepublicarVaga.swift": "Ocupado pelo PR #103",
        "MeuTurnoViewModel.swift": "Ocupado pelo PR #103 e branch #39",
        "PresencaDoTurnoViewModel.swift": "Ocupado pelo PR #103",
        "TextosDaPresenca.swift": "Ocupado pelo PR #103",
        "MinhasVagas.swift": "Ocupado pelo PR #73 e branch #39",
        "PublicarVagaDaCasa.swift": "Ocupado pelo PR #73",
        "FluxoDoContratante.swift": "Ocupado pelo PR #73",
        "FluxoDoProfissional.swift": "Ocupado pelo PR #114 e branch #39",
        "TelasDaCandidatura.swift": "Ocupado pelo PR #114",
        "TextosDoProfissional.swift": "Ocupado pelo PR #114",
        "TelaTurnoDoContratante.swift": "Ocupado pela branch #39",
        "FolhaDeCancelamento.swift": "Ocupado pela branch #39",
        "CancelamentoViewModel.swift": "Ocupado pela branch #39",
        "TextosDoCancelamento.swift": "Ocupado pela branch #39",
        "AcoesDeSeguranca.swift": "Ocupado pela branch #39",
        "SegurancaViewModel.swift": "Ocupado pela branch #39",
        "AcompanhamentoViewModel.swift": "Ocupado pela branch #39"
    ]

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
