import Foundation
import FrilaDominio
@testable import FrilaInfraestrutura
import Testing

private actor TokensRecebidos {
    private(set) var tokens: [String] = []
    func anotar(_ token: String) { tokens.append(token) }
}

/// O esquema Local não tem `GoogleService-Info.plist`: o canal não fala com o FCM nem com o APNs.
@Suite("Canal do push sem Firebase, como no esquema Local (#8)", .enabled(if: !RelatorioDeFalhas.firebaseConfigurado))
struct CanalDePushSemFirebaseTests {
    @Test("Ativar entrega o token simulado a quem registra o aparelho, a cada abertura")
    func tokenSimulado() async {
        let recebidos = TokensRecebidos()
        let canal = CanalDePushDoAparelho(tokenSimulado: "token-simulado-do-teste-0001") { await recebidos.anotar($0) }

        await canal.ativar()
        await canal.ativar()

        #expect(await recebidos.tokens == ["token-simulado-do-teste-0001", "token-simulado-do-teste-0001"])
    }

    @Test("Sem token simulado, ativar não entrega nada, e o token do APNs é ignorado")
    func semTokenSimulado() async {
        let recebidos = TokensRecebidos()
        let canal = CanalDePushDoAparelho { await recebidos.anotar($0) }

        await canal.ativar()
        CanalDePushDoAparelho.recebeu(tokenDoAPNs: Data([0x01, 0x02, 0x03]))

        #expect(await recebidos.tokens.isEmpty)
    }

    @Test("Suspender a entrega desregistra o app no sistema, e sem Firebase ativar não o registra de volta")
    func suspenderEntrega() async {
        let pedidos = TokensRecebidos()
        let sistema = CanalDePushDoAparelho.RegistroNoSistema(
            registrar: { Task { await pedidos.anotar("registrar") } },
            desregistrar: { Task { await pedidos.anotar("desregistrar") } }
        )
        let canal = CanalDePushDoAparelho(sistema: sistema) { _ in }

        await canal.suspenderEntrega()
        await canal.ativar()
        // Os pedidos são anotados numa tarefa: dá a vez para ela rodar.
        for _ in 0..<100 where await pedidos.tokens.isEmpty { await Task.yield() }

        #expect(await pedidos.tokens == ["desregistrar"])
    }
}

@Suite("Configuração do push por esquema (#8)")
struct ConfiguracaoDoPushTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func texto(_ caminho: String) throws -> String {
        try String(contentsOf: Self.raiz.appending(path: caminho), encoding: .utf8)
    }

    @Test("Os esquemas de Release declaram o APNs de produção, e os de Debug, o de desenvolvimento", arguments: [
        ("Local", "development"), ("Dev", "development"), ("Beta", "production"), ("Prod", "production"),
    ])
    func ambienteDoAPNs(esquema: String, ambiente: String) throws {
        let linhas = try texto("Configurations/\(esquema).xcconfig").split(separator: "\n").map { $0.filter { !$0.isWhitespace } }
        #expect(linhas.filter { $0.hasPrefix("FRILA_APS_ENVIRONMENT=") } == ["FRILA_APS_ENVIRONMENT=\(ambiente)"])
    }

    @Test("O entitlement do push vem da configuração do esquema, e não fixo no arquivo")
    func entitlement() throws {
        let dados = try Data(contentsOf: Self.raiz.appending(path: "Sources/App/Frila.entitlements"))
        let direitos = try #require(PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])
        #expect(direitos["aps-environment"] as? String == "$(FRILA_APS_ENVIRONMENT)")
    }

    /// O token de push é registrado no servidor para a conta (`registrar_dispositivo`): é um
    /// identificador do aparelho vinculado à pessoa, e o manifesto de privacidade diz isso.
    @Test("O manifesto de privacidade declara o Device ID vinculado à pessoa, só para o funcionamento do app e sem rastreamento")
    func deviceIDVinculado() throws {
        let dados = try Data(contentsOf: Self.raiz.appending(path: "Resources/PrivacyInfo.xcprivacy"))
        let manifesto = try #require(PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])
        let coletados = try #require(manifesto["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let deviceID = try #require(coletados.first { $0["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeDeviceID" })

        #expect(deviceID["NSPrivacyCollectedDataTypeLinked"] as? Bool == true)
        #expect(deviceID["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        #expect(deviceID["NSPrivacyCollectedDataTypePurposes"] as? [String] == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
    }

    @Test("O proxy do Firebase fica desligado: o token e o toque passam pelo AppDelegate, à vista")
    func proxyDesligado() throws {
        let dados = try Data(contentsOf: Self.raiz.appending(path: "Sources/App/Info.plist"))
        let info = try #require(PropertyListSerialization.propertyList(from: dados, format: nil) as? [String: Any])
        #expect(info["FirebaseAppDelegateProxyEnabled"] as? Bool == false)
        #expect(try texto("project.yml").contains("product: FirebaseMessaging"))
    }
}
