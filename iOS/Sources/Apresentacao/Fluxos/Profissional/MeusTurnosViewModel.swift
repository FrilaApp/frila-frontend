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
