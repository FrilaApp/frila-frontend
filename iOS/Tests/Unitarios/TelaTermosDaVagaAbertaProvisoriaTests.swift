@testable import FrilaApresentacao
import FrilaDominio
import SwiftUI
import Testing
import UIKit

/// A tela provisória dos termos da vaga já aberta (`409 trabalho_ja_aberto`, contrato 0.2.95): a linha com o valor e
/// os inclusos da vaga, e o tamanho com os dois botões.
@Suite("Tela provisória dos termos da vaga já aberta")
@MainActor
struct TelaTermosDaVagaAbertaProvisoriaTests {
    private let termos = TermosDaVagaAberta(vagaID: UUID(), valor: Dinheiro(centavos: 15_000),
                                           inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false))

    @Test("A linha traz o valor e os inclusos da vaga; o material próprio entra quando a vaga exige")
    func linha() {
        let valor = FormatadorFrila().dinheiro(Dinheiro(centavos: 15_000))
        #expect(TelaTermosDaVagaAbertaProvisoria.linha(termos) == "\(valor), Refeição inclusa, sem transporte")
        let comMaterial = TermosDaVagaAberta(vagaID: termos.vagaID, valor: termos.valor,
                                             inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: true))
        #expect(TelaTermosDaVagaAbertaProvisoria.linha(comMaterial) == "\(valor), Sem refeição nem transporte, Exige material próprio")
    }

    @Test("Desenha dentro da largura com os dois botões de 44 pt, também no tamanho de texto AX5")
    func tamanhos() {
        let tela = TelaTermosDaVagaAbertaProvisoria(termos: termos, confirmar: {}, cancelar: {})
        let normal = UIHostingController(rootView: tela).sizeThatFits(in: CGSize(width: 375, height: 2_000))
        #expect(normal.width <= 375)
        #expect(normal.height >= 88)
        let ax5 = UIHostingController(rootView: tela.environment(\.dynamicTypeSize, .accessibility5))
            .sizeThatFits(in: CGSize(width: 320, height: 4_000))
        #expect(ax5.width <= 320)
        #expect(ax5.height > normal.height)
    }
}
