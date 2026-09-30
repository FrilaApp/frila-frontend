import Foundation
import FrilaDominio

public enum DestinoAposEntrada: Equatable, Sendable {
    case profissional(Conta)
    case funcoesEHorarios(Conta)
    case contratante(Conta)
}

public enum DemonstracaoContas {
    public static func ehEmailDeDemonstracao(_ email: String) -> Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (limpo.hasPrefix("revisao") && limpo.hasSuffix("@frila.app")) || limpo == "demo@example.com"
    }
}
