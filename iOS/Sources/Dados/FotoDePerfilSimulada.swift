import Foundation
import FrilaDominio

/// Dublê da verificação do aparelho para testes e para o esquema Frila-Local: simula o resultado
/// sem executar a análise do Vision sobre a imagem.
public final class VerificadorLocalDeFotoSimulado: VerificadorLocalDeFoto, @unchecked Sendable {
    public var resultado: ResultadoDaVerificacaoLocal
    public private(set) var chamadas = 0
    private let trava = NSLock()

    public init(resultado: ResultadoDaVerificacaoLocal = .liberada) {
        self.resultado = resultado
    }

    public func verificar(jpeg: Data, contexto: ContextoDaFotoDePerfil) async -> ResultadoDaVerificacaoLocal {
        trava.withLock {
            chamadas += 1
            return resultado
        }
    }

    public func verificar(jpeg: Data) async -> ResultadoDaVerificacaoLocal {
        await verificar(jpeg: jpeg, contexto: .profissional)
    }

    #if DEBUG
    /// Só em Debug, como o `ApiClienteEmMemoria.pelosArgumentos` (#96): o Release não lê argumentos de
    /// lançamento. `-FRILA_FOTO_VERIFICACAO <telefone|email|link|pix|qrcode|sem_rosto|multiplos_rostos|indisponivel>`
    /// faz a verificação do aparelho bloquear a foto com esse motivo.
    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> VerificadorLocalDeFotoSimulado {
        guard let indice = argumentos.firstIndex(of: "-FRILA_FOTO_VERIFICACAO"), argumentos.indices.contains(indice + 1) else {
            return VerificadorLocalDeFotoSimulado()
        }
        let motivo: MotivoDeBloqueioLocal? = switch argumentos[indice + 1] {
        case "telefone": .telefone
        case "email": .email
        case "link": .linkOuArroba
        case "pix": .chavePix
        case "qrcode": .qrCode
        case "sem_rosto", "rosto_nao_encontrado", "improprio": .rostoNaoEncontrado
        case "multiplos_rostos": .multiplosRostos
        case "indisponivel": .analiseIndisponivel
        default: nil
        }
        return VerificadorLocalDeFotoSimulado(resultado: motivo.map(ResultadoDaVerificacaoLocal.bloqueada) ?? .liberada)
    }
    #endif
}

/// Dublê do envio para a URL assinada: guarda quantos bytes receberia e não toca a rede.
public final class EnviadorDeMidiaSimulado: EnviadorDeMidia, @unchecked Sendable {
    public private(set) var envios: [(bytes: Int, url: URL)] = []
    public var erro: (any Error)?
    private let trava = NSLock()

    public init(erro: (any Error)? = nil) {
        self.erro = erro
    }

    public func enviar(_ jpeg: Data, para url: URL) async throws {
        try trava.withLock {
            if let erro { throw erro }
            envios.append((jpeg.count, url))
        }
    }
}
