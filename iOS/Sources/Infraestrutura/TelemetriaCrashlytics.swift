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

    /// A chave do Info.plist que liga ou desliga a coleta do Crashlytics (o SDK lê a mesma).
    public static let chaveDaColeta = "FirebaseCrashlyticsCollectionEnabled"

    /// Se o Info.plist liga a coleta do Crashlytics. Na 1.1 ela vem desligada (C1, 08/11/2026: falta
    /// base legal para transferir dados de falha ao Google nos EUA). Sem a chave, conta como desligada.
    public static func coletaLigada(bundle: Bundle = .main) -> Bool {
        (bundle.object(forInfoDictionaryKey: chaveDaColeta) as? Bool) == true
    }

    /// O esquema Local não inclui o plist; assim, seus testes e o dublê permanecem sem Firebase.
    /// O FirebaseApp continua configurado mesmo com o Crashlytics desligado: o push (FCM) depende dele.
    public static func iniciarSeConfigurado(bundle: Bundle = .main) {
        guard bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return }
        let configurouAgora = configurado.withLock { jaConfigurado -> Bool in
            guard !jaConfigurado else { return false }
            FirebaseApp.configure()
            jaConfigurado = true
            return true
        }
        // Com a coleta desligada, o SDK guarda no aparelho os relatórios de falha para enviar
        // depois (FIRCrashlytics.h, Firebase 12.19.2). Como nada será enviado, eles saem na abertura.
        if configurouAgora, !coletaLigada(bundle: bundle) {
            Crashlytics.crashlytics().deleteUnsentReports()
        }
    }
}

/// Onde um erro da API seria gravado. Separado do ator para o teste espiar que nada chega aqui.
public protocol DestinoDeFalhas: Sendable {
    func gravar(codigo: String, rpc: String, duracaoNs: Int64)
}

/// O destino real: o Crashlytics. Só é usado com a coleta ligada no Info.plist.
public struct DestinoCrashlytics: DestinoDeFalhas {
    public init() {}

    public func gravar(codigo: String, rpc: String, duracaoNs: Int64) {
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
            userInfo: ["codigo": codigo, "rpc": rpc, "duracao_ns": duracaoNs]
        )
    }
}

public actor TelemetriaCrashlytics: TelemetryReporter {
    private let coletaLigada: Bool
    private let destino: any DestinoDeFalhas

    /// Por padrão, a coleta segue o Info.plist do app, que na 1.1 a desliga: nada é gravado.
    public init(coletaLigada: Bool = RelatorioDeFalhas.coletaLigada(), destino: any DestinoDeFalhas = DestinoCrashlytics()) {
        self.coletaLigada = coletaLigada
        self.destino = destino
    }

    public func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async {
        // Coleta desligada: nada vai ao Crashlytics, nem fica guardado no aparelho para depois.
        guard coletaLigada else { return }
        let componentes = duracao.components
        let nanos = componentes.seconds * 1_000_000_000 + componentes.attoseconds / 1_000_000_000
        destino.gravar(codigo: codigo, rpc: rpc, duracaoNs: nanos)
    }
}
