import Foundation
import Testing

/// Testes de conformidade estática de release e entitlements (Cartões aAQflYu8 e AkupeSBi).
///
/// Valida que builds destinados ao TestFlight e à App Store configuram estritamente
/// `aps-environment = production`, que o manifesto de privacidade não declara rastreamento,
/// e que os scripts de release barram testes empacotados (*.xctest) e entitlements inválidos.
@Suite("Conformidade de Entitlements e Release (#aAQflYu8, #AkupeSBi)")
struct ConformidadeReleaseTests {
    private static let raiz: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Unitarios
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iOS
    }()

    @Test("Frila.entitlements amarra aps-environment à variável de build FRILA_APS_ENVIRONMENT")
    func declaracaoEntitlementsApp() throws {
        let caminho = Self.raiz.appending(path: "Sources/App/Frila.entitlements")
        let dados = try Data(contentsOf: caminho)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let apsEnv = try #require(plist["aps-environment"] as? String)
        #expect(apsEnv == "$(FRILA_APS_ENVIRONMENT)", "aps-environment deve referenciar $(FRILA_APS_ENVIRONMENT)")

        let grupos = plist["com.apple.security.application-groups"] as? [String]
        #expect(grupos?.contains("group.com.frila.org.app") == true, "Deve conter o grupo de compartilhamento do Frila")
    }

    @Test("Configurações de Release (Beta/TestFlight e Prod) definem categoricamente aps-environment = production (aAQflYu8)")
    func apsEnvironmentEmReleaseETestFlight() throws {
        let configs = [
            ("Beta.xcconfig (TestFlight)", "Configurations/Beta.xcconfig"),
            ("Prod.xcconfig (Release/AppStore)", "Configurations/Prod.xcconfig")
        ]

        let regexAps = /FRILA_APS_ENVIRONMENT\s*=\s*(\w+)/

        for (nome, caminhoRelativo) in configs {
            let conteudo = try String(contentsOf: Self.raiz.appending(path: caminhoRelativo), encoding: .utf8)
            let match = try #require(conteudo.firstMatch(of: regexAps), "Config \(nome) deve declarar FRILA_APS_ENVIRONMENT")
            let valor = String(match.output.1)

            #expect(valor == "production", "\(nome) deve ter FRILA_APS_ENVIRONMENT = production para receber push no TestFlight/Produção")
            #expect(valor != "development", "\(nome) não pode ter aps-environment development")
        }
    }

    @Test("project.yml associa Release-Beta e Release-Prod aos arquivos xcconfig corretos")
    func mapeamentoConfigsNoProjectYml() throws {
        let conteudo = try String(contentsOf: Self.raiz.appending(path: "project.yml"), encoding: .utf8)

        #expect(conteudo.contains("Release-Beta: Configurations/Beta.xcconfig"), "Release-Beta deve usar Beta.xcconfig")
        #expect(conteudo.contains("Release-Prod: Configurations/Prod.xcconfig"), "Release-Prod deve usar Prod.xcconfig")
    }

    @Test("PrivacyInfo.xcprivacy declara ausência de rastreamento (NSPrivacyTracking = false e domínios vazios)")
    func manifestoDePrivacidadeSemRastreamento() throws {
        let caminho = Self.raiz.appending(path: "Resources/PrivacyInfo.xcprivacy")
        let dados = try Data(contentsOf: caminho)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let tracking = plist["NSPrivacyTracking"] as? Bool
        #expect(tracking == false, "NSPrivacyTracking deve ser categoricamente false")

        let trackingDomains = plist["NSPrivacyTrackingDomains"] as? [String]
        #expect(trackingDomains?.isEmpty == true, "NSPrivacyTrackingDomains deve ser vazio")
    }

    @Test("Script conferir-release.sh valida ausência de XCTest em PlugIns e exige aps-environment production")
    func scriptConferirReleaseValidaXCTestEEntitlements() throws {
        let caminhoScript = Self.raiz.appending(path: "Scripts/conferir-release.sh")
        let conteudo = try String(contentsOf: caminhoScript, encoding: .utf8)

        #expect(conteudo.contains("PlugIns"), "Script deve inspecionar pasta PlugIns")
        #expect(conteudo.contains("*.xctest"), "Script deve procurar por *.xctest")
        #expect(conteudo.contains("bundle contém teste XCTest"), "Script deve reprovar testes XCTest empacotados")
        #expect(conteudo.contains("aps-environment deve ser production no Release"), "Script deve barrar aps-environment diferente de production")

        let atributos = try FileManager.default.attributesOfItem(atPath: caminhoScript.path(percentEncoded: false))
        let permissoes = (atributos[.posixPermissions] as? NSNumber)?.intValue ?? 0
        #expect((permissoes & 0o111) != 0, "conferir-release.sh deve ser executável")
    }

    @Test("App e project.yml declaram isenção de criptografia ITSAppUsesNonExemptEncryption = false (#AkupeSBi, #Jg8qMYKj)")
    func declaracaoIsencaoDeCriptografia() throws {
        let caminhoPlist = Self.raiz.appending(path: "Sources/App/Info.plist")
        let dados = try Data(contentsOf: caminhoPlist)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let isencao = try #require(plist["ITSAppUsesNonExemptEncryption"] as? Bool)
        #expect(isencao == false, "ITSAppUsesNonExemptEncryption deve ser o booleano false no Info.plist para evitar avisos na App Store")

        let projectYml = try String(contentsOf: Self.raiz.appending(path: "project.yml"), encoding: .utf8)
        #expect(projectYml.contains("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO"), "project.yml deve configurar INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO")
    }

    @Test("Target configurado exclusivamente para iPhone TARGETED_DEVICE_FAMILY = 1 (#Jg8qMYKj)")
    func targetApenasIPhone() throws {
        let projectYml = try String(contentsOf: Self.raiz.appending(path: "project.yml"), encoding: .utf8)
        #expect(projectYml.contains("TARGETED_DEVICE_FAMILY: \"1\""), "project.yml deve fixar TARGETED_DEVICE_FAMILY em 1 (iPhone)")
        #expect(!projectYml.contains("TARGETED_DEVICE_FAMILY: \"1,2\""), "Não pode incluir iPad (família 2)")
        #expect(!projectYml.contains("TARGETED_DEVICE_FAMILY: \"2\""), "Não pode ser target exclusivo de iPad")
    }
}
