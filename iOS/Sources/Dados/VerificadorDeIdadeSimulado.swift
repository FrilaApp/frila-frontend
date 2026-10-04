import Foundation
import FrilaDominio

/// Dublê da verificação de idade para testes e para o esquema Frila-Local.
public final class VerificadorDeIdadeSimulado: VerificadorDeIdade, @unchecked Sendable {
    public var resultado: ResultadoVerificacaoIdade
    public private(set) var chamadasAVerificar = 0
    private let trava = NSLock()

    public init(resultado: ResultadoVerificacaoIdade = .dezoitoOuMais) {
        self.resultado = resultado
    }

    @MainActor
    public func verificarMaioridade() async -> ResultadoVerificacaoIdade {
        trava.withLock {
            chamadasAVerificar += 1
            return resultado
        }
    }

    #if DEBUG
    /// Só em Debug, como o `ApiClienteEmMemoria.pelosArgumentos` (#96): o Release não lê argumentos
    /// de lançamento, e o `conferir-release.sh` reprova o símbolo.
    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> VerificadorDeIdadeSimulado {
        guard let indice = argumentos.firstIndex(of: "-FRILA_DECLARED_AGE_RANGE"),
              argumentos.indices.contains(indice + 1) else {
            return VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
        }
        let valor = argumentos[indice + 1]
        let resultado: ResultadoVerificacaoIdade
        switch valor {
        case "abaixo-de-18", "menor":
            resultado = .abaixoDe18
        case "18-ou-mais", "maior", "adulto":
            resultado = .dezoitoOuMais
        case "recusou", "recusa":
            resultado = .recusou
        case "indisponivel", "erro":
            resultado = .indisponivel
        default:
            resultado = ResultadoVerificacaoIdade(rawValue: valor) ?? .dezoitoOuMais
        }
        return VerificadorDeIdadeSimulado(resultado: resultado)
    }
    #endif
}
