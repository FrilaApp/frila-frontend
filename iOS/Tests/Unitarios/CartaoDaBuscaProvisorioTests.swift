@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
import Testing
import UIKit

/// O cartão provisório da busca (contrato 0.2.90, CD-B07): foto pequena e circular quando há `foto_url`, senão a inicial.
@Suite("Cartão provisório da busca: foto ou inicial")
@MainActor
struct CartaoDaBuscaProvisorioTests {
    private struct ErroDeRede: Error {}

    private func cartao(nome: String = "Maria S.", fotoURL: URL? = nil) -> CartaoProfissional {
        let funcao = Funcao(id: UUID(), nome: "Garçom", categoria: "Salão")
        return CartaoProfissional(
            id: UUID(), nome: nome,
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcao.id, unidade: .hora, valorCentavos: 3_500)),
            distanciaFaixa: .ate5km,
            reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            fotoURL: fotoURL)
    }

    @Test("Foto com erro (404 ou qualquer outro) mostra a inicial, sem mensagem de erro")
    func fotoComErroViraInicial() {
        guard case .inicial = FotoDoCartaoDaBusca.aparencia(para: .failure(ErroDeRede())) else {
            Issue.record("falha de carregamento deveria mostrar a inicial")
            return
        }
        guard case .inicial = FotoDoCartaoDaBusca.aparencia(para: .failure(URLError(.fileDoesNotExist))) else {
            Issue.record("404 deveria mostrar a inicial")
            return
        }
    }

    @Test("Enquanto a foto carrega, a inicial; carregada, a foto")
    func carregandoECarregada() {
        guard case .inicial = FotoDoCartaoDaBusca.aparencia(para: .empty) else {
            Issue.record("carregando deveria mostrar a inicial")
            return
        }
        guard case .foto = FotoDoCartaoDaBusca.aparencia(para: .success(Image(systemName: "person"))) else {
            Issue.record("foto carregada deveria aparecer")
            return
        }
    }

    @Test("A inicial é a primeira letra do nome em maiúscula, e sem nome é ?")
    func inicial() {
        #expect(FotoDoCartaoDaBusca.inicial(de: "Maria S.") == "M")
        #expect(FotoDoCartaoDaBusca.inicial(de: "  ícaro P.") == "Í")
        #expect(FotoDoCartaoDaBusca.inicial(de: "") == "?")
        #expect(FotoDoCartaoDaBusca.inicial(de: "   ") == "?")
    }

    @Test("Sem foto e com foto (URL que não responde) o cartão tem o mesmo tamanho: círculo de 40 pt, linha de ao menos 44")
    func tamanhoComESemFoto() {
        let limite = CGSize(width: 375, height: 2_000)
        let sem = UIHostingController(rootView: CartaoDaBuscaProvisorio(cartao: cartao())).sizeThatFits(in: limite)
        let com = UIHostingController(rootView: CartaoDaBuscaProvisorio(cartao: cartao(fotoURL: URL(string: "https://invalido.test/foto.jpg")))).sizeThatFits(in: limite)
        #expect(FotoDoCartaoDaBusca.lado == 40)
        #expect(sem.height >= 44)
        #expect(abs(sem.height - com.height) < 1)
        #expect(sem.width <= 375 && com.width <= 375)
    }

    @Test("Com o dublê: o cartão de quem tem foto traz a URL e o de quem não tem vem sem ela")
    func comODuble() async throws {
        let api = ApiClienteEmMemoria(cenario: .buscaDeProfissionais)
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let funcaoID = try #require(try await api.funcoes().first).id
        let pagina = try await api.buscarProfissionais(FiltroBuscaProfissionais(estabelecimentoID: casaID, funcaoID: funcaoID), cursor: nil, limite: 20)
        let maria = try #require(pagina.itens.first { $0.id == ApiClienteEmMemoria.IDsDaBusca.disponivel })
        #expect(maria.fotoURL != nil)
        let semFoto = try #require(pagina.itens.first { $0.id != ApiClienteEmMemoria.IDsDaBusca.disponivel })
        #expect(semFoto.fotoURL == nil)
        // Os dois desenham sem quebrar.
        for item in [maria, semFoto] {
            #expect(UIHostingController(rootView: CartaoDaBuscaProvisorio(cartao: item)).sizeThatFits(in: CGSize(width: 375, height: 2_000)).height >= 44)
        }
    }
}
