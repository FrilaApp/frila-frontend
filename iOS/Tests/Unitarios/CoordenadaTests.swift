import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Coordenadas e Distância Geodésica")
struct CoordenadaTests {
    @Test("Coordenadas nos limites válidos são criadas com sucesso", arguments: [
        (0.0, 0.0),
        (-90.0, -180.0),
        (90.0, 180.0),
        (-23.5505, -46.6333), // São Paulo (Marco Zero da Sé)
        (-15.7942, -47.8822)  // Brasília
    ])
    func coordenadasValidas(lat: Double, lon: Double) throws {
        let coord = try Coordenada(latitude: lat, longitude: lon)
        #expect(coord.latitude == lat)
        #expect(coord.longitude == lon)
    }

    @Test("Latitude fora do intervalo [-90, 90] lança ErroCoordenada.latitudeInvalida", arguments: [
        -90.0001, 90.0001, -91.0, 91.0, -120.0, 150.0
    ])
    func latitudeInvalida(lat: Double) {
        #expect(throws: ErroCoordenada.latitudeInvalida) {
            try Coordenada(latitude: lat, longitude: 0.0)
        }
    }

    @Test("Longitude fora do intervalo [-180, 180] lança ErroCoordenada.longitudeInvalida", arguments: [
        -180.0001, 180.0001, -181.0, 181.0, -200.0, 250.0
    ])
    func longitudeInvalida(lon: Double) {
        #expect(throws: ErroCoordenada.longitudeInvalida) {
            try Coordenada(latitude: 0.0, longitude: lon)
        }
    }

    @Test("Distância de um ponto para ele mesmo é exatamente zero metros")
    func distanciaPontoIdentico() throws {
        let ponto = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let distancia = ponto.distancia(emMetrosDe: ponto)
        #expect(distancia == 0.0)
    }

    @Test("Distância geodésica é estritamente simétrica: d(A, B) == d(B, A)")
    func simetriaDaDistancia() throws {
        let se = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let ibirapuera = try Coordenada(latitude: -23.5857, longitude: -46.6573)

        let ida = se.distancia(emMetrosDe: ibirapuera)
        let volta = ibirapuera.distancia(emMetrosDe: se)

        #expect(abs(ida - volta) < 0.0001)
        #expect(ida > 4_000 && ida < 5_000) // ~4,5 km em linha reta
    }

    @Test("Detecção de proximidade crítica no limiar de 200 metros da presença (RN22)")
    func limiarDePresenca200Metros() throws {
        let base = try Coordenada(latitude: -23.550000, longitude: -46.633300)
        // Deslocamento de ~100 metros ao norte
        let dentroDoRaio = try Coordenada(latitude: -23.550900, longitude: -46.633300)
        // Deslocamento de ~500 metros ao norte
        let foraDoRaio = try Coordenada(latitude: -23.554500, longitude: -46.633300)

        let distanciaDentro = base.distancia(emMetrosDe: dentroDoRaio)
        let distanciaFora = base.distancia(emMetrosDe: foraDoRaio)

        #expect(distanciaDentro <= Double(RegraDePresenca.distanciaMaximaDoCheckinMetros))
        #expect(distanciaFora > Double(RegraDePresenca.distanciaMaximaDoCheckinMetros))
    }

    @Test("Codificação e decodificação JSON estruturada (Codable)")
    func serializacaoJSON() throws {
        let original = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decodificado = try decoder.decode(Coordenada.self, from: data)

        #expect(decodificado == original)
        #expect(decodificado.latitude == -23.5505)
        #expect(decodificado.longitude == -46.6333)
    }

    @Test("Hashable e unicidade em coleções (Set e Dictionary)")
    func hashableESets() throws {
        let c1 = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let c2 = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let c3 = try Coordenada(latitude: -23.5614, longitude: -46.6559)

        let set: Set<Coordenada> = [c1, c2, c3]
        #expect(set.count == 2)
        #expect(set.contains(c1))
        #expect(set.contains(c3))
    }
}
