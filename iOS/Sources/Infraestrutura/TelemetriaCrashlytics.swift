@preconcurrency import FirebaseCore
@preconcurrency import FirebaseCrashlytics
import Foundation
import FrilaDominio

public enum RelatorioDeFalhas {
    /// O esquema Local não inclui o plist; assim, seus testes e o dublê permanecem sem Firebase.
    public static func iniciarSeConfigurado(bundle: Bundle = .main) {
        guard bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil,
              FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}

public actor TelemetriaCrashlytics: TelemetryReporter {
    public init() {}

    public func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async {
        let componentes = duracao.components
        let nanos = componentes.seconds * 1_000_000_000 + componentes.attoseconds / 1_000_000_000
        let erro = ErroDaApiParaCrashlytics(codigo: codigo)

        // Os três campos abaixo são a totalidade dos metadados anexados ao evento. Não usar
        // setUserID, logs ou valores customizados com dados pessoais nesta integração.
        Crashlytics.crashlytics().record(
            error: erro,
            userInfo: ["codigo": codigo, "rpc": rpc, "duracao_ns": nanos]
        )
    }
}

private struct ErroDaApiParaCrashlytics: LocalizedError {
    let codigo: String

    var errorDescription: String? { "erro_api_\(codigo)" }
}
