import CryptoKit
import Foundation
import Security

public enum ProvedorSocial: String, Sendable, Equatable, Hashable {
    case apple
    case google
}

public struct InicioOAuthPKCE: Sendable, Equatable {
    public let transacaoID: String
    public let urlAutorizacao: URL

    public init(transacaoID: String, urlAutorizacao: URL) {
        self.transacaoID = transacaoID
        self.urlAutorizacao = urlAutorizacao
    }
}

public struct ResultadoEntradaSocial: Sendable, Equatable {
    public let provedor: ProvedorSocial
    public let email: String?
    public let nomeSugerido: String?
    public let precisaDefinirSenha: Bool

    public init(
        provedor: ProvedorSocial,
        email: String? = nil,
        nomeSugerido: String? = nil,
        precisaDefinirSenha: Bool = false
    ) {
        self.provedor = provedor
        self.email = email
        self.nomeSugerido = nomeSugerido
        self.precisaDefinirSenha = precisaDefinirSenha
    }
}

public enum ErroEntradaSocial: Error, Equatable, Sendable {
    case cancelado
    case conflitoDeIdentidade
    case provedorIndisponivel
    case callbackInvalido
    case limiteExcedido
    case rede
}

/// Utilitários criptográficos puros para Sign in with Apple (nonce SHA-256) e OAuth PKCE S256 (Google/Apple).
/// Nunca registra tokens, nonces ou códigos em log.
public enum SegurancaOAuthSocial {
    public static let esquemaCallbackPadrao = "frila-auth"
    public static let urlCallbackPadrao = URL(string: "frila-auth://auth/callback")!

    public typealias ProvedorBytesAleatorios = @Sendable (Int) -> Data?

    public static let provedorBytesSistema: ProvedorBytesAleatorios = { quantidade in
        var bytes = [UInt8](repeating: 0, count: quantidade)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return nil }
        return Data(bytes)
    }

    public static func gerarBytesAleatoriosBase64URL(
        quantidade: Int = 32,
        provedorBytes: ProvedorBytesAleatorios = provedorBytesSistema
    ) throws -> String {
        let tamanho = max(16, quantidade)
        guard let dados = provedorBytes(tamanho), dados.count == tamanho else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        return dados.base64URLEncodedString()
    }

    public static func gerarNonceBruto(
        provedorBytes: ProvedorBytesAleatorios = provedorBytesSistema
    ) throws -> String {
        try gerarBytesAleatoriosBase64URL(quantidade: 32, provedorBytes: provedorBytes)
    }

    public static func sha256Hex(_ texto: String) -> String {
        let digest = SHA256.hash(data: Data(texto.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func gerarVerifierPKCE(
        provedorBytes: ProvedorBytesAleatorios = provedorBytesSistema
    ) throws -> String {
        try gerarBytesAleatoriosBase64URL(quantidade: 32, provedorBytes: provedorBytes)
    }

    public static func desafioPKCES256(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    public static func gerarState(
        provedorBytes: ProvedorBytesAleatorios = provedorBytesSistema
    ) throws -> String {
        try gerarBytesAleatoriosBase64URL(quantidade: 16, provedorBytes: provedorBytes)
    }

    public static func ehVerifierPKCEValido(_ verifier: String) -> Bool {
        let count = verifier.count
        guard count >= 43, count <= 128 else { return false }
        return verifier.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57) ||
                (scalar.value >= 65 && scalar.value <= 90) ||
                (scalar.value >= 97 && scalar.value <= 122) ||
                scalar == "-" || scalar == "_"
        }
    }

    public static func extrairCodigoDoCallback(
        url: URL,
        esquemaEsperado: String = esquemaCallbackPadrao,
        hostEsperado: String = "auth",
        pathEsperado: String = "/callback",
        stateEsperado: String? = nil
    ) -> Result<String, ErroEntradaSocial> {
        guard let scheme = url.scheme?.lowercased(), scheme == esquemaEsperado.lowercased(),
              let host = url.host?.lowercased(), host == hostEsperado.lowercased(),
              url.path == pathEsperado
        else {
            return .failure(.callbackInvalido)
        }
        guard let componentes = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.callbackInvalido)
        }
        let itens = componentes.queryItems ?? []
        let mapa = Dictionary(itens.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { _, novo in novo })

        let correlacaoRecebida = mapa["tx"] ?? mapa["state"]
        if let stateEsperado {
            guard let correlacaoRecebida, !correlacaoRecebida.isEmpty, correlacaoRecebida == stateEsperado else {
                return .failure(.callbackInvalido)
            }
        }

        if let erro = mapa["error"] ?? mapa["error_code"] {
            let combinado = "\(erro) \(mapa["error_description"] ?? "")".lowercased()
            if combinado.contains("access_denied") || combinado.contains("cancel") {
                return .failure(.cancelado)
            }
            if combinado.contains("identity_already_exists")
                || combinado.contains("manual_linking")
                || combinado.contains("email_conflict")
                || combinado.contains("already_registered")
            {
                return .failure(.conflitoDeIdentidade)
            }
            return .failure(.provedorIndisponivel)
        }

        guard let codigo = mapa["code"],
              codigo.count >= 4,
              codigo.count <= 512,
              codigo.unicodeScalars.allSatisfy({ $0.value >= 0x21 && $0.value <= 0x7e })
        else {
            return .failure(.callbackInvalido)
        }
        return .success(codigo)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
