@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// O dublê em memória faz o papel do servidor da equipe da casa (0.2.73 e 0.2.103): só o administrador lê a lista e age, o convite
/// é de uso único, e os modelos de tela rodam contra ele de ponta a ponta. É o que os testes de interface usam.
@MainActor
@Suite("Equipe da casa contra o dublê em memória")
struct EquipeDaCasaEmMemoriaTests {
    private let bistro = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let token = ApiClienteEmMemoria.tokenDeConviteDeExemplo

    private func administradora() -> ApiClienteEmMemoria { ApiClienteEmMemoria(cenario: .equipeDaCasa) }

    // MARK: Servidor

    @Test("A lista vem do servidor: os administradores primeiro e, em cada papel, do mais antigo ao mais novo; só um é \"você\"")
    func lista() async throws {
        let membros = try await administradora().membrosDaCasa(estabelecimentoID: bistro)

        #expect(membros.map(\.nome).count == 4)
        #expect(membros.map(\.papel) == [.administrador, .administrador, .operador, .operador])
        #expect(membros.map(\.id) == [ApiClienteEmMemoria.membroDaContaID, ApiClienteEmMemoria.membroRenataID,
                                       ApiClienteEmMemoria.membroMarinaID, ApiClienteEmMemoria.membroPauloID])
        #expect(membros.filter(\.eVoce).count == 1)
        #expect(membros.first?.eVoce == true)
    }

    @Test("Operador da casa, casa de outra conta, casa que não existe e conta de profissional recebem o mesmo 403 sem details")
    func soOAdministrador() async throws {
        let operadora = ApiClienteEmMemoria(cenario: .equipeDaCasaOperador)
        let profissional = ApiClienteEmMemoria(cenario: .sucesso)
        let casasSemPermissao: [(ApiClienteEmMemoria, UUID)] = [
            (operadora, bistro),
            (administradora(), ApiClienteEmMemoria.cantinaDaEsquinaID), // é só operadora na Cantina
            (administradora(), UUID()),
            (profissional, bistro),
        ]
        for (api, casa) in casasSemPermissao {
            let leitura = await #expect(throws: ErroDaApi.self) { _ = try await api.membrosDaCasa(estabelecimentoID: casa) }
            #expect(leitura?.recusaDeAdministrador == true)
            #expect(leitura?.detalhes == nil)

            let convite = await #expect(throws: ErroDaApi.self) {
                _ = try await api.convidarMembro(estabelecimentoID: casa, email: "alguem@exemplo.com", papel: .operador)
            }
            #expect(convite?.recusaDeAdministrador == true)

            let remocao = await #expect(throws: ErroDaApi.self) {
                try await api.removerMembro(estabelecimentoID: casa, membroID: ApiClienteEmMemoria.membroMarinaID)
            }
            #expect(remocao?.recusaDeAdministrador == true)

            let promocao = await #expect(throws: ErroDaApi.self) {
                try await api.transferirAdministracao(estabelecimentoID: casa, novoAdministradorID: ApiClienteEmMemoria.membroMarinaID)
            }
            #expect(promocao?.recusaDeAdministrador == true)
        }
        #expect(await operadora.membrosRemovidos.isEmpty)
        #expect(await operadora.administracoesTransferidas.isEmpty)
        #expect(await operadora.convitesGerados.isEmpty)
    }

    @Test("Conta suspensa recebe 403 com conta_suspensa, que não é a recusa de administrador")
    func contaSuspensa() async {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.membrosDaCasa(estabelecimentoID: UUID()) }
        #expect(erro?.contaSuspensa == true)
        #expect(erro?.recusaDeAdministrador == false)
    }

    @Test("Remover tira a pessoa da lista, e o último administrador não sai (422 ultimo_administrador)")
    func remover() async throws {
        let api = administradora()

        try await api.removerMembro(estabelecimentoID: bistro, membroID: ApiClienteEmMemoria.membroMarinaID)
        try await api.removerMembro(estabelecimentoID: bistro, membroID: ApiClienteEmMemoria.membroRenataID)
        let restantes = try await api.membrosDaCasa(estabelecimentoID: bistro)
        #expect(restantes.map(\.id) == [ApiClienteEmMemoria.membroDaContaID, ApiClienteEmMemoria.membroPauloID])

        let ultimo = await #expect(throws: ErroDaApi.self) {
            try await api.removerMembro(estabelecimentoID: bistro, membroID: ApiClienteEmMemoria.membroDaContaID)
        }
        #expect(ultimo?.ultimoAdministrador == true)

        let ausente = await #expect(throws: ErroDaApi.self) {
            try await api.removerMembro(estabelecimentoID: bistro, membroID: ApiClienteEmMemoria.membroMarinaID)
        }
        #expect(ausente?.codigo == .naoEncontrado)
        #expect(await api.membrosRemovidos == [ApiClienteEmMemoria.membroMarinaID, ApiClienteEmMemoria.membroRenataID])
    }

    @Test("Tornar administrador promove o operador, e quem não é da casa é nao_encontrado")
    func transferir() async throws {
        let api = administradora()

        try await api.transferirAdministracao(estabelecimentoID: bistro, novoAdministradorID: ApiClienteEmMemoria.membroMarinaID)
        let membros = try await api.membrosDaCasa(estabelecimentoID: bistro)
        #expect(membros.first { $0.id == ApiClienteEmMemoria.membroMarinaID }?.papel == .administrador)

        let ausente = await #expect(throws: ErroDaApi.self) {
            try await api.transferirAdministracao(estabelecimentoID: bistro, novoAdministradorID: UUID())
        }
        #expect(ausente?.codigo == .naoEncontrado)
    }

    @Test("O convite de exemplo entra uma vez só: a casa passa a ser da conta como operadora, e repetir é convite_invalido")
    func aceitarUmaVez() async throws {
        let api = administradora()
        #expect(try await api.meusEstabelecimentos().count == 2)

        let membro = try await api.aceitarConviteDeMembro(token: token)

        #expect(membro.estabelecimentoID == ApiClienteEmMemoria.padariaDoBairroID)
        #expect(membro.papel == .operador)
        let casas = try await api.meusEstabelecimentos()
        #expect(casas.count == 3)
        #expect(casas.first { $0.id == ApiClienteEmMemoria.padariaDoBairroID }?.papel == .operador)
        let repetido = await #expect(throws: ErroDaApi.self) { _ = try await api.aceitarConviteDeMembro(token: token) }
        #expect(repetido?.conviteInvalido == true)
    }

    @Test("Token que o servidor não conhece é convite_invalido, e a conta de profissional recebe perfil_incompativel")
    func recusasDoAceite() async {
        let desconhecido = await #expect(throws: ErroDaApi.self) {
            _ = try await administradora().aceitarConviteDeMembro(token: String(repeating: "ab", count: 32))
        }
        #expect(desconhecido?.conviteInvalido == true)

        let profissional = await #expect(throws: ErroDaApi.self) {
            _ = try await ApiClienteEmMemoria(cenario: .sucesso).aceitarConviteDeMembro(token: String(repeating: "ef", count: 32))
        }
        #expect(profissional?.codigo == .perfilIncompativel)
    }

    @Test("Convite gerado: 7 dias, token de 64 hexadecimais e e-mail conferido pelo servidor")
    func convidar() async throws {
        let api = administradora()

        let convite = try await api.convidarMembro(estabelecimentoID: bistro, email: " nova@exemplo.com ", papel: .administrador)

        #expect(ConviteDaCasa.ehCodigo(convite.token))
        #expect(convite.token == convite.token.lowercased())
        #expect(await api.convitesGerados.map(\.email) == ["nova@exemplo.com"])
        #expect(await api.convitesGerados.map(\.papel) == [.administrador])
        let vence = try #require(convite.expiraEm)
        #expect(abs(vence.timeIntervalSinceNow - 7 * 24 * 60 * 60) < 60)

        let invalido = await #expect(throws: ErroDaApi.self) {
            _ = try await api.convidarMembro(estabelecimentoID: bistro, email: "sem-arroba", papel: .operador)
        }
        #expect(invalido?.codigo == .campoInvalido)
        #expect(invalido?.detalhes == "email")
    }

    // MARK: Modelos de tela contra o dublê

    @Test("De ponta a ponta: o administrador gera o convite, o link usa a origem do ambiente e volta aceito pelo \"Tenho um convite\"")
    func deSegundaAAceite() async throws {
        let api = administradora()
        let equipe = EquipeDaCasaViewModel(api: api, estabelecimentoID: bistro, nomeDaCasa: "Bistrô", papel: .administrador, origemDaWeb: OrigemDaWeb.producao)
        await equipe.carregar()
        equipe.email = "convidada@exemplo.com"
        await equipe.gerarConvite()
        let link = try #require(equipe.convite?.link)
        #expect(link.hasPrefix("https://frilabr.com/app/convite#"))
        #expect(ConviteDaCasa.extrairToken(de: link, origens: [OrigemDaWeb.producao]) != nil)

        // A convidada abre o link na conta dela: o dublê tem uma conta só, que já é da casa, então o convite não vale ali. O que
        // importa é que o link inteiro chegou ao servidor como o token, em minúsculas e sem o resto.
        let tela = TenhoUmConviteViewModel(api: api)
        tela.texto = link
        await tela.aceitarConvite()
        let recebidos = await api.tokensRecebidosNoAceite
        #expect(recebidos == [try #require(ConviteDaCasa.extrairToken(de: link, origens: [OrigemDaWeb.producao]))])
        #expect(tela.erro == TextosDaEquipeDaCasa.conviteInvalido)
    }

    @Test("\"Tenho um convite\" com o link do convite de exemplo entra na casa; texto inválido nunca chega ao dublê")
    func tenhoUmConvite() async {
        let api = administradora()
        let tela = TenhoUmConviteViewModel(api: api)

        for invalido in ["", "oi", "zz\(token)zz", token + token, "https://frilabr.com/app/convite#\(token)zz", "https://exemplo.test/app/convite#\(token)"] {
            tela.texto = invalido
            await tela.aceitarConvite()
            #expect(tela.erro == TextosDaEquipeDaCasa.conviteFormatoInvalido)
        }
        #expect(await api.tokensRecebidosNoAceite.isEmpty)

        tela.texto = "Entre pela casa: \(OrigemDaWeb.dev)/convite#\(token.uppercased()) até logo"
        await tela.aceitarConvite()

        #expect(tela.aceito == ConviteAceito(estabelecimentoID: ApiClienteEmMemoria.padariaDoBairroID, papel: .operador))
        #expect(await api.tokensRecebidosNoAceite == [token])
    }

    @Test("A equipe do operador não pede a lista: o dublê vê zero leituras, e a tela só diz que é do administrador")
    func operadorNaoPedeALista() async {
        let api = ApiClienteEmMemoria(cenario: .equipeDaCasaOperador)
        let equipe = EquipeDaCasaViewModel(api: api, estabelecimentoID: bistro, nomeDaCasa: "Bistrô", papel: .operador)

        await equipe.carregar()

        #expect(equipe.lista == .soAdministrador)
        #expect(await api.chamadasAMembrosDaCasa == 0)
    }

    @Test("Quem perdeu a administração no servidor (a conta virou operadora) vê o 403 na lista e fica sem ações")
    func papelVelhoNaTela() async {
        // A tela abriu com o papel de administradora, mas o servidor já a tem como operadora.
        let api = ApiClienteEmMemoria(cenario: .equipeDaCasaOperador)
        let equipe = EquipeDaCasaViewModel(api: api, estabelecimentoID: bistro, nomeDaCasa: "Bistrô", papel: .administrador)

        await equipe.carregar()

        #expect(equipe.lista == .soAdministrador)
        #expect(!equipe.podeGerenciar)
        equipe.email = "alguem@exemplo.com"
        await equipe.gerarConvite()
        #expect(await api.convitesGerados.isEmpty)
    }

    @Test("Trocar de casa contra o dublê: a lista tem as duas casas, com o papel certo em cada uma")
    func trocarDeCasaNoDuble() async {
        let api = administradora()
        let tela = TrocarDeCasaViewModel(api: api)

        await tela.carregar()

        guard case let .conteudo(casas) = tela.estado else {
            Issue.record("a lista de casas devia carregar")
            return
        }
        #expect(casas.map(\.id) == [bistro, ApiClienteEmMemoria.cantinaDaEsquinaID])
        #expect(casas.map(\.papel) == [.administrador, .operador])
    }
}
