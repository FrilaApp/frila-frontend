import Foundation
import FrilaDominio

/// Manda a fila de check-in, check-out e avaliação quando a conexão volta, e também ao abrir o app
/// já com rede, para a ação feita antes de fechar não esperar a próxima queda. Cada ação sai com o
/// instante do toque (`SincronizadorAcoes`), e é esse instante que vale no servidor.
public struct ReenvioAoReconectar: Sendable {
    private let monitor: any MonitorDeConexao
    private let enviarFila: @Sendable () async -> Void

    public init(monitor: any MonitorDeConexao, enviarFila: @escaping @Sendable () async -> Void) {
        self.monitor = monitor
        self.enviarFila = enviarFila
    }

    public init(monitor: any MonitorDeConexao, sincronizador: SincronizadorAcoes) {
        self.init(monitor: monitor) { await sincronizador.sincronizar() }
    }

    /// Roda até a sequência de estados terminar ou a tarefa ser cancelada.
    public func acompanhar() async {
        var conectadoAntes = false
        for await conectado in monitor.estados() {
            if conectado, !conectadoAntes { await enviarFila() }
            conectadoAntes = conectado
        }
    }
}
