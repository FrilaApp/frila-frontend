import AuthenticationServices
import Foundation
import FrilaDominio
import UIKit

public struct CredencialAppleNativa: Sendable, Equatable {
    public let idToken: String
    public let email: String?
    public let nome: String?

    public init(idToken: String, email: String? = nil, nome: String? = nil) {
        self.idToken = idToken
        self.email = email
        self.nome = nome
    }
}

/// Porta testável para os fluxos nativos de UI do sistema (Sign in with Apple e ASWebAuthenticationSession).
@MainActor
public protocol ProvedorUIAutenticacaoSocial: AnyObject {
    func solicitarApple(nonceSha256: String) async throws -> CredencialAppleNativa
    func abrirSessaoWebOAuth(url: URL, esquemaCallback: String) async throws -> URL
}

/// Implementação nativa usando `AuthenticationServices` (`ASAuthorizationAppleIDProvider` + `ASWebAuthenticationSession`).
/// Não requer `CFBundleURLTypes` no `Info.plist` (mantém `conferir-release.sh` íntegro) nem SDK de terceiros.
@MainActor
public final class AutenticadorSocialNativo: NSObject, ProvedorUIAutenticacaoSocial {
    private var sessaoWebAtual: ASWebAuthenticationSession?
    private var continuacaoApple: CheckedContinuation<CredencialAppleNativa, Error>?

    public override init() {
        super.init()
    }

    public func solicitarApple(nonceSha256: String) async throws -> CredencialAppleNativa {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceSha256

        return try await withCheckedThrowingContinuation { continuacao in
            self.continuacaoApple = continuacao
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    public func abrirSessaoWebOAuth(url: URL, esquemaCallback: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuacao in
            let sessao = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: esquemaCallback
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.sessaoWebAtual = nil
                    if let error {
                        let nsError = error as NSError
                        if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                        {
                            continuacao.resume(throwing: ErroEntradaSocial.cancelado)
                        } else {
                            continuacao.resume(throwing: ErroEntradaSocial.provedorIndisponivel)
                        }
                        return
                    }
                    guard let callbackURL else {
                        continuacao.resume(throwing: ErroEntradaSocial.callbackInvalido)
                        return
                    }
                    continuacao.resume(returning: callbackURL)
                }
            }
            sessao.presentationContextProvider = self
            sessao.prefersEphemeralWebBrowserSession = false
            self.sessaoWebAtual = sessao
            if !sessao.start() {
                self.sessaoWebAtual = nil
                continuacao.resume(throwing: ErroEntradaSocial.provedorIndisponivel)
            }
        }
    }

    private func janelaAtiva() -> ASPresentationAnchor {
        let cenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for cena in cenas {
            if let janela = cena.windows.first(where: \.isKeyWindow) {
                return janela
            }
        }
        return cenas.first?.windows.first ?? UIWindow()
    }
}

extension AutenticadorSocialNativo: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        janelaAtiva()
    }
}

extension AutenticadorSocialNativo: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        janelaAtiva()
    }
}

extension AutenticadorSocialNativo: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let continuacao = continuacaoApple else { return }
        continuacaoApple = nil

        guard let credencial = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credencial.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty
        else {
            continuacao.resume(throwing: ErroEntradaSocial.callbackInvalido)
            return
        }

        let nomeFormatado = credencial.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) }
        let nomeLimpo = nomeFormatado?.trimmingCharacters(in: .whitespacesAndNewlines)
        continuacao.resume(returning: CredencialAppleNativa(
            idToken: idToken,
            email: credencial.email,
            nome: nomeLimpo?.isEmpty == false ? nomeLimpo : nil
        ))
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        guard let continuacao = continuacaoApple else { return }
        continuacaoApple = nil

        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue
        {
            continuacao.resume(throwing: ErroEntradaSocial.cancelado)
        } else {
            continuacao.resume(throwing: ErroEntradaSocial.provedorIndisponivel)
        }
    }
}
