import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Decodificação Segura de Dinheiro e Coordenada")
struct DecodificacaoValoresDeDominioTests {
    // MARK: - Dinheiro

    @Test("Decodificação válida de Dinheiro preserva valor em centavos")
    func decodificacaoDinheiroValida() throws {
        let json = """
        { "centavos": 15000 }
        """.data(using: .utf8)!

        let valor = try JSONDecoder().decode(Dinheiro.self, from: json)
        #expect(valor.centavos == 15_000)
        #expect(valor == Dinheiro(centavos: 15_000))
    }

    @Test("Decodificação de Dinheiro com centavos zero é aceita")
    func decodificacaoDinheiroZero() throws {
        let json = """
        { "centavos": 0 }
        """.data(using: .utf8)!

        let valor = try JSONDecoder().decode(Dinheiro.self, from: json)
        #expect(valor.centavos == 0)
    }

    @Test("Decodificação de Dinheiro com centavos negativos lança DecodingError", arguments: [
        -1, -50, -12_000, Int.min
    ])
    func decodificacaoDinheiroNegativoRecusada(centavos: Int) {
        let json = """
        { "centavos": \(centavos) }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Dinheiro.self, from: json)
        }
    }

    // MARK: - Coordenada

    @Test("Decodificação válida de Coordenada preserva latitude e longitude")
    func decodificacaoCoordenadaValida() throws {
        let json = """
        { "latitude": -23.5505, "longitude": -46.6333 }
        """.data(using: .utf8)!

        let coord = try JSONDecoder().decode(Coordenada.self, from: json)
        #expect(coord.latitude == -23.5505)
        #expect(coord.longitude == -46.6333)
    }

    @Test("Decodificação de Coordenada com latitude fora de [-90, 90] lança DecodingError", arguments: [
        -90.0001, 90.0001, -120.0, 150.0
    ])
    func decodificacaoLatitudeInvalida(lat: Double) {
        let json = """
        { "latitude": \(lat), "longitude": 0.0 }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Coordenada.self, from: json)
        }
    }

    @Test("Decodificação de Coordenada com longitude fora de [-180, 180] lança DecodingError", arguments: [
        -180.0001, 180.0001, -200.0, 250.0
    ])
    func decodificacaoLongitudeInvalida(lon: Double) {
        let json = """
        { "latitude": 0.0, "longitude": \(lon) }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Coordenada.self, from: json)
        }
    }

    @Test("Criação direta de Coordenada com NaN ou Infinito lança ErroCoordenada")
    func coordenadaNaNInfinitoInit() {
        #expect(throws: ErroCoordenada.latitudeInvalida) {
            try Coordenada(latitude: Double.nan, longitude: 0.0)
        }
        #expect(throws: ErroCoordenada.latitudeInvalida) {
            try Coordenada(latitude: Double.infinity, longitude: 0.0)
        }
        #expect(throws: ErroCoordenada.latitudeInvalida) {
            try Coordenada(latitude: -Double.infinity, longitude: 0.0)
        }
        #expect(throws: ErroCoordenada.longitudeInvalida) {
            try Coordenada(latitude: 0.0, longitude: Double.nan)
        }
        #expect(throws: ErroCoordenada.longitudeInvalida) {
            try Coordenada(latitude: 0.0, longitude: Double.infinity)
        }
        #expect(throws: ErroCoordenada.longitudeInvalida) {
            try Coordenada(latitude: 0.0, longitude: -Double.infinity)
        }
    }

    @Test("Serialização e volta (roundtrip) preserva igualdade de Dinheiro e Coordenada")
    func roundtripCodable() throws {
        let d = Dinheiro(centavos: 35_000)
        let c = try Coordenada(latitude: -15.7942, longitude: -47.8822)

        let encoder = JSONEncoder()
        let dData = try encoder.encode(d)
        let cData = try encoder.encode(c)

        let dDecodificado = try JSONDecoder().decode(Dinheiro.self, from: dData)
        let cDecodificado = try JSONDecoder().decode(Coordenada.self, from: cData)

        #expect(dDecodificado == d)
        #expect(cDecodificado == c)
    }
}
