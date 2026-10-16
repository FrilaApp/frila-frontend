import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Segurança e sanitização de url_da_loja (App Store)")
struct UrlDaLojaTests {

    private nonisolated static let linksValidosAppStore = [
        "https://apps.apple.com/app/id6815311991",
        "HTTPS://APPS.APPLE.COM/app/id6815311991",
        "https://itunes.apple.com/app/id6815311991",
        "https://apps.apple.com/br/app/frila/id6815311991?action=write-review",
    ]

    private nonisolated static let linksInvalidosOuMaliciosos = [
        "javascript:alert(1)",
        "http://apps.apple.com/app/id6815311991",
        "https://apps.apple.com.evil.com/app/id6815311991",
        "https://evil.com/app/id6815311991",
        "frila://atualizar",
        "data:text/html,<script>alert(1)</script>",
    ]

    private static func configuracaoJSON(url: String) -> String {
        """
        {
            "plataforma": "ios",
            "versao_minima": "1.0.0",
            "versao_recomendada": "1.2.0",
            "url_da_loja": "\(url)",
            "mensagem": "Atualize o app."
        }
        """
    }

    @Test("URL da App Store em HTTPS oficial passa intacta", arguments: linksValidosAppStore)
    func urlValidaPassaIntacta(url: String) throws {
        let json = Self.configuracaoJSON(url: url)
        let dto = try JSONDecoder().decode(ContratoAPI.ConfiguracaoDoAppDTO.self, from: Data(json.utf8))
        let dominio = dto.dominio()

        #expect(dominio.urlDaLoja.absoluteString == url)
        #expect(dominio.versaoMinima == "1.0.0")
        #expect(dominio.versaoRecomendada == "1.2.0")
        #expect(dominio.mensagem == "Atualize o app.")
    }

    @Test("URL maliciosa, insegura (HTTP) ou de outro domínio é substituída pelo link padrão seguro da App Store", arguments: linksInvalidosOuMaliciosos)
    func urlMaliciosaOuInseguraRecorreAoPadrao(url: String) throws {
        let json = Self.configuracaoJSON(url: url)
        let dto = try JSONDecoder().decode(ContratoAPI.ConfiguracaoDoAppDTO.self, from: Data(json.utf8))
        let dominio = dto.dominio()

        #expect(dominio.urlDaLoja.absoluteString == "https://apps.apple.com/")
        #expect(dominio.urlDaLoja.scheme == "https")
        #expect(dominio.urlDaLoja.host == "apps.apple.com")
        #expect(dominio.versaoMinima == "1.0.0")
    }

    @Test("Método urlSeguraDaLoja diretamente confere conformidade de esquema e host")
    func validacaoDiretaDeURL() throws {
        let valida = try #require(URL(string: "https://apps.apple.com/app/id6815311991"))
        #expect(ContratoAPI.ConfiguracaoDoAppDTO.urlSeguraDaLoja(valida) == valida)

        let http = try #require(URL(string: "http://apps.apple.com/app/id6815311991"))
        #expect(ContratoAPI.ConfiguracaoDoAppDTO.urlSeguraDaLoja(http) == ContratoAPI.ConfiguracaoDoAppDTO.urlPadraoDaLoja)

        let outroHost = try #require(URL(string: "https://phishing.com/loja"))
        #expect(ContratoAPI.ConfiguracaoDoAppDTO.urlSeguraDaLoja(outroHost) == ContratoAPI.ConfiguracaoDoAppDTO.urlPadraoDaLoja)
    }
}
