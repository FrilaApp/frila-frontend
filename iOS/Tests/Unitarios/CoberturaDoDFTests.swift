import Foundation
import FrilaDominio
import Testing

@Suite("Cobertura do Distrito Federal (A6)")
struct CoberturaDoDFTests {
    @Test("Pontos dentro do DF, sem unidade federativa, não são fora", arguments: [
        (-15.7942, -47.8822), // Plano Piloto
        (-15.8267, -47.9218), // Guará
        (-15.8330, -48.0500), // Taguatinga
        (-16.0000, -47.9500), // Santa Maria, sul do DF
        (-15.6000, -47.6500)  // Planaltina, norte do DF
    ])
    func dentroPorCoordenada(latitude: Double, longitude: Double) {
        #expect(!CoberturaDoDF.estaForaDoDF(latitude: latitude, longitude: longitude))
    }

    @Test("Pontos longe do DF, sem unidade federativa, são fora", arguments: [
        (-16.6869, -49.2648), // Goiânia
        (-23.5505, -46.6333), // São Paulo
        (-12.9714, -38.5014), // Salvador
        (-15.4000, -47.9000), // ao norte do DF
        (-15.8000, -48.5000)  // a oeste do DF
    ])
    func foraPorCoordenada(latitude: Double, longitude: Double) {
        #expect(CoberturaDoDF.estaForaDoDF(latitude: latitude, longitude: longitude))
    }

    @Test("A unidade federativa do geocodificador vale mais que o retângulo", arguments: [
        ("DF", false), ("Distrito Federal", false), ("distrito federal", false), (" Federal District ", false),
        ("GO", true), ("Goiás", true), ("MG", true)
    ])
    func areaManda(area: String, fora: Bool) {
        // Ponto dentro do retângulo, no Entorno: só a unidade federativa separa os dois lados.
        #expect(CoberturaDoDF.estaForaDoDF(latitude: -15.9000, longitude: -48.2800, area: area) == fora)
    }

    @Test("Área vazia cai no retângulo")
    func areaVazia() {
        #expect(!CoberturaDoDF.estaForaDoDF(latitude: -15.7942, longitude: -47.8822, area: "  "))
        #expect(CoberturaDoDF.estaForaDoDF(latitude: -16.6869, longitude: -49.2648, area: ""))
    }

    @Test("País diferente de BR é fora, mesmo com as coordenadas do DF")
    func outroPais() {
        #expect(CoberturaDoDF.estaForaDoDF(latitude: -15.7942, longitude: -47.8822, area: "DF", codigoDoPais: "AR"))
        #expect(!CoberturaDoDF.estaForaDoDF(latitude: -15.7942, longitude: -47.8822, area: "DF", codigoDoPais: "br"))
    }

    @Test("A sobrecarga com Coordenada dá a mesma resposta")
    func comCoordenada() throws {
        let goiania = try Coordenada(latitude: -16.6869, longitude: -49.2648)
        let asaSul = try Coordenada(latitude: -15.8200, longitude: -47.9000)
        #expect(CoberturaDoDF.estaForaDoDF(goiania))
        #expect(!CoberturaDoDF.estaForaDoDF(asaSul))
    }
}
