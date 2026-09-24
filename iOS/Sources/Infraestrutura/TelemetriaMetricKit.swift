import Foundation
import FrilaDominio
import MetricKit
import OSLog

public actor TelemetriaMetricKit: TelemetryReporter {
    private let logger = Logger(subsystem: "com.frila.org.app", category: "api")

    public init() {}

    public func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async {
        // Apenas metadados operacionais controlados; nunca corpo, token, telefone ou e-mail.
        let nanos = duracao.components.attoseconds / 1_000_000_000
        logger.error("rpc=\(rpc, privacy: .public) code=\(codigo, privacy: .public) duration_ns=\(nanos, privacy: .public)")
    }
}

@MainActor
public final class ColetorMetricKit: NSObject, MXMetricManagerSubscriber {
    public static let compartilhado = ColetorMetricKit()
    private let logger = Logger(subsystem: "com.frila.org.app", category: "metrickit")

    private override init() { super.init() }

    public func iniciar() {
        MXMetricManager.shared.add(self)
    }

    public func encerrar() {
        MXMetricManager.shared.remove(self)
    }

    nonisolated public func didReceive(_ payloads: [MXMetricPayload]) {
        let quantidade = payloads.count
        Task { @MainActor [logger, quantidade] in
            logger.info("metric_payloads=\(quantidade, privacy: .public)")
        }
    }

    nonisolated public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let quantidade = payloads.count
        Task { @MainActor [logger, quantidade] in
            logger.error("diagnostic_payloads=\(quantidade, privacy: .public)")
        }
    }
}
