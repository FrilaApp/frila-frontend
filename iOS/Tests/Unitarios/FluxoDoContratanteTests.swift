import Foundation
import FrilaDados
import FrilaDominio
import Testing
@testable import FrilaApresentacao

@MainActor
@Suite("Entrada do contratante (#99)")
struct FluxoDoContratanteTests {
    @Test("Sem estabelecimento, busca a conta depois da lista e mantém os dados reais do responsável")
    func semEstabelecimento() async throws {
        let conta = try Self.conta()
        let chamadas = Chamadas()
        let model = FluxoDoContratanteViewModel(meusEstabelecimentos: {
            await chamadas.registrar("estabelecimentos")
            return []
        }, minhaConta: {
            await chamadas.registrar("conta")
            return conta
        })
        #expect(model.estado == .carregando)
        await model.carregar()
        #expect(model.estado == .cadastro(conta))
        #expect(await chamadas.todas == ["estabelecimentos", "conta"])
    }

    @Test("Com estabelecimentos, usa o primeiro na ordem da API e não consulta a conta")
    func comEstabelecimentos() async {
        let primeiro = EstabelecimentoDaConta(id: UUID(), nome: "Primeiro Café", papel: .administrador)
        let segundo = EstabelecimentoDaConta(id: UUID(), nome: "Segundo Café", papel: .administrador)
        let chamadas = Chamadas()
        let model = FluxoDoContratanteViewModel(meusEstabelecimentos: { [primeiro, segundo] }, minhaConta: {
            await chamadas.registrar("conta")
            throw ErroDaApi(codigo: .desconhecido)
        })
        await model.carregar()
        #expect(model.estado == .vagas(primeiro))
        #expect(await chamadas.todas.isEmpty)
    }

    @Test("Falha na lista ou na conta apresenta erro sem abrir o cadastro", arguments: [false, true])
    func falha(naConta: Bool) async {
        let model = FluxoDoContratanteViewModel(meusEstabelecimentos: {
            if naConta { return [] }
            throw ErroDaApi(codigo: .desconhecido)
        }, minhaConta: { throw ErroDaApi(codigo: .desconhecido) })
        await model.carregar()
        #expect(model.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido))))
    }

    @Test("Sem rede na lista ou na conta permite tentar novamente, sem prometer cache", arguments: [false, true])
    func offline(naConta: Bool) async {
        let model = FluxoDoContratanteViewModel(meusEstabelecimentos: {
            if naConta { return [] }
            throw ErroDaApi(codigo: .semRede)
        }, minhaConta: { throw ErroDaApi(codigo: .semRede) })
        await model.carregar()
        #expect(model.estado == .offline)
    }

    @Test("Nova tentativa repete a consulta e recupera o cadastro após a falha")
    func novaTentativa() async throws {
        let conta = try Self.conta()
        let chamadas = Chamadas()
        let model = FluxoDoContratanteViewModel(meusEstabelecimentos: {
            await chamadas.registrar("estabelecimentos")
            if await chamadas.todas.count == 1 { throw ErroDaApi(codigo: .semRede) }
            return []
        }, minhaConta: { conta })
        await model.carregar()
        #expect(model.estado == .offline)
        await model.carregar()
        #expect(model.estado == .cadastro(conta))
        #expect(await chamadas.todas.count == 2)
    }

    @Test("Cliente em memória não inventa estabelecimento para uma conta recém-criada")
    func contaNovaEmMemoria() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let conta = try Self.conta()
        _ = try await api.criarConta(CadastroConta(nome: conta.nome, telefone: conta.telefone,
                                                   nascimento: conta.nascimento, perfil: .contratante,
                                                   versaoTermos: "1"))
        #expect(try await api.meusEstabelecimentos().isEmpty)
        let model = FluxoDoContratanteViewModel(api: api)
        await model.carregar()
        #expect(model.estado == .cadastro(try await api.minhaConta()))
    }

    private static func conta() throws -> Conta {
        Conta(id: UUID(), perfil: .contratante, nome: "Responsável do Café", telefone: "61988887777",
              email: "contratante@frila.app", nascimento: try DataCivil(ano: 1995, mes: 5, dia: 15), estado: .ativa)
    }

    private actor Chamadas {
        var todas: [String] = []
        func registrar(_ chamada: String) { todas.append(chamada) }
    }
}
