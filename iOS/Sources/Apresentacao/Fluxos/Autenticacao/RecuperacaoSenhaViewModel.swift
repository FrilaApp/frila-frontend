import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class RecuperacaoSenhaViewModel {
    public enum ResultadoEnvio: Equatable, Sendable {
        case avancarParaCodigo(email: String)
        case estadoNeutro
    }

    private let api: any ApiCliente
    public var email: String
    public var carregando: Bool = false
    public var erro: String?
    public var mensagemNeutra: String?

    /// Garante que um retorno tardio ou cancelado nunca sobrescreva o estado nem avance a navegação
    /// após a pessoa sair da tela ou iniciar outra tentativa.
    private var tentativaAtual: UUID?

    public init(api: any ApiCliente, emailInicial: String = "") {
        self.api = api
        self.email = emailInicial
    }

    public var emailNormalizado: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var emailValido: Bool {
        let limpo = emailNormalizado
        guard limpo.contains("@") else { return false }
        let partes = limpo.split(separator: "@")
        guard partes.count == 2, !partes[0].isEmpty, partes[1].contains(".") else { return false }
        return true
    }

    public func cancelarTentativaAtual() {
        tentativaAtual = nil
        carregando = false
    }

    public func solicitarRecuperacao() async -> ResultadoEnvio? {
        guard !carregando else { return nil }
        let limpo = emailNormalizado
        guard emailValido else {
            erro = String(localized: "Informe um e-mail válido.", bundle: bundleApresentacao)
            mensagemNeutra = nil
            return nil
        }

        // Sem fallback de demonstração na recuperação de senha.
        if DemonstracaoContas.ehEmailDeDemonstracao(limpo) {
            erro = String(localized: "Esta conta entra apenas com código por e-mail.", bundle: bundleApresentacao)
            mensagemNeutra = nil
            return nil
        }

        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil
        mensagemNeutra = nil

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        do {
            try await api.solicitarCodigoDeRecuperacao(email: limpo)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            return .avancarParaCodigo(email: limpo)
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            if Self.indicaIdentidadeInexistenteOuIndisponivel(erroApi) {
                mensagemNeutra = String(
                    localized: "Se existir uma conta ativa com este e-mail, enviaremos um código de 6 dígitos. Confira sua caixa de entrada ou volte para entrar com código.",
                    bundle: bundleApresentacao
                )
                return .estadoNeutro
            }
            erro = MensagemDoErroAPI.texto(erroApi)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível enviar o código. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    /// `shouldCreateUser: false` devolve `otp_disabled` ou `user_not_found` quando o e-mail não
    /// tem identidade OTP ativa (inexistente ou social-only). Nunca esconde 429 (`limiteExcedido`)
    /// nem `semRede`.
    private static func indicaIdentidadeInexistenteOuIndisponivel(_ erroApi: ErroDaApi) -> Bool {
        if erroApi.codigo == .limiteExcedido || erroApi.codigo == .semRede {
            return false
        }
        return erroApi.codigo == .naoEncontrado
            || erroApi.codigoOriginal == "otp_disabled"
            || erroApi.codigoOriginal == "user_not_found"
    }
}
