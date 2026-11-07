import Foundation
import FrilaDominio
import OSLog
import Vision

/// Vision como `VerificadorLocalDeFoto` (CD-M06, camada 1, parecer J-007):
/// - Profissional: exige exatamente um rosto inteiro e nítido (via `VNDetectFaceRectanglesRequest`,
///   sem landmarks faciais para evitar coleta de dados biométricos).
/// - Estabelecimento: imagem livre e texto geral liberado, mas veda códigos e dados de contato.
/// - Em ambos: QR code/código de barras e dados de contato (telefone, e-mail, link, @, Pix) são barrados.
/// **Falha fechada:** qualquer erro ou prazo estourado volta como `.bloqueada(.analiseIndisponivel)`.
public struct VerificadorLocalDeFotoDoSistema: VerificadorLocalDeFoto {
    private static let log = Logger(subsystem: "com.frila.org.app", category: "foto-perfil")

    /// Prazo total da análise com folga, para aparelhos mais lentos sem travar a interface.
    public static let prazo: Duration = .seconds(30)

    /// Confiança mínima para considerar um retângulo facial válido.
    public static let confiancaMinimaRosto: Float = 0.5
    /// Área mínima do retângulo do rosto em relação à imagem total (evita rostos minúsculos de fundo).
    public static let areaMinimaRosto: Double = 0.01

    private let prazoDaAnalise: Duration

    public init(prazo: Duration = Self.prazo) {
        self.prazoDaAnalise = prazo
    }

    public func verificar(jpeg: Data, contexto: ContextoDaFotoDePerfil) async -> ResultadoDaVerificacaoLocal {
        let resultado = await executarComPrazo(prazoDaAnalise) { await analisar(jpeg, contexto: contexto) }
        return resultado ?? .bloqueada(.analiseIndisponivel)
    }

    public func verificar(jpeg: Data) async -> ResultadoDaVerificacaoLocal {
        await verificar(jpeg: jpeg, contexto: .profissional)
    }

    private func analisar(_ jpeg: Data, contexto: ContextoDaFotoDePerfil) async -> ResultadoDaVerificacaoLocal {
        do {
            let achados = try await Task.detached(priority: .userInitiated) {
                try Self.executarAnaliseVision(jpeg, contexto: contexto)
            }.value

            if achados.temCodigo {
                return .bloqueada(.qrCode)
            }

            if let motivoContato = DetectorDeDadosEmTexto.motivo(em: achados.textos) {
                return .bloqueada(motivoContato)
            }

            if contexto == .profissional {
                guard achados.totalRostos > 0 else {
                    return .bloqueada(.rostoNaoEncontrado)
                }
                guard achados.totalRostos == 1 else {
                    return .bloqueada(.multiplosRostos)
                }
                guard achados.rostoUnicoValido else {
                    return .bloqueada(.rostoNaoEncontrado)
                }
            }

            return .liberada
        } catch {
            // Só o tipo do erro vai ao log, nunca a imagem nem o texto lido dela.
            Self.log.error("analise_local_falhou erro=\(String(describing: type(of: error)), privacy: .public)")
            return .bloqueada(.analiseIndisponivel)
        }
    }

    struct AchadosAnalise {
        let temCodigo: Bool
        let textos: [String]
        let totalRostos: Int
        let rostoUnicoValido: Bool
    }

    /// Executa os pedidos do Vision sobre o JPEG.
    static func executarAnaliseVision(_ jpeg: Data, contexto: ContextoDaFotoDePerfil) throws -> AchadosAnalise {
        let manipulador = VNImageRequestHandler(data: jpeg, options: [:])

        // 1. Códigos de barras / QR code
        let codigos = VNDetectBarcodesRequest()
        #if targetEnvironment(simulator)
        codigos.revision = VNDetectBarcodesRequestRevision2
        #endif
        try manipulador.perform([codigos])
        let temCodigo = !(codigos.results ?? []).isEmpty

        // 2. Reconhecimento de texto
        let texto = VNRecognizeTextRequest()
        texto.recognitionLevel = .accurate
        // Correção de idioma "conserta" dígito em letra e esconderia um telefone: lê o que está escrito.
        texto.usesLanguageCorrection = false
        texto.recognitionLanguages = ["pt-BR", "en-US"]
        try manipulador.perform([texto])
        let linhas = (texto.results ?? []).compactMap { $0.topCandidates(1).first?.string }

        // 3. Detecção de rostos (apenas retângulos, sem landmarks - parecer J-007)
        var totalRostos = 0
        var rostoValido = false

        if contexto == .profissional {
            let pedidoRostos = VNDetectFaceRectanglesRequest()
            try manipulador.perform([pedidoRostos])
            let observacoes = pedidoRostos.results ?? []
            totalRostos = observacoes.count

            if observacoes.count == 1, let face = observacoes.first {
                let confiancaOk = face.confidence >= confiancaMinimaRosto
                let area = Double(face.boundingBox.width * face.boundingBox.height)
                let tamanhoOk = area >= areaMinimaRosto && face.boundingBox.width >= 0.08 && face.boundingBox.height >= 0.08
                let qualidadeOk: Bool
                if let qualidade = face.faceCaptureQuality {
                    qualidadeOk = qualidade >= 0.10
                } else {
                    qualidadeOk = true
                }
                rostoValido = confiancaOk && tamanhoOk && qualidadeOk
            }
        }

        return AchadosAnalise(
            temCodigo: temCodigo,
            textos: linhas,
            totalRostos: totalRostos,
            rostoUnicoValido: rostoValido
        )
    }
}
