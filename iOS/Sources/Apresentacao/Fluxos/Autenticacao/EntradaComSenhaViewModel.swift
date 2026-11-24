import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class EntradaComSenhaViewModel {
    private let api: any ApiCliente
    public var email: String
    public var senha: String = ""
    public var carregando: Bool = false
    public var erro: String?

    /// Identifica a tentativa corrente para que uma chamada cancelada ou atrasada nunca sobrescreva
    /// o estado nem entregue um destino obsoleto para uma tentativa posterior.
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

    public func entrar() async -> DestinoCodigo? {
        guard !carregando else { return nil }
        let limpo = emailNormalizado
        guard emailValido else {
            erro = String(localized: "Informe um e-mail válido.", bundle: bundleApresentacao)
            return nil
        }
        guard !senha.isEmpty else {
            erro = String(localized: "Digite sua senha para entrar.", bundle: bundleApresentacao)
            return nil
        }
        if DemonstracaoContas.ehEmailDeDemonstracao(limpo) {
            erro = String(localized: "Esta conta entra apenas com código por e-mail.", bundle: bundleApresentacao)
            return nil
        }

        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil
        let senhaEnviada = senha

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        do {
            try await api.entrarComSenha(email: limpo, senha: senhaEnviada)
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            tratarErroDeEntrada(erroApi)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }

        guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

        do {
            let destino = try await DestinoDaConta.avaliar(api: api, emailParaCadastro: limpo)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            senha = ""
            switch destino {
            case let .cadastro(emailCad):
                return .cadastro(email: emailCad ?? limpo)
            case .profissional:
                DestinoGuardado.salvar(.profissional)
                return .destino(.profissional)
            case .funcoesEHorarios:
                DestinoGuardado.salvar(.funcoesEHorarios)
                return .destino(.funcoesEHorarios)
            case .contratante:
                DestinoGuardado.salvar(.contratante)
                return .destino(.contratante)
            case let .contaSuspensa(situacao):
                return .destino(.contaSuspensa(situacao))
            }
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = MensagemDoErroAPI.texto(erroApi)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func tratarErroDeEntrada(_ erroApi: ErroDaApi) {
        if erroApi.codigo == .naoAutenticado {
            erro = String(localized: "E-mail ou senha incorretos. Confira os dados ou entre com código.", bundle: bundleApresentacao)
        } else {
            erro = MensagemDoErroAPI.texto(erroApi)
        }
    }
}
