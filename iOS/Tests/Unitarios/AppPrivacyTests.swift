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

    @Test("Manifesto de privacidade declara os tipos de dados funcionais e de diagnóstico obrigatórios")
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

        for esperado in esperados {
            #expect(nomesDosTipos.contains(esperado), "Tipo de dado ausente no manifesto: \(esperado)")
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
                #expect(purposes.contains("NSPrivacyCollectedDataTypePurposeAnalytics"), "\(tipo ?? "") deve ter finalidade Analytics")
            } else {
                #expect(purposes.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality"), "\(tipo ?? "") deve ter finalidade AppFunctionality")
            }
        }
    }

    @Test("Endereços oficiais utilizam protocolo HTTPS e e-mail institucional válido")
    func enderecosOficiaisValidos() {
        let enderecos = EnderecosOficiais.padrao

        #expect(enderecos.termosDeUso.scheme == "https")
        #expect(enderecos.termosDeUso.host == "frila.app")
        #expect(enderecos.termosDeUso.path == "/termos")

        #expect(enderecos.politicaDePrivacidade.scheme == "https")
        #expect(enderecos.politicaDePrivacidade.host == "frila.app")
        #expect(enderecos.politicaDePrivacidade.path == "/privacidade")

        #expect(enderecos.emailSuporte.contains("@"))
        #expect(enderecos.emailSuporte.contains("."))
        #expect(enderecos.urlSuporte?.scheme == "mailto")
    }
}
