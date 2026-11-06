@testable import FrilaApresentacao
import CoreLocation
import SwiftUI
import Testing
import UIKit

@Suite("Mapa com ação (iteração 5)")
@MainActor
struct FrilaMapaComAcaoTests {
    @Test("O bloco mede 132 pt: prévia de 102 e botão de 30, em qualquer largura de iPhone")
    func alturaDoBloco() {
        for largura: CGFloat in [361, 393] {
            let anfitriao = UIHostingController(
                rootView: FrilaMapaComAcao(ponto: CLLocationCoordinate2D(latitude: -15.8267, longitude: -47.9218), abrirMapa: {})
            )
            let medida = anfitriao.sizeThatFits(in: CGSize(width: largura, height: 1000))
            #expect(abs(medida.height - 132) <= 4, "Bloco de \(medida.height) pt (aceitável de 128 a 136)")
        }
        #expect(FrilaMapaComAcao.alturaPrevia == 102)
        #expect(FrilaMapaComAcao.alturaBotao == 30)
        #expect(FrilaMapaComAcao.alvoMinimoToque == 44)
    }

    @Test("O botão abre o Apple Maps na coordenada da vaga, com nome e endereço como rótulo")
    func destinoDoBotao() throws {
        let url = try #require(DestinoDoMapaDaVaga.url(
            nome: "Bistrô Ipê", endereco: "CLS 405, Asa Sul, Brasília - DF", latitude: -15.8267, longitude: -47.9218
        ))
        let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(componentes.host == "maps.apple.com")
        #expect(componentes.queryItems?.first { $0.name == "ll" }?.value == "-15.826700,-47.921800")
        #expect(componentes.queryItems?.first { $0.name == "q" }?.value == "Bistrô Ipê, CLS 405, Asa Sul, Brasília - DF")
    }
}
