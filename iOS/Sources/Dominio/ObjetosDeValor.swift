import Foundation

public struct Dinheiro: Codable, Hashable, Comparable, Sendable {
    public let centavos: Int

    public init(centavos: Int) {
        precondition(centavos >= 0, "Dinheiro não pode ter centavos negativos")
        self.centavos = centavos
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.centavos < rhs.centavos
    }
}
public enum ErroCoordenada: Error, Equatable, Sendable {
    case latitudeInvalida
    case longitudeInvalida
}

public struct Coordenada: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) throws(ErroCoordenada) {
        guard (-90...90).contains(latitude) else { throw .latitudeInvalida }
        guard (-180...180).contains(longitude) else { throw .longitudeInvalida }
        self.latitude = latitude
        self.longitude = longitude
    }

    public func distancia(emMetrosDe outra: Coordenada) -> Double {
        let raioDaTerra = 6_371_000.0
        let latitude1 = latitude * .pi / 180
        let latitude2 = outra.latitude * .pi / 180
        let deltaLatitude = (outra.latitude - latitude) * .pi / 180
        let deltaLongitude = (outra.longitude - longitude) * .pi / 180
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return raioDaTerra * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

public enum ErroPeriodo: Error, Equatable, Sendable {
    case fimNaoPosteriorAoInicio
}

public struct Periodo: Codable, Hashable, Sendable {
    public let inicio: Date
    public let fim: Date

    public init(inicio: Date, fim: Date) throws(ErroPeriodo) {
        guard fim > inicio else { throw .fimNaoPosteriorAoInicio }
        self.inicio = inicio
        self.fim = fim
    }

    /// Intervalos são semiabertos: um turno que termina quando outro começa não sobrepõe.
    public func sobrepoe(_ outro: Periodo) -> Bool {
        inicio < outro.fim && outro.inicio < fim
    }
}

public enum ErroHoraDoDia: Error, Equatable, Sendable {
    case formatoInvalido
}

public struct HoraDoDia: Codable, Hashable, Comparable, Sendable {
    public let hora: Int
    public let minuto: Int

    public init(hora: Int, minuto: Int) throws(ErroHoraDoDia) {
        guard (0...23).contains(hora), (0...59).contains(minuto) else {
            throw .formatoInvalido
        }
        self.hora = hora
        self.minuto = minuto
    }

    public init(_ valor: String) throws(ErroHoraDoDia) {
        let partes = valor.split(separator: ":", omittingEmptySubsequences: false)
        guard partes.count == 2,
              partes[0].count == 2,
              partes[1].count == 2,
              let hora = Int(partes[0]),
              let minuto = Int(partes[1]) else {
            throw .formatoInvalido
        }
        try self.init(hora: hora, minuto: minuto)
    }

    public var contrato: String {
        String(format: "%02d:%02d", hora, minuto)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.hora, lhs.minuto) < (rhs.hora, rhs.minuto)
    }
}

public struct JanelaDeDisponibilidade: Codable, Hashable, Sendable {
    /// 0 = domingo, conforme o contrato.
    public let diaDaSemana: Int
    public let inicio: HoraDoDia
    public let fim: HoraDoDia

    public init(diaDaSemana: Int, inicio: HoraDoDia, fim: HoraDoDia) {
        precondition((0...6).contains(diaDaSemana))
        self.diaDaSemana = diaDaSemana
        self.inicio = inicio
        self.fim = fim
    }

    public var atravessaMeiaNoite: Bool { fim <= inicio }
}

public protocol Relogio: Sendable {
    var agora: Date { get }
}

public struct RelogioDoSistema: Relogio {
    public init() {}
    public var agora: Date { .now }
}

public struct RelogioFixo: Relogio {
    public let agora: Date
    public init(agora: Date) { self.agora = agora }
}
