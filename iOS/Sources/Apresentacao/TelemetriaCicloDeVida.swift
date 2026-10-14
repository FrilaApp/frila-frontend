import SwiftUI

/// Regras de ciclo de vida para emissão de telemetria no app (T-0017, RN15, RNF08).
public enum TelemetriaCicloDeVida {
    /// Determina se a transição entre fases da cena do SwiftUI configura uma abertura real do app.
    /// Deduplica a partida inicial: somente transições estritas onde a fase antiga não era ativa
    /// e a nova se tornou ativa emitem o evento.
    public static func deveRegistrarAbertura(de anterior: ScenePhase, para nova: ScenePhase) -> Bool {
        anterior != .active && nova == .active
    }
}
