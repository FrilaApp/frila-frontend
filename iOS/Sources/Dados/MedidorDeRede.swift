#if DEBUG || FRILA_MEDICAO
import Foundation
import FrilaDominio

/// Soma os bytes de cada requisição do app (#73, RNF05) pelas métricas da `URLSession`: cabeçalho e
/// corpo, enviados e recebidos, como passaram pela rede (o corpo comprimido, quando veio
/// comprimido). Respostas lidas do cache local não contam. Só existe no Debug e no build de medição.
///
/// Fora da conta: o tráfego que não passa por esta sessão (o envio do Crashlytics e os mapas) e a
/// negociação TLS de cada conexão nova.
public final class MedidorDeRede: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let registro: RegistroDeMedicoes

    public init(registro: RegistroDeMedicoes = .compartilhado) {
        self.registro = registro
    }

    /// A sessão que o `SupabaseApiCliente` usa no build de medição, no lugar da `.shared`.
    public static func sessao(registro: RegistroDeMedicoes = .compartilhado) -> URLSession {
        URLSession(configuration: .default, delegate: MedidorDeRede(registro: registro), delegateQueue: nil)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let transacoes = metrics.transactionMetrics.map {
            Transacao(
                pelaRede: $0.resourceFetchType == .networkLoad,
                enviados: $0.countOfRequestHeaderBytesSent + $0.countOfRequestBodyBytesSent,
                recebidos: $0.countOfResponseHeaderBytesReceived + $0.countOfResponseBodyBytesReceived
            )
        }
        guard let soma = Self.somar(transacoes) else { return }
        registro.registrarTransferencia(enviados: soma.enviados, recebidos: soma.recebidos)
    }

    /// Uma transação da requisição: redirecionamentos e novas tentativas viram transações separadas.
    struct Transacao: Equatable {
        let pelaRede: Bool
        let enviados: Int64
        let recebidos: Int64
    }

    /// Soma só o que passou pela rede; `nil` quando a requisição inteira veio do cache local.
    static func somar(_ transacoes: [Transacao]) -> (enviados: Int64, recebidos: Int64)? {
        let pelaRede = transacoes.filter(\.pelaRede)
        guard !pelaRede.isEmpty else { return nil }
        return (pelaRede.reduce(0) { $0 + $1.enviados }, pelaRede.reduce(0) { $0 + $1.recebidos })
    }
}

extension SupabaseApiCliente {
    /// Cliente com uma sessão HTTP escolhida, para o build de medição contar os bytes (#73).
    public convenience init(url: URL, chavePublicavel: String, telemetria: any TelemetryReporter, sessaoMedida: URLSession) {
        self.init(url: url, chavePublicavel: chavePublicavel, telemetria: telemetria, sessaoHTTP: sessaoMedida)
    }
}
#endif
