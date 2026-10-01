import Foundation

/// Tipo de destino avaliado para a conta, persistido localmente sem dados pessoais.
public enum TipoDestinoConta: String, Codable, Equatable, Sendable {
    case profissional
    case funcoesEHorarios = "funcoes_e_horarios"
    case contratante
}

/// Guarda o último destino avaliado para permitir recuperação offline (#111 e #109).
/// Não armazena nenhum dado pessoal (apenas o tipo de tela inicial).
/// Limpo na saída da conta por `SaidaDaConta`.
public enum DestinoGuardado {
    public static let chave = "frila_ultimo_destino_conta"

    public static func salvar(_ tipo: TipoDestinoConta, em defaults: UserDefaults = .standard) {
        defaults.set(tipo.rawValue, forKey: chave)
    }

    public static func obter(de defaults: UserDefaults = .standard) -> TipoDestinoConta? {
        guard let raw = defaults.string(forKey: chave) else { return nil }
        return TipoDestinoConta(rawValue: raw)
    }

    public static func limpar(em defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: chave)
    }
}
