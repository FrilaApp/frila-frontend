@preconcurrency import FirebaseCore
@preconcurrency import FirebaseCrashlytics
import Foundation
import FrilaDominio
import os

public enum RelatorioDeFalhas {
    /// Guarda se o Firebase já foi configurado. `FirebaseApp.app()` e `FirebaseApp.allApps`
    /// respondem a mesma pergunta, mas registram erro no log ("has not yet been configured")
    /// quando a resposta é não, que é justamente o caso normal na primeira chamada.
    private static let configurado = OSAllocatedUnfairLock(initialState: false)

    /// Se o Firebase está configurado neste processo. O push só fala com o FCM quando está.
    public static var firebaseConfigurado: Bool { configurado.withLock { $0 } }

    /// O esquema Local não inclui o plist; assim, seus testes e o dublê permanecem sem Firebase.
    public static func iniciarSeConfigurado(bundle: Bundle = .main) {
        guard bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return }
        configurado.withLock { jaConfigurado in
            guard !jaConfigurado else { return }
            FirebaseApp.configure()
            jaConfigurado = true
        }
    }
}

public actor TelemetriaCrashlytics: TelemetryReporter {
    public init() {}

    public func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async {
        let componentes = duracao.components
        let nanos = componentes.seconds * 1_000_000_000 + componentes.attoseconds / 1_000_000_000
        // Domínio fixo por código, e não o nome de um tipo Swift privado: o nome de tipo privado
        // carrega um endereço de memória ("unknown context at $1064a0350"), que muda a cada build
        // e abria uma issue nova no painel para o mesmo erro.
        let erro = NSError(
            domain: "frila.api.\(codigo)",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "erro_api_\(codigo)"]
        )

        // Os três campos abaixo são a totalidade dos metadados anexados ao evento. Não usar
        // setUserID, logs ou valores customizados com dados pessoais nesta integração.
        Crashlytics.crashlytics().record(
            error: erro,
            userInfo: ["codigo": codigo, "rpc": rpc, "duracao_ns": nanos]
        )
    }
}
