import Foundation
import FrilaDominio

public enum DestinoAposEntrada: Equatable, Sendable {
    case profissional
    case funcoesEHorarios
    case contratante
}

public enum DestinoDaConta: Equatable, Sendable {
    case cadastro(email: String?)
    case profissional
    case funcoesEHorarios
    case contratante

    public var tipoGuardavel: TipoDestinoConta? {
        switch self {
        case .profissional: return .profissional
        case .funcoesEHorarios: return .funcoesEHorarios
        case .contratante: return .contratante
        case .cadastro: return nil
        }
    }

    public init(tipo: TipoDestinoConta) {
        switch tipo {
        case .profissional: self = .profissional
        case .funcoesEHorarios: self = .funcoesEHorarios
        case .contratante: self = .contratante
        }
    }

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
                return .profissional
            } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
                return .funcoesEHorarios
            }
        case .contratante:
            return .contratante
        }
    }

    public static func avaliarComRecuperacaoOffline(api: any ApiCliente) async throws -> DestinoDaConta {
        do {
            let destino = try await avaliar(api: api)
            if let tipo = destino.tipoGuardavel {
                DestinoGuardado.salvar(tipo)
            } else {
                DestinoGuardado.limpar()
            }
            return destino
        } catch let erroApi as ErroDaApi where erroApi.codigo == .semRede {
            if let guardado = DestinoGuardado.obter() {
                return DestinoDaConta(tipo: guardado)
            }
            throw erroApi
        }
    }
}

public enum DemonstracaoContas {
    public static func ehEmailDeDemonstracao(_ email: String) -> Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return limpo == "revisao-profissional@frila.app" || limpo == "revisao-contratante@frila.app"
    }
}
