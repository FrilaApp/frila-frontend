import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class MeusTurnosViewModel {
    public enum Estado: Equatable {
        case ociosa
        case carregando
        case carregada(turnos: [Turno], origem: OrigemDosTurnos)
        case falha(String)
    }

    public var estado: Estado = .ociosa
    public private(set) var turnos: [Turno] = []
    public private(set) var origem: OrigemDosTurnos = .rede
    private let repositorio: any TurnoRepositorio

    public init(repositorio: any TurnoRepositorio) {
        self.repositorio = repositorio
    }

    public func carregar() async {
        if case .carregando = estado { return }
        estado = .carregando
        await buscar()
    }

    public func atualizar() async {
        await buscar()
    }

    /// Atualização automática: só com a lista na tela, sem carregamento por cima, e a falha deixa
    /// a lista como estava. Sem rede, `TurnosComCache` devolve o cache e a tela mostra o aviso dele.
    public func atualizarEmSilencio() async {
        guard case .carregada = estado, let leitura = try? await repositorio.ler(), !Task.isCancelled,
              case .carregada = estado else { return }
        turnos = leitura.turnos
        origem = leitura.origem
        estado = .carregada(turnos: leitura.turnos, origem: leitura.origem)
    }

    private func buscar() async {
        do {
            let leitura = try await repositorio.ler()
            self.turnos = leitura.turnos
            self.origem = leitura.origem
            self.estado = .carregada(turnos: leitura.turnos, origem: leitura.origem)
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            self.estado = .falha(TextosDoProfissional.Lista.semConexaoMensagem)
        } catch {
            self.estado = .falha(TextosDoProfissional.Turnos.erroAoCarregar)
        }
    }
}
