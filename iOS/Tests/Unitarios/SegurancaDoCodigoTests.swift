import Foundation
import Testing

/// Busca estática no código do app (critério 4 do #53): os logs de execução são auditados por
/// `Scripts/auditar-logs-sensiveis.sh`; aqui a busca é no próprio código, a cada `xcodebuild test`.
@Suite("Dados sensíveis no código")
struct SegurancaDoCodigoTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func arquivosSwift() throws -> [(nome: String, linhas: [Substring])] {
        let fontes = raiz.appending(path: "Sources")
        let enumerador = try #require(FileManager.default.enumerator(at: fontes, includingPropertiesForKeys: nil))
        return try enumerador.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { url in
                let nome = url.path.replacingOccurrences(of: raiz.path + "/", with: "")
                return (nome, try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false))
            }
    }

    @Test("A busca enxerga o código do app")
    func enxergaOCodigo() throws {
        #expect(try Self.arquivosSwift().count > 20)
    }

    @Test("Nenhum print, NSLog, debugPrint ou dump no app")
    func semSaidaSolta() throws {
        let saidaSolta = /(^|[^A-Za-z0-9_.])(print|NSLog|debugPrint|dump)\(/
        var achados: [String] = []
        for arquivo in try Self.arquivosSwift() {
            for (indice, linha) in arquivo.linhas.enumerated() where linha.contains(saidaSolta) {
                achados.append("\(arquivo.nome):\(indice + 1)")
            }
        }
        #expect(achados.isEmpty, "saída fora do Logger em \(achados)")
    }

    @Test("Nenhum log interpola e-mail, token, sessão, senha, telefone ou chave")
    func logsSemDadoSensivel() throws {
        let interpolacao = /\\\(([^)]*)\)/
        let sensivel = /(?i)(e-?mail|token|sess(ao|ion)|senha|password|telefone|phone|chave|apikey|jwt|bearer)/
        var achados: [String] = []
        for arquivo in try Self.arquivosSwift() {
            for (indice, linha) in arquivo.linhas.enumerated() where linha.contains(/logger\.|Logger\(|os_log/) {
                for trecho in linha.matches(of: interpolacao) where trecho.output.1.contains(sensivel) {
                    achados.append("\(arquivo.nome):\(indice + 1)")
                }
            }
        }
        #expect(achados.isEmpty, "log com dado sensível em \(achados)")
    }
}
