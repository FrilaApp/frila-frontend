import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class EntradaViewModel {
    private let api: any ApiCliente
    public var email: String = ""
    public var carregando: Bool = false
    public var erro: String?

    public init(api: any ApiCliente, emailInicial: String = "") {
        self.api = api
        self.email = emailInicial
    }

    public var emailValido: Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limpo.contains("@") else { return false }
        let partes = limpo.split(separator: "@")
        guard partes.count == 2, !partes[0].isEmpty, partes[1].contains(".") else { return false }
        return true
    }

    public func solicitarCodigo() async -> Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard emailValido else {
            erro = String(localized: "Informe um e-mail válido.", bundle: bundleApresentacao)
            return false
        }
        carregando = true
        erro = nil
        defer { carregando = false }

        // Se for conta de demonstração da revisão da App Store, não chama solicitarCodigo
        // (a revisão não tem caixa de entrada; a autenticação ocorre via entrarDemonstracao na tela seguinte).
        if DemonstracaoContas.ehEmailDeDemonstracao(limpo) {
            return true
        }

        do {
            try await api.solicitarCodigo(email: limpo)
            return true
        } catch let erroApi as ErroDaApi {
            erro = MensagemDoErroAPI.texto(erroApi)
            return false
        } catch {
            erro = String(localized: "Não foi possível enviar o código. Tente novamente.", bundle: bundleApresentacao)
            return false
        }
    }
}
