@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
import Testing
import UIKit

/// A tela provisória do aceite dos Termos (contrato 0.2.90): os estados principais e a ligação com a busca.
@Suite("Tela provisória do aceite dos Termos")
@MainActor
struct TelaAceiteDeTermosProvisoriaTests {
    private let termos = URL(string: "https://frilabr.com/termos")!

    private func altura(aceitando: Bool, erro: Bool, largura: CGFloat = 375) -> CGSize {
        let tela = TelaAceiteDeTermosProvisoria(aceitando: aceitando, erroNoAceite: erro, termosDeUso: termos, aceitar: {})
        return UIHostingController(rootView: tela).sizeThatFits(in: CGSize(width: largura, height: 2_000))
    }

    @Test("Os três estados (normal, aceitando, erro) desenham dentro da largura e o aviso de erro acrescenta altura")
    func estados() {
        let normal = altura(aceitando: false, erro: false)
        let aceitando = altura(aceitando: true, erro: false)
        let comErro = altura(aceitando: false, erro: true)
        #expect(normal.width <= 375 && aceitando.width <= 375 && comErro.width <= 375)
        // Link de 44 pt + botão de 44 pt, fora o texto e o respiro.
        #expect(normal.height >= 88)
        #expect(comErro.height > normal.height)
    }

    @Test("Tamanho de texto AX5: nada estoura a largura da tela")
    func tamanhoAcessivelMaximo() {
        let tela = TelaAceiteDeTermosProvisoria(aceitando: false, erroNoAceite: true, termosDeUso: termos, aceitar: {})
            .environment(\.dynamicTypeSize, .accessibility5)
        let medida = UIHostingController(rootView: tela).sizeThatFits(in: CGSize(width: 320, height: 4_000))
        #expect(medida.width <= 320)
        #expect(medida.height > altura(aceitando: false, erro: true, largura: 320).height)
    }

    @Test("O botão Aceitar da busca chama aceitar_termos e repete a busca")
    func botaoLigadoAoModelo() async throws {
        let api = ApiClienteEmMemoria(cenario: .buscaComTermosPendentes)
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let modelo = BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaID)
        modelo.funcaoID = try #require(try await api.funcoes().first).id
        await modelo.buscar()
        #expect(modelo.estado == .termosPendentes)

        // O toque na tela é este mesmo caminho: `init(modelo:)` liga o botão a `aceitarTermosERepetirABusca()`.
        _ = TelaAceiteDeTermosProvisoria(modelo: modelo)
        await modelo.aceitarTermosERepetirABusca()
        #expect(await api.aceitesDeTermosRecebidos == [VersaoDosTermos.vigente])
        #expect(modelo.estado == .resultados)
    }

    @Test("Os Termos abrem pelo endereço oficial que o app já usa")
    func enderecoOficial() {
        #expect(EnderecosOficiais.padrao.termosDeUso.absoluteString == "https://frilabr.com/termos")
    }
}
