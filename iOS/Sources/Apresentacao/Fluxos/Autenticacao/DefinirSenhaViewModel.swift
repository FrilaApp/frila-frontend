import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class DefinirSenhaViewModel {
    public static let tamanhoMinimo = 8

    private let api: any ApiCliente
    private let manterDispositivoAtual: Bool
    public var senha: String = ""
    public var confirmacao: String = ""
    public var carregando: Bool = false
    public var erro: String?
    public var concluido: Bool = false

    private var tentativaAtual: UUID?

    public init(api: any ApiCliente, manterDispositivoAtual: Bool = false) {
        self.api = api
        self.manterDispositivoAtual = manterDispositivoAtual
    }

    public var senhaValidaLocalmente: Bool {
        senha.count >= Self.tamanhoMinimo && senha == confirmacao
    }

    public func salvar() async -> Bool {
        guard !carregando else { return false }
        guard senha.count >= Self.tamanhoMinimo else {
            erro = String(localized: "Use pelo menos 8 caracteres na senha.", bundle: bundleApresentacao)
            return false
        }
        guard senha == confirmacao else {
            erro = String(localized: "As senhas não conferem. Digite a mesma senha nos dois campos.", bundle: bundleApresentacao)
            return false
        }

        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil
        let novaSenha = senha

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        do {
            try await api.definirSenha(novaSenha, manterDispositivoAtual: manterDispositivoAtual)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return false }
            senha = ""
            confirmacao = ""
            concluido = true
            return true
        } catch is CancellationError {
            return false
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return false }
            tratarErro(erroApi)
            return false
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return false }
            erro = String(localized: "Não foi possível salvar a senha agora. Tente novamente.", bundle: bundleApresentacao)
            return false
        }
    }

    private func tratarErro(_ erroApi: ErroDaApi) {
        switch erroApi.codigoOriginal {
        case "weak_password", "senha_fraca":
            erro = String(localized: "Escolha uma senha mais forte, combinando letras e números.", bundle: bundleApresentacao)
        case "same_password", "senha_igual":
            erro = String(localized: "Escolha uma senha diferente da atual.", bundle: bundleApresentacao)
        case "reauthentication_needed", "reautenticacao_necessaria":
            erro = String(localized: "Por segurança, saia e entre novamente com um código enviado ao seu e-mail antes de trocar a senha.", bundle: bundleApresentacao)
        case "dispositivo_nao_verificado":
            erro = String(localized: "Confirme este dispositivo com um código por e-mail antes de continuar.", bundle: bundleApresentacao)
        default:
            erro = MensagemDoErroAPI.texto(erroApi)
        }
    }
}
