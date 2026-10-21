import Foundation
import FrilaApresentacao
import Testing

/// Testes automatizados para validação do manifesto de privacidade e links legais (Cartão iWfyZwdu / Diretrizes 5.1.1 e 5.1.2).
@Suite("Conformidade de App Privacy e Links Legais (#iWfyZwdu)")
struct AppPrivacyTests {

    private static let raiz: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Unitarios
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // iOS
    }()

    @Test("Manifesto de privacidade principal declara ausência de rastreamento (NSPrivacyTracking = false)")
    func manifestoSemRastreamento() throws {
        let caminhoManifesto = Self.raiz.appending(path: "Resources/PrivacyInfo.xcprivacy")
        let dados = try Data(contentsOf: caminhoManifesto)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let tracking = plist["NSPrivacyTracking"] as? Bool
        #expect(tracking == false, "NSPrivacyTracking deve ser categoricamente false")

        let trackingDomains = plist["NSPrivacyTrackingDomains"] as? [String]
        #expect(trackingDomains?.isEmpty == true, "NSPrivacyTrackingDomains deve ser vazio")
    }

    @Test("Manifesto de privacidade declara os 12 tipos de dados obrigatórios e sem duplicatas")
    func tiposDeDadosDeclaradosNoManifesto() throws {
        let caminhoManifesto = Self.raiz.appending(path: "Resources/PrivacyInfo.xcprivacy")
        let dados = try Data(contentsOf: caminhoManifesto)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let tiposColetados = try #require(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let nomesDosTipos = tiposColetados.compactMap { $0["NSPrivacyCollectedDataType"] as? String }

        let esperados = [
            "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeEmailAddress",
            "NSPrivacyCollectedDataTypePhoneNumber",
            "NSPrivacyCollectedDataTypePhysicalAddress",
            "NSPrivacyCollectedDataTypePreciseLocation",
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeDeviceID",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeOtherDataTypes",
            "NSPrivacyCollectedDataTypeCrashData",
            "NSPrivacyCollectedDataTypeOtherDiagnosticData",
            "NSPrivacyCollectedDataTypeProductInteraction",
        ]

        // Asserção contra duplicatas no manifesto (cada tipo deve aparecer exatamente 1 vez)
        #expect(tiposColetados.count == esperados.count, "O manifesto deve conter exatamente \(esperados.count) tipos de dados declarados")
        let contagemPorTipo = Dictionary(grouping: nomesDosTipos, by: { $0 }).mapValues { $0.count }
        for esperado in esperados {
            let ocorrencias = contagemPorTipo[esperado] ?? 0
            #expect(ocorrencias == 1, "Tipo de dado '\(esperado)' deve aparecer exatamente 1 vez no manifesto, mas apareceu \(ocorrencias) vezes")
        }

        for item in tiposColetados {
            let tracking = item["NSPrivacyCollectedDataTypeTracking"] as? Bool
            #expect(tracking == false, "Nenhum tipo de dado coletado pode estar marcado como tracking")

            let tipo = item["NSPrivacyCollectedDataType"] as? String
            let linked = item["NSPrivacyCollectedDataTypeLinked"] as? Bool
            let purposes = item["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? []

            if tipo == "NSPrivacyCollectedDataTypeProductInteraction" {
                #expect(linked == true, "ProductInteraction deve ser vinculado ao usuário (usuario_id)")
                #expect(purposes.contains("NSPrivacyCollectedDataTypePurposeAnalytics"), "ProductInteraction deve ter finalidade Analytics")
            } else if tipo == "NSPrivacyCollectedDataTypeCrashData" || tipo == "NSPrivacyCollectedDataTypeOtherDiagnosticData" {
                #expect(linked == false, "\(tipo ?? "") não deve ser vinculado ao usuário")
                #expect(purposes.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality"), "\(tipo ?? "") deve ter finalidade AppFunctionality na main atual")
            } else {
                #expect(linked == true, "\(tipo ?? "") deve ser vinculado ao usuário (finalidade funcional)")
                #expect(purposes.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality"), "\(tipo ?? "") deve ter finalidade AppFunctionality")
            }
        }
    }

    @Test("Manifesto de privacidade declara uso de APIs de motivos permitidos (UserDefaults)")
    func apisDeMotivosPermitidos() throws {
        let caminhoManifesto = Self.raiz.appending(path: "Resources/PrivacyInfo.xcprivacy")
        let dados = try Data(contentsOf: caminhoManifesto)
        let plist = try #require(try PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])

        let apis = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(!apis.isEmpty, "NSPrivacyAccessedAPITypes não pode ser vazio")

        let userDefaultsApi = try #require(apis.first(where: {
            ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
        }))

        let reasons = try #require(userDefaultsApi["NSPrivacyAccessedAPITypeReasons"] as? [String])
        #expect(reasons.contains("CA92.1"), "Deve declarar a razão CA92.1 para UserDefaults")
        #expect(reasons.contains("1C8F.1"), "Deve declarar a razão 1C8F.1 para UserDefaults")
    }

    @Test("Endereços oficiais utilizam protocolo HTTPS e e-mail institucional válido")
    func enderecosOficiaisValidos() {
        let enderecos = EnderecosOficiais.padrao

        #expect(enderecos.termosDeUso.scheme == "https")
        #expect(enderecos.termosDeUso.host == "frila.netlify.app")
        #expect(enderecos.termosDeUso.path == "/termos")

        #expect(enderecos.politicaDePrivacidade.scheme == "https")
        #expect(enderecos.politicaDePrivacidade.host == "frila.netlify.app")
        #expect(enderecos.politicaDePrivacidade.path == "/privacidade")

        #expect(enderecos.emailSuporte == "suporte@frilabr.com")
        #expect(enderecos.urlSuporte?.absoluteString == "mailto:suporte@frilabr.com")
        #expect(enderecos.urlSuporte?.scheme == "mailto")
    }
}
