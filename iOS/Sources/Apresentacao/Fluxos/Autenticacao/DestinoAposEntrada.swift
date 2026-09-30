import Foundation
import FrilaDominio

public enum DestinoAposEntrada: Equatable, Sendable {
    case profissional(Conta)
    case funcoesEHorarios(Conta)
    case contratante(Conta)
}

public enum DestinoDaConta: Equatable, Sendable {
    case cadastro(email: String?)
    case profissional(Conta)
    case funcoesEHorarios(Conta)
    case contratante(Conta)

    public static func avaliar(api: any ApiCliente, emailParaCadastro: String? = nil) async throws -> DestinoDaConta {
        let conta: Conta
        do {
            conta = try await api.minhaConta()
        } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
            return .cadastro(email: emailParaCadastro)
        }

        switch conta.perfil {
        case .profissional:
            do {
                _ = try await api.meuPerfilProfissional()
                return .profissional(conta)
            } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
                return .funcoesEHorarios(conta)
            }
        case .contratante:
            return .contratante(conta)
        }
    }
}

public enum DemonstracaoContas {
    public static func ehEmailDeDemonstracao(_ email: String) -> Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return limpo == "revisao-profissional@frila.app" || limpo == "revisao-contratante@frila.app"
    }
}
