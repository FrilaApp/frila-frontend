import Foundation
#if DEBUG || FRILA_MEDICAO
import os
#endif

/// Telas cuja abertura é medida (#73, RNF01). O tipo existe em todo build para a Apresentação
/// chamar `medirAbertura` sem `#if`; o registro das medições só existe no Debug e no build de medição.
public enum TelaMedida: String, CaseIterable, Codable, Sendable {
    case listaDeVagas = "Lista de vagas"
    case detalheDaVaga = "Detalhe da vaga"
    case meuTurno = "Meu turno"
}

#if DEBUG || FRILA_MEDICAO
/// Medições de desempenho e de dados (#73). Compila em Debug, para a CI exercitar, e no Release só
/// com a condição `FRILA_MEDICAO` (o build de medição do aparelho); o `conferir-release.sh` reprova
/// este código em qualquer outro Release. Guarda só o nome da tela, a duração em milissegundos e a
/// soma de bytes: nada da pessoa, da vaga ou do turno. As medições ficam no aparelho até "Zerar",
/// para somar aberturas de várias execuções do app.
public final class RegistroDeMedicoes: @unchecked Sendable {
    public static let compartilhado = RegistroDeMedicoes(defaults: .standard)

    /// No build de medição o registro está sempre ligado; em Debug, só com `-FRILA_MEDICAO`, para os
    /// outros testes de interface não verem o botão nem gravarem medições.
    public static var ativo: Bool {
        #if FRILA_MEDICAO
        true
        #else
        ProcessInfo.processInfo.arguments.contains("-FRILA_MEDICAO")
        #endif
    }

    static let chave = "frila-medicao-de-desempenho"
    public static let sinalizador = OSSignposter(subsystem: "com.frila.org.app", category: "medicao-de-desempenho")
    /// Cada medição também vai ao log do sistema, só com números, para o Console ou o
    /// `log stream` lerem sem abrir o relatório.
    private static let log = Logger(subsystem: "com.frila.org.app", category: "medicao-de-desempenho")

    private struct Dados: Codable {
        var duracoes: [String: [Double]] = [:]
        var requisicoes = 0
        var bytesEnviados: Int64 = 0
        var bytesRecebidos: Int64 = 0
    }

    private let trava = NSLock()
    private let defaults: UserDefaults
    private var dados: Dados

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        if let guardado = defaults.data(forKey: Self.chave),
           let lido = try? JSONDecoder().decode(Dados.self, from: guardado) {
            dados = lido
        } else {
            dados = Dados()
        }
    }

    public func registrar(_ tela: TelaMedida, milissegundos: Double) {
        Self.log.notice("abertura tela=\(tela.rawValue, privacy: .public) ms=\(Int(milissegundos.rounded()), privacy: .public)")
        alterar { $0.duracoes[tela.rawValue, default: []].append(milissegundos) }
    }

    /// Uma requisição terminada, com os bytes de cabeçalho e de corpo que passaram pela rede.
    public func registrarTransferencia(enviados: Int64, recebidos: Int64) {
        Self.log.notice("requisicao enviados=\(enviados, privacy: .public) recebidos=\(recebidos, privacy: .public)")
        alterar {
            $0.requisicoes += 1
            $0.bytesEnviados += enviados
            $0.bytesRecebidos += recebidos
        }
    }

    public func zerar() {
        alterar { $0 = Dados() }
    }

    public func resumo() -> ResumoDasMedicoes {
        let copia = trava.withLock { dados }
        let telas = TelaMedida.allCases.map { tela in
            let valores = copia.duracoes[tela.rawValue] ?? []
            return ResumoDeTela(
                tela: tela,
                quantidade: valores.count,
                p50: Self.percentil(50, de: valores),
                p95: Self.percentil(95, de: valores),
                maximo: valores.max()
            )
        }
        return ResumoDasMedicoes(
            telas: telas,
            requisicoes: copia.requisicoes,
            bytesEnviados: copia.bytesEnviados,
            bytesRecebidos: copia.bytesRecebidos
        )
    }

    /// Percentil pelo método do posto mais próximo: o menor valor com pelo menos p% das medições
    /// iguais ou abaixo dele. Com 20 medições, o p95 é a 19ª menor.
    public static func percentil(_ p: Double, de valores: [Double]) -> Double? {
        guard !valores.isEmpty, p > 0, p <= 100 else { return nil }
        let ordenados = valores.sorted()
        let posto = Int((p / 100 * Double(ordenados.count)).rounded(.up))
        return ordenados[max(posto, 1) - 1]
    }

    private func alterar(_ mudanca: (inout Dados) -> Void) {
        let codificado: Data? = trava.withLock {
            mudanca(&dados)
            return try? JSONEncoder().encode(dados)
        }
        if let codificado { defaults.set(codificado, forKey: Self.chave) }
    }
}

public struct ResumoDeTela: Equatable, Sendable {
    public let tela: TelaMedida
    public let quantidade: Int
    public let p50: Double?
    public let p95: Double?
    public let maximo: Double?
}

public struct ResumoDasMedicoes: Equatable, Sendable {
    public let telas: [ResumoDeTela]
    public let requisicoes: Int
    public let bytesEnviados: Int64
    public let bytesRecebidos: Int64

    public var bytesTotais: Int64 { bytesEnviados + bytesRecebidos }

    /// RNF05: a sessão de consulta e candidatura fica abaixo de 1 MB (1.000.000 bytes).
    public static let limiteDaSessao: Int64 = 1_000_000

    /// O relatório que o botão "Copiar" põe na área de transferência: só números.
    public var texto: String {
        var linhas = ["Medições do Frila (#73)"]
        for tela in telas {
            let n = tela.quantidade
            if n == 0 {
                linhas.append("\(tela.tela.rawValue): sem medições")
            } else {
                linhas.append("\(tela.tela.rawValue): n=\(n) p50=\(Self.ms(tela.p50)) p95=\(Self.ms(tela.p95)) máx=\(Self.ms(tela.maximo))")
            }
        }
        let situacao = bytesTotais < Self.limiteDaSessao ? "abaixo de 1 MB" : "acima de 1 MB"
        linhas.append("Rede: \(requisicoes) requisições, enviados \(bytesEnviados) B, recebidos \(bytesRecebidos) B, total \(bytesTotais) B (\(situacao))")
        return linhas.joined(separator: "\n")
    }

    public static func ms(_ valor: Double?) -> String {
        guard let valor else { return "-" }
        return "\(Int(valor.rounded())) ms"
    }
}
#endif
