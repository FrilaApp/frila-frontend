import Foundation
import FrilaDominio
import Testing

@Suite("Regras e Tipos de Presença e Localização")
struct RegraDePresencaTests {
    @Test("Constantes normativas de presença para check-in geolocalizado (RF13, RN22)")
    func constantesDePresenca() {
        #expect(RegraDePresenca.distanciaMaximaDoCheckinMetros == 200, "distância máxima para check-in geolocalizado é 200 metros (RN22)")
        #expect(RegraDePresenca.precisaoHorizontalMaximaMetros == 100.0, "precisão horizontal máxima aceita é 100 metros")
        #expect(RegraDePresenca.tempoLimiteDaLeitura == .seconds(10), "tempo limite de leitura do GPS é 10 segundos")
        #expect(RegraDePresenca.chaveDaPrecisaoTemporaria == "CheckIn", "chave para precisão temporária é CheckIn")
    }

    @Test("LeituraDeLocalizacao preserva coordenadas e precisão horizontal")
    func leituraDeLocalizacao() throws {
        let coord1 = try Coordenada(latitude: -15.7942, longitude: -47.8822)
        let coord2 = try Coordenada(latitude: -15.7942, longitude: -47.8822)
        let coordDiferente = try Coordenada(latitude: -15.8000, longitude: -47.8900)

        let leitura1 = LeituraDeLocalizacao(coordenada: coord1, precisaoHorizontalMetros: 15.5)
        let leitura2 = LeituraDeLocalizacao(coordenada: coord2, precisaoHorizontalMetros: 15.5)
        let leituraPrecisaoDiferente = LeituraDeLocalizacao(coordenada: coord1, precisaoHorizontalMetros: 25.0)
        let leituraCoordDiferente = LeituraDeLocalizacao(coordenada: coordDiferente, precisaoHorizontalMetros: 15.5)

        #expect(leitura1 == leitura2)
        #expect(leitura1 != leituraPrecisaoDiferente)
        #expect(leitura1 != leituraCoordDiferente)
        #expect(leitura1.coordenada.latitude == -15.7942)
        #expect(leitura1.coordenada.longitude == -47.8822)
        #expect(leitura1.precisaoHorizontalMetros == 15.5)
    }
}
