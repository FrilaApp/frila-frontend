import CoreGraphics
import Foundation
import os

// Foto de perfil, parte do aparelho (contrato 0.2.54, CD-M04b e CD-M06): recorte quadrado, conversão
// para JPEG sem metadados e as verificações locais que rodam antes de qualquer byte subir. Aqui ficam
// só as regras e as portas; Vision e ImageIO moram em `FrilaInfraestrutura`.

/// Limites que o contrato exige do original enviado.
public enum LimitesDaFoto {
    /// Lado maior do JPEG enviado, em pixels.
    public static let ladoMaximo = 1600
    /// Tamanho máximo do arquivo enviado.
    public static let bytesMaximos = 5 * 1024 * 1024
    public static let mime = "image/jpeg"
}

/// O recorte 1:1 escolhido na tela: `zoom` de 1 (a imagem inteira no lado menor) para cima e o
/// deslocamento do centro do recorte, de -1 a 1 em cada eixo, relativo à folga que sobra. Como o
/// quadrado nunca sai da imagem, qualquer valor vira um recorte válido.
public struct RecorteQuadrado: Equatable, Sendable {
    public let zoom: Double
    public let deslocamentoX: Double
    public let deslocamentoY: Double

    public static let centralizado = RecorteQuadrado(zoom: 1)

    public init(zoom: Double = 1, deslocamentoX: Double = 0, deslocamentoY: Double = 0) {
        self.zoom = zoom.isFinite ? min(max(zoom, 1), 8) : 1
        self.deslocamentoX = deslocamentoX.isFinite ? min(max(deslocamentoX, -1), 1) : 0
        self.deslocamentoY = deslocamentoY.isFinite ? min(max(deslocamentoY, -1), 1) : 0
    }

    /// O quadrado, em pixels da imagem, dentro dos limites. Imagem sem área não tem recorte.
    public func retangulo(larguraDaImagem: Int, alturaDaImagem: Int) -> CGRect? {
        guard larguraDaImagem > 0, alturaDaImagem > 0 else { return nil }
        let largura = Double(larguraDaImagem)
        let altura = Double(alturaDaImagem)
        let lado = (min(largura, altura) / zoom).rounded(.down)
        guard lado >= 1 else { return nil }
        let folgaX = (largura - lado) / 2
        let folgaY = (altura - lado) / 2
        let x = (folgaX + deslocamentoX * folgaX).rounded()
        let y = (folgaY + deslocamentoY * folgaY).rounded()
        return CGRect(x: min(max(x, 0), largura - lado), y: min(max(y, 0), altura - lado), width: lado, height: lado)
    }
}

/// O JPEG pronto para subir: quadrado, até 1600 px de lado, até 5 MB e sem nenhum metadado.
public struct FotoPreparada: Equatable, Sendable {
    public let jpeg: Data
    public let lado: Int

    public init(jpeg: Data, lado: Int) {
        self.jpeg = jpeg
        self.lado = lado
    }
}

public enum ErroDePreparoDaFoto: Error, Equatable, Sendable {
    /// Os bytes não são uma imagem que o aparelho consiga abrir.
    case imagemInvalida
    /// Nem na menor qualidade o JPEG coube em 5 MB.
    case grandeDemais
}

/// Recorta, reduz, converte para JPEG e remove todos os metadados (EXIF, GPS, TIFF, IPTC, orientação
/// embutida): a orientação é aplicada nos pixels antes do recorte.
public protocol PreparadorDeFoto: Sendable {
    func preparar(original: Data, recorte: RecorteQuadrado) throws -> FotoPreparada
}

/// Contexto em que a foto de perfil está sendo analisada no aparelho.
public enum ContextoDaFotoDePerfil: String, CaseIterable, Equatable, Sendable {
    /// Exige exatamente um rosto inteiro e nítido.
    case profissional
    /// Imagem livre (fachada, ambiente, logo), sem exigência de rosto, mas restringe códigos e dados de contato.
    case estabelecimento
}

/// Por que a verificação do aparelho não deixou a foto subir.
public enum MotivoDeBloqueioLocal: Equatable, Sendable {
    case telefone
    case email
    case linkOuArroba
    case chavePix
    case qrCode
    /// Nenhum rosto foi detectado na foto ou a qualidade é insuficiente para identificação facial (perfil profissional).
    case rostoNaoEncontrado
    /// Mais de um rosto foi detectado na foto (o perfil profissional deve ser individual).
    case multiplosRostos
    /// A análise local não rodou (erro, prazo, recurso indisponível): a foto não sobe (falha fechada).
    case analiseIndisponivel

    /// A foto tem dado de contato, e a recusa é pelo texto ou código que ela mostra.
    public var ehDadoDeContato: Bool {
        switch self {
        case .telefone, .email, .linkOuArroba, .chavePix, .qrCode: true
        case .rostoNaoEncontrado, .multiplosRostos, .analiseIndisponivel: false
        }
    }
}

public enum ResultadoDaVerificacaoLocal: Equatable, Sendable {
    case liberada
    case bloqueada(MotivoDeBloqueioLocal)
}

/// As verificações do aparelho (CD-M06, camada 1): texto com telefone, e-mail, link, @ ou Pix; QR code ou
/// código de barras; detecção de rosto para perfil profissional. Falha fechada: o que não puder rodar volta como
/// `.bloqueada(.analiseIndisponivel)`, e a foto não sobe.
public protocol VerificadorLocalDeFoto: Sendable {
    func verificar(jpeg: Data, contexto: ContextoDaFotoDePerfil) async -> ResultadoDaVerificacaoLocal
}

public extension VerificadorLocalDeFoto {
    func verificar(jpeg: Data) async -> ResultadoDaVerificacaoLocal {
        await verificar(jpeg: jpeg, contexto: .profissional)
    }
}

/// Envia os bytes para a URL assinada que `solicitar_upload_midia` devolveu.
public protocol EnviadorDeMidia: Sendable {
    func enviar(_ jpeg: Data, para url: URL) async throws
}

/// Procura nos textos lidos da foto o que não pode aparecer nela. Puro e sem Vision, para ser testado
/// com texto na mão: o reconhecimento de texto da imagem só alimenta esta função.
public enum DetectorDeDadosEmTexto {
    /// O primeiro motivo encontrado, na ordem Pix, e-mail, link ou @, telefone; `nil` se o texto está limpo.
    public static func motivo(em textos: [String]) -> MotivoDeBloqueioLocal? {
        let encontrados = Set(textos.compactMap(motivo(em:)))
        for motivo in [MotivoDeBloqueioLocal.chavePix, .email, .linkOuArroba, .telefone] where encontrados.contains(motivo) {
            return motivo
        }
        return nil
    }

    public static func motivo(em texto: String) -> MotivoDeBloqueioLocal? {
        let linha = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !linha.isEmpty else { return nil }
        if ehChavePix(linha) { return .chavePix }
        if contem(email, em: linha) { return .email }
        if contem(link, em: linha) || contem(arroba, em: linha) { return .linkOuArroba }
        if temTelefone(linha) { return .telefone }
        return nil
    }

    // MARK: Regras

    /// A palavra "pix", uma chave aleatória (UUID) ou CPF/CNPJ formatado.
    private static func ehChavePix(_ linha: String) -> Bool {
        contem(palavraPix, em: linha) || contem(uuid, em: linha) || contem(cpfOuCnpjFormatado, em: linha)
    }

    /// Dez ou mais dígitos juntos, ignorando espaço, ponto, hífen, parêntese e `+`. Um ano ou um número
    /// de camisa não chega perto; um celular com DDD (11 dígitos) ou fixo (10) passa.
    private static func temTelefone(_ linha: String) -> Bool {
        guard let sequencia = try? NSRegularExpression(pattern: #"(?:\+?\d[\s().\-]*){10,}"#) else { return false }
        let intervalo = NSRange(linha.startIndex..., in: linha)
        return sequencia.firstMatch(in: linha, range: intervalo) != nil
            || contem(telefoneCurto, em: linha)
    }

    private static func contem(_ padrao: String, em linha: String) -> Bool {
        guard let expressao = try? NSRegularExpression(pattern: padrao, options: [.caseInsensitive]) else { return false }
        return expressao.firstMatch(in: linha, range: NSRange(linha.startIndex..., in: linha)) != nil
    }

    private static let palavraPix = #"\bp\s?i\s?x\b"#
    private static let uuid = #"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#
    private static let cpfOuCnpjFormatado = #"\b\d{3}\.\d{3}\.\d{3}-\d{2}\b|\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b"#
    private static let email = #"[a-z0-9._%+\-]+\s?@\s?[a-z0-9\-]+(?:\.[a-z0-9\-]+)+"#
    private static let link = #"https?://|\bwww\.|\b[a-z0-9\-]+\.(?:com|net|org|app|io|me|ly|gov|edu)(?:\.br)?\b|\b[a-z0-9\-]+\.br\b"#
    private static let arroba = #"(?:^|\s)@\s?[a-z0-9_.]{2,}"#
    /// Celular sem DDD no formato 9XXXX-XXXX, que a regra dos dez dígitos não pega. O fixo sem DDD
    /// (XXXX-XXXX) fica de fora de propósito: "2020-2024" na camisa não é telefone.
    private static let telefoneCurto = #"\b9\d{4}[\s\-]\d{4}\b"#
}

/// Roda `operacao` e devolve `nil` se ela não terminar no `prazo`. O prazo vence mesmo que a operação
/// ignore o cancelamento (uma chamada do sistema que não volta): quem chama não espera por ela. É o
/// "prazo e fallback explícitos" de todo `await` de API do sistema dentro de um fluxo com `carregando`.
public func executarComPrazo<T: Sendable>(_ prazo: Duration, _ operacao: @escaping @Sendable () async -> T) async -> T? {
    await withCheckedContinuation { (continuacao: CheckedContinuation<T?, Never>) in
        let entregue = OSAllocatedUnfairLock(initialState: false)
        @Sendable func entregar(_ valor: T?) {
            let primeira = entregue.withLock { jaEntregue -> Bool in
                if jaEntregue { return false }
                jaEntregue = true
                return true
            }
            if primeira { continuacao.resume(returning: valor) }
        }
        let trabalho = Task { entregar(await operacao()) }
        Task {
            try? await Task.sleep(for: prazo)
            trabalho.cancel()
            entregar(nil)
        }
    }
}

/// As três peças do aparelho que a foto de perfil usa. O app monta as de verdade (ImageIO e Vision,
/// e o envio HTTP) uma vez, na raiz; a tela lê do ambiente.
public struct FerramentasDaFoto: Sendable {
    public let preparador: any PreparadorDeFoto
    public let verificador: any VerificadorLocalDeFoto
    public let enviador: any EnviadorDeMidia

    public init(preparador: any PreparadorDeFoto, verificador: any VerificadorLocalDeFoto, enviador: any EnviadorDeMidia) {
        self.preparador = preparador
        self.verificador = verificador
        self.enviador = enviador
    }

    /// Sem as peças montadas nada sobe: o verificador bloqueia (falha fechada) e o preparador recusa.
    public static let indisponivel = FerramentasDaFoto(
        preparador: PreparadorIndisponivel(), verificador: VerificadorIndisponivel(), enviador: EnviadorIndisponivel()
    )

    private struct PreparadorIndisponivel: PreparadorDeFoto {
        func preparar(original: Data, recorte: RecorteQuadrado) throws -> FotoPreparada { throw ErroDePreparoDaFoto.imagemInvalida }
    }

    private struct VerificadorIndisponivel: VerificadorLocalDeFoto {
        func verificar(jpeg: Data, contexto: ContextoDaFotoDePerfil) async -> ResultadoDaVerificacaoLocal {
            .bloqueada(.analiseIndisponivel)
        }
    }

    private struct EnviadorIndisponivel: EnviadorDeMidia {
        func enviar(_ jpeg: Data, para url: URL) async throws { throw ErroDaApi(codigo: .semRede) }
    }
}
