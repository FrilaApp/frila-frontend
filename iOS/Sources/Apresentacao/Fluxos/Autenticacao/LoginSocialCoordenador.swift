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

/// Abstração mínima de sessão web OAuth para permitir testes determinísticos de timeout e cancelamento sem callback.
@MainActor
public protocol SessaoWebOAuthControlavel: AnyObject {
    func start() -> Bool
    func cancel()
}

extension ASWebAuthenticationSession: SessaoWebOAuthControlavel {}

/// Implementação nativa usando `AuthenticationServices` (`ASAuthorizationAppleIDProvider` + `ASWebAuthenticationSession`).
/// Não requer `CFBundleURLTypes` no `Info.plist` (mantém `conferir-release.sh` íntegro) nem SDK de terceiros.
@MainActor
public final class AutenticadorSocialNativo: NSObject, ProvedorUIAutenticacaoSocial {
    public typealias ExecutorApple = @MainActor (ASAuthorizationAppleIDRequest, AutenticadorSocialNativo) -> Void
    public typealias ExecutorWeb = @MainActor (
        URL,
        String,
        AutenticadorSocialNativo,
        @escaping @Sendable (URL?, Error?) -> Void
    ) -> any SessaoWebOAuthControlavel

    private let prazoSistema: Duration
    private let provedorJanela: @MainActor () -> ASPresentationAnchor?
    private let executorApple: ExecutorApple
    private let executorWeb: ExecutorWeb

    private var tentativaAppleAtual: UUID?
    private var continuacaoApple: CheckedContinuation<CredencialAppleNativa, Error>?
    private var controllerAppleAtual: ASAuthorizationController?
    private var tarefaTimeoutApple: Task<Void, Never>?

    private var tentativaWebAtual: UUID?
    private var continuacaoWeb: CheckedContinuation<URL, Error>?
    private var sessaoWebAtual: (any SessaoWebOAuthControlavel)?
    private var tarefaTimeoutWeb: Task<Void, Never>?

    private weak var janelaDaTentativa: ASPresentationAnchor?

    public init(
        prazoSistema: Duration = .seconds(120),
        provedorJanela: (@MainActor () -> ASPresentationAnchor?)? = nil,
        executorApple: ExecutorApple? = nil,
        executorWeb: ExecutorWeb? = nil
    ) {
        self.prazoSistema = prazoSistema
        self.provedorJanela = provedorJanela ?? { Self.buscarJanelaEmCenaAtiva() }
        self.executorApple = executorApple ?? { request, coordenador in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordenador
            controller.presentationContextProvider = coordenador
            coordenador.registrarControllerApple(controller)
            controller.performRequests()
        }
        self.executorWeb = executorWeb ?? { url, esquema, coordenador, conclusao in
            let sessao = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: esquema,
                completionHandler: conclusao
            )
            sessao.presentationContextProvider = coordenador
            sessao.prefersEphemeralWebBrowserSession = false
            return sessao
        }
        super.init()
    }

    func registrarControllerApple(_ controller: ASAuthorizationController) {
        controllerAppleAtual = controller
    }

    public func solicitarApple(nonceSha256: String) async throws -> CredencialAppleNativa {
        try Task.checkCancellation()
        // Guarda contra chamadas simultâneas: nunca sobrescreve uma continuation ativa.
        guard continuacaoApple == nil else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        guard let janela = provedorJanela() else {
            throw ErroEntradaSocial.provedorIndisponivel
        }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceSha256

        let tentativa = UUID()
        let flagCancelada = CancelamentoMainActor()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuacao in
                // Revalida cancelamento no MainActor antes de apresentar: nunca abre sheet de tarefa cancelada.
                if Task.isCancelled || flagCancelada.cancelada {
                    continuacao.resume(throwing: CancellationError())
                    return
                }
                self.tentativaAppleAtual = tentativa
                self.continuacaoApple = continuacao
                self.janelaDaTentativa = janela
                self.tarefaTimeoutApple = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: self?.prazoSistema ?? .seconds(120))
                    guard !Task.isCancelled else { return }
                    self?.finalizarApple(
                        tentativa: tentativa,
                        resultado: .failure(ErroEntradaSocial.provedorIndisponivel)
                    )
                }

                if Task.isCancelled || flagCancelada.cancelada {
                    self.finalizarApple(tentativa: tentativa, resultado: .failure(CancellationError()))
                    return
                }
                self.executorApple(request, self)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                flagCancelada.cancelada = true
                self?.finalizarApple(tentativa: tentativa, resultado: .failure(CancellationError()))
            }
        }
    }

    public func abrirSessaoWebOAuth(url: URL, esquemaCallback: String) async throws -> URL {
        try Task.checkCancellation()
        // Guarda contra chamadas simultâneas: impede sobreposição de sessões OAuth.
        guard sessaoWebAtual == nil, continuacaoWeb == nil else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        guard let janela = provedorJanela() else {
            throw ErroEntradaSocial.provedorIndisponivel
        }

        let tentativa = UUID()
        let flagCancelada = CancelamentoMainActor()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuacao in
                // Revalida cancelamento no MainActor antes de criar/apresentar ASWebAuthenticationSession.
                if Task.isCancelled || flagCancelada.cancelada {
                    continuacao.resume(throwing: CancellationError())
                    return
                }

                self.tentativaWebAtual = tentativa
                self.continuacaoWeb = continuacao
                self.janelaDaTentativa = janela

                let sessao = self.executorWeb(url, esquemaCallback, self) { [weak self] callbackURL, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let error {
                            let nsError = error as NSError
                            if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                            {
                                self.finalizarWeb(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.cancelado))
                            } else {
                                self.finalizarWeb(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.provedorIndisponivel))
                            }
                            return
                        }
                        guard let callbackURL else {
                            self.finalizarWeb(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.callbackInvalido))
                            return
                        }
                        self.finalizarWeb(tentativa: tentativa, resultado: .success(callbackURL))
                    }
                }
                self.sessaoWebAtual = sessao
                self.tarefaTimeoutWeb = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: self?.prazoSistema ?? .seconds(120))
                    guard !Task.isCancelled else { return }
                    self?.finalizarWeb(
                        tentativa: tentativa,
                        resultado: .failure(ErroEntradaSocial.provedorIndisponivel)
                    )
                }

                // Segunda checagem após registrar sessaoWebAtual: se cancelada no intervalo, aborta sem abrir sheet.
                if Task.isCancelled || flagCancelada.cancelada {
                    self.finalizarWeb(tentativa: tentativa, resultado: .failure(CancellationError()))
                    return
                }
                if !sessao.start() {
                    self.finalizarWeb(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.provedorIndisponivel))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                flagCancelada.cancelada = true
                self?.finalizarWeb(tentativa: tentativa, resultado: .failure(CancellationError()))
            }
        }
    }

    private func finalizarApple(tentativa: UUID, resultado: Result<CredencialAppleNativa, Error>) {
        guard tentativaAppleAtual == tentativa, let continuacao = continuacaoApple else { return }
        tentativaAppleAtual = nil
        continuacaoApple = nil
        controllerAppleAtual = nil
        tarefaTimeoutApple?.cancel()
        tarefaTimeoutApple = nil
        if continuacaoWeb == nil {
            janelaDaTentativa = nil
        }
        continuacao.resume(with: resultado)
    }

    private func finalizarWeb(tentativa: UUID, resultado: Result<URL, Error>) {
        guard tentativaWebAtual == tentativa, let continuacao = continuacaoWeb else { return }
        let sessao = sessaoWebAtual
        tentativaWebAtual = nil
        continuacaoWeb = nil
        sessaoWebAtual = nil
        tarefaTimeoutWeb?.cancel()
        tarefaTimeoutWeb = nil
        if continuacaoApple == nil {
            janelaDaTentativa = nil
        }
        if case .failure = resultado {
            sessao?.cancel()
        }
        continuacao.resume(with: resultado)
    }

    private static func buscarJanelaEmCenaAtiva() -> ASPresentationAnchor? {
        let cenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let ativa = cenas.first(where: { $0.activationState == .foregroundActive }) {
            if let janela = ativa.windows.first(where: \.isKeyWindow) ?? ativa.windows.first {
                return janela
            }
        }
        for cena in cenas {
            if let janela = cena.windows.first(where: \.isKeyWindow) ?? cena.windows.first {
                return janela
            }
        }
        return nil
    }

    private func janelaParaApresentacao() -> ASPresentationAnchor {
        if let janela = janelaDaTentativa ?? provedorJanela() {
            return janela
        }
        preconditionFailure("AutenticadorSocialNativo apresentou fluxo sem UIWindowScene ativa")
    }
}

@MainActor
private final class CancelamentoMainActor {
    var cancelada = false
}

extension AutenticadorSocialNativo: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        janelaParaApresentacao()
    }
}

extension AutenticadorSocialNativo: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        janelaParaApresentacao()
    }
}

extension AutenticadorSocialNativo: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let tentativa = tentativaAppleAtual,
              controllerAppleAtual == nil || controllerAppleAtual === controller
        else { return }

        guard let credencial = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credencial.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty
        else {
            finalizarApple(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.callbackInvalido))
            return
        }

        let nomeFormatado = credencial.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) }
        let nomeLimpo = nomeFormatado?.trimmingCharacters(in: .whitespacesAndNewlines)
        finalizarApple(
            tentativa: tentativa,
            resultado: .success(CredencialAppleNativa(
                idToken: idToken,
                email: credencial.email,
                nome: nomeLimpo?.isEmpty == false ? nomeLimpo : nil
            ))
        )
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        guard let tentativa = tentativaAppleAtual,
              controllerAppleAtual == nil || controllerAppleAtual === controller
        else { return }

        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue
        {
            finalizarApple(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.cancelado))
        } else {
            finalizarApple(tentativa: tentativa, resultado: .failure(ErroEntradaSocial.provedorIndisponivel))
        }
    }
}
