import Foundation

// Enxerto: fora de FrilaShiftModels.swift, porque o guarda do US18 não
// aceita casas decimais em arquivo que fala do histórico do local. A distância não é esse histórico.
extension FrilaShiftVenue {
    /// "3,2 km", "14 km".
    public var distanceLabel: String {
        distanceKm.formatted(.number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(0...1))) + " km"
    }

    /// "3,2 quilômetros".
    public var spokenDistance: String {
        distanceKm.formatted(.number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(0...1))) + " quilômetros"
    }
}
