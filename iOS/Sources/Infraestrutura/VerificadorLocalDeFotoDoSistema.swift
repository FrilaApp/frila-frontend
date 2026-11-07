import CoreML
import Foundation
import FrilaDominio
import OSLog
import Vision

/// O classificador de conteúdo impróprio, atrás de uma porta para o teste usar um falso.
public protocol ClassificadorDeConteudo: Sendable {
    /// De 0 a 1: a confiança de que a imagem tem conteúdo impróprio. Lança se não puder analisar.
    func pontuacaoDeConteudoImproprio(em jpeg: Data) async throws -> Double
}

public enum ErroDoClassificadorDeConteudo: Error, Equatable, Sendable {
    /// O modelo CoreML não está no bundle: a análise local não roda e a foto não sobe.
    case modeloAusente
    case modeloInvalido
    case semResultado
}

/// CoreML como `ClassificadorDeConteudo` (CD-M06, camada 1): carrega um classificador de imagem do bundle
/// e devolve a maior confiança entre os rótulos tidos como impróprios.
///
/// **Falha fechada:** sem o modelo compilado no bundle (`<nome>.mlmodelc`), ou com ele quebrado,
/// `pontuacaoDeConteudoImproprio` lança e a foto não sobe. O modelo (código aberto, licença
/// permissiva) é escolhido e registrado pelo Prisma; este módulo não embute nenhum.
public struct ClassificadorDeConteudoCoreML: ClassificadorDeConteudo {
    public static let nomePadraoDoModelo = "FrilaModeracaoFoto"
    /// Rótulos que, em classificadores de conteúdo adulto de código aberto, indicam imagem imprópria.
    public static let rotulosPadraoImproprios: Set<String> = ["nsfw", "porn", "hentai", "sexy", "unsafe", "adult", "explicit"]

    private let nomeDoModelo: String
    private let bundle: Bundle
    private let rotulosImproprios: Set<String>

    public init(
        nomeDoModelo: String = Self.nomePadraoDoModelo,
        bundle: Bundle = .main,
        rotulosImproprios: Set<String> = Self.rotulosPadraoImproprios
    ) {
        self.nomeDoModelo = nomeDoModelo
        self.bundle = bundle
        self.rotulosImproprios = rotulosImproprios
    }

    public func pontuacaoDeConteudoImproprio(em jpeg: Data) async throws -> Double {
        guard let url = bundle.url(forResource: nomeDoModelo, withExtension: "mlmodelc") else {
            throw ErroDoClassificadorDeConteudo.modeloAusente
        }
        let rotulos = rotulosImproprios
        return try await Task.detached(priority: .userInitiated) {
            let configuracao = MLModelConfiguration()
            let modelo: VNCoreMLModel
            do {
                modelo = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: configuracao))
            } catch {
                throw ErroDoClassificadorDeConteudo.modeloInvalido
            }
            let pedido = VNCoreMLRequest(model: modelo)
            pedido.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(data: jpeg, options: [:]).perform([pedido])
            let observacoes = (pedido.results ?? []).compactMap { $0 as? VNClassificationObservation }
            guard !observacoes.isEmpty else { throw ErroDoClassificadorDeConteudo.semResultado }
            let improprias = observacoes.filter { rotulos.contains($0.identifier.lowercased()) }
            return Double(improprias.map(\.confidence).max() ?? 0)
        }.value
    }
}

/// Vision e CoreML como `VerificadorLocalDeFoto` (CD-M06, camada 1): QR code ou código de barras,
/// texto com telefone, e-mail, link, @ ou Pix e conteúdo impróprio. **Falha fechada:** qualquer erro,
/// modelo ausente ou prazo estourado volta como `.bloqueada(.analiseIndisponivel)`.
public struct VerificadorLocalDeFotoDoSistema: VerificadorLocalDeFoto {
    private static let log = Logger(subsystem: "com.frila.org.app", category: "foto-perfil")

    /// A partir daqui a imagem é tida como imprópria.
    public static let limiteDeConteudoImproprio = 0.7
    /// A análise inteira, com folga para o aparelho mais lento, e nunca sem fim.
    public static let prazo: Duration = .seconds(30)

    private let classificador: any ClassificadorDeConteudo
    private let limite: Double
    private let prazoDaAnalise: Duration

    public init(
        classificador: any ClassificadorDeConteudo = ClassificadorDeConteudoCoreML(),
        limite: Double = Self.limiteDeConteudoImproprio,
        prazo: Duration = Self.prazo
    ) {
        self.classificador = classificador
        self.limite = limite
        self.prazoDaAnalise = prazo
    }

    public func verificar(jpeg: Data) async -> ResultadoDaVerificacaoLocal {
        let resultado = await executarComPrazo(prazoDaAnalise) { await analisar(jpeg) }
        return resultado ?? .bloqueada(.analiseIndisponivel)
    }

    private func analisar(_ jpeg: Data) async -> ResultadoDaVerificacaoLocal {
        do {
            let achados = try await Task.detached(priority: .userInitiated) { try Self.lerCodigosETextos(jpeg) }.value
            if achados.temCodigo { return .bloqueada(.qrCode) }
            if let motivo = DetectorDeDadosEmTexto.motivo(em: achados.textos) { return .bloqueada(motivo) }
            let pontuacao = try await classificador.pontuacaoDeConteudoImproprio(em: jpeg)
            return pontuacao >= limite ? .bloqueada(.conteudoImproprio) : .liberada
        } catch {
            // Só o tipo do erro vai ao log, nunca a imagem nem o texto lido dela.
            Self.log.error("analise_local_falhou erro=\(String(describing: type(of: error)), privacy: .public)")
            return .bloqueada(.analiseIndisponivel)
        }
    }

    struct Achados {
        let temCodigo: Bool
        let textos: [String]
    }

    /// Os dois pedidos do Vision sobre a mesma imagem, um de cada vez: juntos, o simulador recusa o
    /// conjunto com "Could not create inference context".
    static func lerCodigosETextos(_ jpeg: Data) throws -> Achados {
        let codigos = VNDetectBarcodesRequest()
        #if targetEnvironment(simulator)
        // O simulador não tem Neural Engine. O detector no dispositivo padrão falha com "Could not create
        // inference context"; na CPU roda, mas as revisões 3 e 4 (de aprendizado de máquina, o padrão no
        // aparelho) não acham nada, sem erro algum. A revisão 2, clássica, acha. No aparelho vale o padrão.
        codigos.revision = VNDetectBarcodesRequestRevision2
        if let cpu = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
            codigos.setComputeDevice(cpu, for: .main)
        }
        #endif
        let texto = VNRecognizeTextRequest()
        texto.recognitionLevel = .accurate
        // Correção de idioma "conserta" dígito em letra e esconderia um telefone: lê o que está escrito.
        texto.usesLanguageCorrection = false
        texto.recognitionLanguages = ["pt-BR", "en-US"]
        try VNImageRequestHandler(data: jpeg, options: [:]).perform([codigos])
        try VNImageRequestHandler(data: jpeg, options: [:]).perform([texto])
        let linhas = (texto.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return Achados(temCodigo: !(codigos.results ?? []).isEmpty, textos: linhas)
    }
}
