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
        try Task.checkCancellation()
        // Guarda contra chamadas simultâneas: nunca sobrescreve uma continuation ativa.
        guard continuacaoApple == nil else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceSha256

        let flagCancelada = CancelamentoMainActor()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuacao in
                // Revalida cancelamento no MainActor antes de apresentar: nunca abre sheet de tarefa cancelada.
                if Task.isCancelled || flagCancelada.cancelada {
                    continuacao.resume(throwing: CancellationError())
                    return
                }
                self.continuacaoApple = continuacao
                if Task.isCancelled || flagCancelada.cancelada {
                    self.continuacaoApple = nil
                    continuacao.resume(throwing: CancellationError())
                    return
                }
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                flagCancelada.cancelada = true
                guard let self, let pendente = self.continuacaoApple else { return }
                self.continuacaoApple = nil
                pendente.resume(throwing: CancellationError())
            }
        }
    }

    public func abrirSessaoWebOAuth(url: URL, esquemaCallback: String) async throws -> URL {
        try Task.checkCancellation()
        // Guarda contra chamadas simultâneas: impede sobreposição de sessões OAuth.
        guard sessaoWebAtual == nil else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        let flagCancelada = CancelamentoMainActor()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuacao in
                var encerrada = false
                @MainActor func finalizar(_ resultado: Result<URL, Error>) {
                    guard !encerrada else { return }
                    encerrada = true
                    self.sessaoWebAtual = nil
                    continuacao.resume(with: resultado)
                }

                // Revalida cancelamento no MainActor antes de criar/apresentar ASWebAuthenticationSession.
                if Task.isCancelled || flagCancelada.cancelada {
                    finalizar(.failure(CancellationError()))
                    return
                }

                let sessao = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: esquemaCallback
                ) { callbackURL, error in
                    Task { @MainActor in
                        if let error {
                            let nsError = error as NSError
                            if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                            {
                                finalizar(.failure(ErroEntradaSocial.cancelado))
                            } else {
                                finalizar(.failure(ErroEntradaSocial.provedorIndisponivel))
                            }
                            return
                        }
                        guard let callbackURL else {
                            finalizar(.failure(ErroEntradaSocial.callbackInvalido))
                            return
                        }
                        finalizar(.success(callbackURL))
                    }
                }
                sessao.presentationContextProvider = self
                sessao.prefersEphemeralWebBrowserSession = false
                self.sessaoWebAtual = sessao

                // Segunda checagem após registrar sessaoWebAtual: se cancelada no intervalo, aborta sem abrir sheet.
                if Task.isCancelled || flagCancelada.cancelada {
                    sessao.cancel()
                    finalizar(.failure(CancellationError()))
                    return
                }
                if !sessao.start() {
                    finalizar(.failure(ErroEntradaSocial.provedorIndisponivel))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                flagCancelada.cancelada = true
                self?.sessaoWebAtual?.cancel()
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

@MainActor
private final class CancelamentoMainActor {
    var cancelada = false
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
