import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private final class ApiDeBloqueiosMock: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var desbloqueiosEfetuados: [Alvo] = []
    var desbloqueios: [Alvo] { trava.withLock { desbloqueiosEfetuados } }
    var falhaBloqueios: ErroDaApi?
    var falhaDesbloquear: ErroDaApi?
    var itensMockados: [ItemBloqueio]

    init(
        falhaBloqueios: ErroDaApi? = nil,
        falhaDesbloquear: ErroDaApi? = nil,
        itensMockados: [ItemBloqueio] = []
    ) {
        self.falhaBloqueios = falhaBloqueios
        self.falhaDesbloquear = falhaDesbloquear
        self.itensMockados = itensMockados
        super.init()
    }

    override func bloqueios() async throws -> [ItemBloqueio] {
        if let falhaBloqueios { throw falhaBloqueios }
        return itensMockados
    }

    override func desbloquear(_ alvo: Alvo) async throws -> Bloqueio {
        trava.withLock { desbloqueiosEfetuados.append(alvo) }
        if let falhaDesbloquear { throw falhaDesbloquear }
        return Bloqueio(alvo: alvo, criadoEm: Date(timeIntervalSince1970: 1700000000))
    }
}

@MainActor @Suite("Pessoas e locais bloqueados (A8)")
struct BloqueiosViewModelTests {
    private func itemExemplo(tipo: TipoPerfilPublico = .estabelecimento, nome: String = "Bar do Teste") -> ItemBloqueio {
        ItemBloqueio(
            alvo: Alvo(tipo: tipo, id: UUID()),
            nome: nome,
            criadoEm: Date(timeIntervalSince1970: 1700000000)
        )
    }

    @Test("Estado inicial é carregando")
    func estadoInicial() {
        let api = ApiDeBloqueiosMock()
        let vm = BloqueiosViewModel(api: api)
        #expect(vm.estado == .carregando)
        #expect(vm.itens.isEmpty)
        #expect(vm.desbloqueandoID == nil)
        #expect(vm.mensagemErro == nil)
        #expect(vm.aviso == nil)
    }

    @Test("Carrega lista com bloqueios e define estado conteudo")
    func carregarComItens() async {
        let item1 = itemExemplo(nome: "Bar do Lago")
        let item2 = itemExemplo(tipo: .profissional, nome: "Carlos Barman")
        let api = ApiDeBloqueiosMock(itensMockados: [item1, item2])
        let vm = BloqueiosViewModel(api: api)

        await vm.carregar()

        #expect(vm.estado == .conteudo([item1, item2]))
        #expect(vm.itens.count == 2)
        #expect(vm.mensagemErro == nil)
    }

    @Test("Lista vazia define estado vazio")
    func carregarVazio() async {
        let api = ApiDeBloqueiosMock(itensMockados: [])
        let vm = BloqueiosViewModel(api: api)

        await vm.carregar()

        #expect(vm.estado == .vazio)
        #expect(vm.itens.isEmpty)
    }

    @Test("Sem rede sem itens define estado erro semRede")
    func carregarSemRedeSemItens() async {
        let api = ApiDeBloqueiosMock(falhaBloqueios: ErroDaApi(codigo: .semRede))
        let vm = BloqueiosViewModel(api: api)

        await vm.carregar()

        #expect(vm.estado == .erro(TextosBloqueios.semRede))
        #expect(vm.itens.isEmpty)
    }

    @Test("Sem rede com itens prévios define estado offline com aviso")
    func carregarSemRedeComItens() async {
        let item = itemExemplo()
        let api = ApiDeBloqueiosMock(itensMockados: [item])
        let vm = BloqueiosViewModel(api: api)

        await vm.carregar()
        #expect(vm.estado == .conteudo([item]))

        api.falhaBloqueios = ErroDaApi(codigo: .semRede)
        await vm.carregar()

        #expect(vm.estado == .offline([item]))
        #expect(vm.aviso == TextosBloqueios.avisoOffline)
        #expect(vm.itens.count == 1)
    }

    @Test("Erro genérico na carga define estado erro erroCarregar")
    func carregarErroGenerico() async {
        let api = ApiDeBloqueiosMock(falhaBloqueios: ErroDaApi(codigo: .respostaInvalida))
        let vm = BloqueiosViewModel(api: api)

        await vm.carregar()

        #expect(vm.estado == .erro(TextosBloqueios.erroCarregar))
        #expect(vm.itens.isEmpty)
    }

    @Test("Desbloquear com sucesso remove item e sincroniza com BloqueiosDaSessao")
    func desbloquearComSucesso() async {
        let item1 = itemExemplo(nome: "Bar do Lago")
        let item2 = itemExemplo(tipo: .profissional, nome: "Carlos Barman")
        let api = ApiDeBloqueiosMock(itensMockados: [item1, item2])
        let sessao = BloqueiosDaSessao()
        sessao.registrar(item1.alvo)
        sessao.registrar(item2.alvo)

        let vm = BloqueiosViewModel(api: api, bloqueiosDaSessao: sessao)
        await vm.carregar()

        await vm.desbloquear(item1)

        #expect(vm.itens == [item2])
        #expect(vm.estado == .conteudo([item2]))
        #expect(!sessao.contem(item1.alvo))
        #expect(sessao.contem(item2.alvo))
        #expect(api.desbloqueios == [item1.alvo])
        #expect(vm.mensagemErro == nil)
    }

    @Test("Desbloquear último item transita para estado vazio")
    func desbloquearUltimoItemTransitaParaVazio() async {
        let item = itemExemplo()
        let api = ApiDeBloqueiosMock(itensMockados: [item])
        let sessao = BloqueiosDaSessao()
        sessao.registrar(item.alvo)

        let vm = BloqueiosViewModel(api: api, bloqueiosDaSessao: sessao)
        await vm.carregar()
        #expect(vm.estado == .conteudo([item]))

        await vm.desbloquear(item)

        #expect(vm.itens.isEmpty)
        #expect(vm.estado == .vazio)
        #expect(!sessao.contem(item.alvo))
    }

    @Test("Desbloquear com falha de rede exibe mensagem semRede e preserva item")
    func desbloquearFalhaSemRede() async {
        let item = itemExemplo()
        let api = ApiDeBloqueiosMock(
            falhaDesbloquear: ErroDaApi(codigo: .semRede),
            itensMockados: [item]
        )
        let sessao = BloqueiosDaSessao()
        sessao.registrar(item.alvo)

        let vm = BloqueiosViewModel(api: api, bloqueiosDaSessao: sessao)
        await vm.carregar()

        await vm.desbloquear(item)

        #expect(vm.itens == [item])
        #expect(vm.mensagemErro == TextosBloqueios.semRede)
        #expect(sessao.contem(item.alvo))
        #expect(vm.desbloqueandoID == nil)
    }

    @Test("Desbloquear com falha genérica exibe erroDesbloquear")
    func desbloquearFalhaGenerica() async {
        let item = itemExemplo()
        let api = ApiDeBloqueiosMock(
            falhaDesbloquear: ErroDaApi(codigo: .respostaInvalida),
            itensMockados: [item]
        )

        let vm = BloqueiosViewModel(api: api)
        await vm.carregar()

        await vm.desbloquear(item)

        #expect(vm.itens == [item])
        #expect(vm.mensagemErro == TextosBloqueios.erroDesbloquear)
    }

    // MARK: - Integração com ApiClienteEmMemoria

    @Test("ApiClienteEmMemoria: bloqueios lista itens ordenados por data decrescente e com nome")
    func memoriaBloqueiosEListagem() async throws {
        let api = ApiClienteEmMemoria()
        let vagas = try await api.vagasAbertas(.todas)
        let estabelecimento = try #require(vagas.first).estabelecimento
        let alvoEstab = Alvo(estabelecimento)

        // Inicialmente vazio
        let vazios = try await api.bloqueios()
        #expect(vazios.isEmpty)

        // Bloqueia
        let b = try await api.bloquear(alvoEstab)
        #expect(b.alvo == alvoEstab)

        // Lista
        let lista = try await api.bloqueios()
        #expect(lista.count == 1)
        #expect(lista[0].alvo == alvoEstab)
        #expect(lista[0].nome == estabelecimento.nome)

        // Vagas do estabelecimento deixaram de aparecer
        let vagasAposBloqueio = try await api.vagasAbertas(.todas)
        #expect(!vagasAposBloqueio.contains(where: { $0.estabelecimento.id == estabelecimento.id }))

        // Desbloqueia
        let desb = try await api.desbloquear(alvoEstab)
        #expect(desb.alvo == alvoEstab)

        // Lista agora está vazia
        let listaApos = try await api.bloqueios()
        #expect(listaApos.isEmpty)

        // Vagas voltam a aparecer
        let vagasAposDesbloqueio = try await api.vagasAbertas(.todas)
        #expect(vagasAposDesbloqueio.contains(where: { $0.estabelecimento.id == estabelecimento.id }))

        // Perfil público volta a responder
        let perfilRecuperado = try await api.perfilPublico(id: estabelecimento.id)
        #expect(perfilRecuperado.id == estabelecimento.id)

        // Idempotência: desbloquear de novo devolve 200 sem erro
        let desbRepetido = try await api.desbloquear(alvoEstab)
        #expect(desbRepetido.alvo == alvoEstab)
    }
}
