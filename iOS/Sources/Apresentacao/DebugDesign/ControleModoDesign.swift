#if DEBUG || FRILA_BETA
import Foundation
import Observation
import SwiftUI
import UIKit

/// Chave de tempo de execução do modo de design (painel de variantes). Nasce DESLIGADA. Só liga por
/// ação deliberada: o argumento de lançamento `-FRILA_MODO_DESIGN` (ou `-FRILA_DESIGN`), a chave
/// `frila_modo_design_ativo` no `UserDefaults` ou cinco toques seguidos no selo BETA.
/// Compilada só em Debug e no Beta; no Prod nada disto existe (Scripts/conferir-release.sh reprova).
@Observable @MainActor
public final class ControleModoDesign {
    public static let compartilhado = ControleModoDesign()

    nonisolated static let chaveNoAparelho = "frila_modo_design_ativo"
    nonisolated static let argumentos: [String] = ["-FRILA_MODO_DESIGN", "-FRILA_DESIGN"]

    public private(set) var ativo: Bool
    private let padroes: UserDefaults

    init(argumentos: [String] = ProcessInfo.processInfo.arguments, padroes: UserDefaults = .standard) {
        self.padroes = padroes
        self.ativo = Self.deveComecarLigado(argumentos: argumentos, padroes: padroes)
    }

    /// Argumento de lançamento ou chave guardada no aparelho; sem nenhum dos dois, desligado.
    nonisolated static func deveComecarLigado(argumentos: [String], padroes: UserDefaults) -> Bool {
        if argumentos.contains(where: { Self.argumentos.contains($0) }) { return true }
        return padroes.bool(forKey: chaveNoAparelho)
    }

    /// Alterna o modo e guarda a escolha no aparelho. O háptico confirma a troca sem tela nem texto.
    public func alternar(comHaptico: Bool = true) {
        ativo.toggle()
        padroes.set(ativo, forKey: Self.chaveNoAparelho)
        guard comHaptico else { return }
        let gerador = UIImpactFeedbackGenerator(style: ativo ? .heavy : .light)
        gerador.impactOccurred()
    }
}

@MainActor
private struct ModoDebugDesignSeAtivo: ViewModifier {
    private let controle = ControleModoDesign.compartilhado

    @ViewBuilder
    func body(content: Content) -> some View {
        if controle.ativo {
            content.modoDebugDesign()
        } else {
            content
        }
    }
}

public extension View {
    /// Aplica o painel de design só enquanto o `ControleModoDesign` estiver ligado.
    func modoDebugDesignSeAtivo() -> some View { modifier(ModoDebugDesignSeAtivo()) }
}
#endif
