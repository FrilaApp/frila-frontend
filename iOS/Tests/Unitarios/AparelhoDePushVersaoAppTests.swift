import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Anota o `versaoApp` que chega a `registrarDispositivo`. O `ApiClienteEmMemoria` sozinho não
/// serve para esta prova: com `nil`, ele anota a versão do bundle no lugar, e o teste passaria com
/// a chamada quebrada.
private final class ApiQueAnotaAVersao: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var _versoes: [String?] = []

    var versoes: [String?] { trava.withLock { _versoes } }

    override func registrarDispositivo(tokenFCM: String, versaoApp: String?) async throws -> Dispositivo {
        trava.withLock { _versoes.append(versaoApp) }
        return try await super.registrarDispositivo(tokenFCM: tokenFCM, versaoApp: versaoApp)
    }
}

@Suite("O registro do aparelho manda o versao_app do bundle (1.1, AparelhoDePush.swift:154-156)")
struct AparelhoDePushVersaoAppTests {
    /// Sintético, com os 20 caracteres que o registro exige.
    private let token = "token-fcm-de-exemplo-versao-0001"
    private let contaID = UUID(uuidString: "10000000-0000-0000-0000-0000000000a1")!

    @Test("registrar chama registrarDispositivo com versaoApp igual ao CFBundleShortVersionString")
    func registrarMandaAVersaoDoBundle() async throws {
        let esperada = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let api = ApiQueAnotaAVersao()
        let aparelho = AparelhoDePush(
            api: api,
            armazenamento: ArmazenamentoDoAparelhoEmMemoria(AparelhoGuardado(token: token)),
            vinculoCompartilhado: ArmazenamentoDoVinculoCompartilhadoEmMemoria()
        )

        let registro = await aparelho.registrar(para: contaID)

        guard case .registrado = registro else {
            Issue.record("o registro devia ter sido confirmado, veio \(registro)")
            return
        }
        #expect(api.versoes == [esperada])
    }
}
