import FrilaDominio
import Foundation
import Network

/// `NWPathMonitor` como `MonitorDeConexao`. Um monitor por sequência: cancelar a sequência encerra o
/// monitor, e nada fica ouvindo a rede depois que a tela ou a tarefa que pediu some.
public struct MonitorDeConexaoDoSistema: MonitorDeConexao {
    public init() {}

    public func estados() -> AsyncStream<Bool> {
        AsyncStream { continuacao in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { caminho in
                continuacao.yield(caminho.status == .satisfied)
            }
            continuacao.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.frila.org.app.conexao"))
        }
    }
}
