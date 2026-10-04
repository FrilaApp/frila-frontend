import Foundation
@testable import FrilaApresentacao
import Testing

/// Critério 1 do #178: a tela de licenças cobre todas as dependências do build. O `Licencas.json`
/// é gerado por `Scripts/gerar-licencas.py`; pacote novo ou atualizado sem gerar de novo falha aqui.
@Suite("Licenças das dependências")
struct LicencasTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let comoCorrigir = "Resolva os pacotes e rode Scripts/gerar-licencas.py."

    private struct PacotesResolvidos: Decodable {
        struct Pino: Decodable {
            struct Estado: Decodable { let revision: String }
            let identity: String
            let state: Estado
        }
        let pins: [Pino]
    }

    private static func pinos() throws -> [PacotesResolvidos.Pino] {
        let urlProjeto = raiz.appending(path: "Frila.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        let urlRaiz = raiz.appending(path: "Package.resolved")
        let url = FileManager.default.fileExists(atPath: urlRaiz.path()) ? urlRaiz : urlProjeto
        return try JSONDecoder().decode(PacotesResolvidos.self, from: Data(contentsOf: url)).pins
    }

    @Test("Todo pacote do Package.resolved tem licença em Licencas.json, na mesma revisão")
    func todoPacoteTemLicenca() throws {
        let pinos = try Self.pinos()
        let licencas = try Licencas.carregar()
        #expect(pinos.count >= 2, "o Package.resolved deveria trazer ao menos o Firebase e o Supabase")

        let revisaoPorID = Dictionary(licencas.map { ($0.id, $0.revisao) }, uniquingKeysWith: { primeira, _ in primeira })
        #expect(revisaoPorID.count == licencas.count, "Licencas.json tem pacote repetido")

        let semLicenca = pinos.map(\.identity).filter { revisaoPorID[$0] == nil }
        #expect(semLicenca.isEmpty, "pacotes do Package.resolved sem entrada em Licencas.json: \(semLicenca). \(Self.comoCorrigir)")

        let emOutraRevisao = pinos.filter { pino in
            revisaoPorID[pino.identity].map { $0 != pino.state.revision } ?? false
        }.map(\.identity)
        #expect(emOutraRevisao.isEmpty, "licenças geradas de outra revisão do pacote: \(emOutraRevisao). \(Self.comoCorrigir)")

        let foraDoBuild = Set(revisaoPorID.keys).subtracting(pinos.map(\.identity)).sorted()
        #expect(foraDoBuild.isEmpty, "Licencas.json lista pacotes que saíram do Package.resolved: \(foraDoBuild). \(Self.comoCorrigir)")
    }

    @Test("Toda licença traz nome, versão, tipo, URL e texto")
    func entradasCompletas() throws {
        var incompletas: [String] = []
        for licenca in try Licencas.carregar() {
            let completa = !licenca.nome.isEmpty && !licenca.versao.isEmpty && !licenca.tipo.isEmpty
                && licenca.url.scheme == "https" && licenca.url.host() != nil
                // A menor licença do build (Zlib, do nanopb) passa de 800 caracteres.
                && licenca.texto.count > 500
                && licenca.aviso?.isEmpty != true
            if !completa { incompletas.append(licenca.id) }
        }
        #expect(incompletas.isEmpty, "entradas incompletas em Licencas.json: \(incompletas). \(Self.comoCorrigir)")
    }

    @Test("Textos da tela de licenças estão no catálogo pt-BR")
    func textosEstaoNoCatalogo() throws {
        let dados = try Data(contentsOf: Self.raiz.appending(path: "Resources/Localizable.xcstrings"))
        let json = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let chaves = Set(try #require(json["strings"] as? [String: Any]).keys)

        let textos = [
            TextosDeLicencas.titulo,
            TextosDeLicencas.versao,
            TextosDeLicencas.licenca,
            TextosDeLicencas.repositorio,
            TextosDeLicencas.aviso,
            TextosDeLicencas.falha,
            TextosDeLicencas.dicaAbrir,
        ]
        let faltantes = textos.filter { !chaves.contains($0) }
        #expect(faltantes.isEmpty, "textos da tela de licenças fora do catálogo: \(faltantes)")
    }
}
