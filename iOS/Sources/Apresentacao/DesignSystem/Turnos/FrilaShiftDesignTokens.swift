import SwiftUI

// MARK: - Neutros do protótipo MidFi (Turnos)
//
// Tema neutro decidido para o MidFi: seleção ativa em preenchimento escuro com texto
// branco, CTA primário neutro sólido, superfícies brancas sobre fundo agrupado cinza.
// A terracota fica fora destas telas.

public extension FrilaColor {
    /// Fundo agrupado das telas (Light: #F2F2F0, Dark: #0B0B0A).
    static func dynamicGroupedBackground(isDark: Bool) -> Color {
        isDark ? Color(red: 11/255, green: 11/255, blue: 10/255) : Color(red: 242/255, green: 242/255, blue: 240/255)
    }

    /// Superfície de cards e campos sobre o fundo agrupado (Light: #FFFFFF, Dark: #1C1C1A).
    static func dynamicGroupedSurface(isDark: Bool) -> Color {
        isDark ? Color(red: 28/255, green: 28/255, blue: 26/255) : .white
    }

    /// Preenchimento de seleção ativa e CTA neutro (Light: #111110, Dark: #F5F4F0).
    static func dynamicSelectionFill(isDark: Bool) -> Color {
        isDark ? Color(red: 245/255, green: 244/255, blue: 240/255) : Color(red: 17/255, green: 17/255, blue: 16/255)
    }

    /// Texto sobre a seleção ativa (Light: #FFFFFF, Dark: #111110).
    static func dynamicOnSelection(isDark: Bool) -> Color {
        isDark ? Color(red: 17/255, green: 17/255, blue: 16/255) : .white
    }

    /// Preenchimento de controles secundários, como os botões do contador (Light: #E8E7E3, Dark: #2C2B28).
    static func dynamicControlFill(isDark: Bool) -> Color {
        isDark ? Color(red: 44/255, green: 43/255, blue: 40/255) : Color(red: 232/255, green: 231/255, blue: 227/255)
    }

    /// Vermelho só para ações destrutivas (Light: #D70015, 5,6:1 sobre branco; Dark: #FF6961).
    static func dynamicDestructive(isDark: Bool) -> Color {
        isDark ? Color(red: 255/255, green: 105/255, blue: 97/255) : Color(red: 215/255, green: 0/255, blue: 21/255)
    }

    /// Texto secundário calibrado para o fundo cinza e o branco (Light: #6B6A66, 4,8:1 sobre #F2F2F0;
    /// Dark: #A3A29C, 6,8:1 sobre #1C1C1A).
    static func dynamicSecondaryText(isDark: Bool) -> Color {
        isDark ? Color(red: 163/255, green: 162/255, blue: 156/255) : Color(red: 107/255, green: 106/255, blue: 102/255)
    }
}

public extension FrilaGeometry {
    /// Altura dos campos de formulário contornados.
    static let fieldHeight: CGFloat = 52
    /// Raio dos cards agrupados (lista de vagas, funções, horários).
    static let radiusGroupedCard: CGFloat = 20
    /// Altura visual dos chips de escolha; a área de toque continua 44.
    static let choiceChipHeight: CGFloat = 32
    /// Diâmetro visual dos botões do contador (menos e mais).
    static let stepperButtonSize: CGFloat = 36
    /// Margem lateral das telas de Turnos.
    static let screenGutter: CGFloat = 16
}
