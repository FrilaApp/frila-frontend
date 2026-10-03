import Foundation
import FrilaDados
import FrilaDominio
@testable import FrilaApresentacao
import Testing

private final class ApiDeSeguranca: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var recebidas: [Denuncia] = []
    var denuncias: [Denuncia] { trava.withLock { recebidas } }
    let falha: ErroDaApi?
    let perdePrimeiraResposta: Bool
    init(falha: ErroDaApi? = nil, perdePrimeiraResposta: Bool = false) {
        self.falha = falha
        self.perdePrimeiraResposta = perdePrimeiraResposta
        super.init()
    }
    override func denunciar(_ denuncia: Denuncia) async throws -> Protocolo {
        let numero = trava.withLock { recebidas.append(denuncia); return recebidas.count }
        if let falha { throw falha }
        let protocolo = try await base.denunciar(denuncia)
        if perdePrimeiraResposta && numero == 1 { throw ErroDaApi(codigo: .semRede) }
        return protocolo
    }
    override func bloquear(_ alvo: Alvo) async throws -> Bloqueio {
        if let falha { throw falha }
        return try await base.bloquear(alvo)
    }
    override func perfilPublico(id: UUID) async throws -> PerfilPublico {
        if let falha { throw falha }
        return try await base.perfilPublico(id: id)
    }
}

@MainActor @Suite("Denunciar e bloquear (#39)")
struct SegurancaViewModelTests {
    private func perfil(_ api: any ApiCliente) async throws -> PerfilPublico {
        try #require(try await api.vagasAbertas(.todas).first).estabelecimento
    }

    @Test("Relato vazio, curto ou só espaços não chega à API", arguments: ["", "curto", "          ", "  nove car  "])
    func relatoInvalido(_ relato: String) async throws {
        let api = ApiDeSeguranca()
        let model = SegurancaViewModel(perfil: try await perfil(api), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = relato
        await model.denunciar()
        #expect(api.denuncias.isEmpty)
        #expect(model.erroDenuncia == TextosDaSeguranca.relatoMinimo)
    }

    @Test("Cada motivo envia o alvo e mostra o protocolo e prazo devolvidos", arguments: MotivoDenuncia.allCases)
    func denunciaValida(_ motivo: MotivoDenuncia) async throws {
        let api = ApiDeSeguranca()
        let perfil = try await perfil(api)
        let model = SegurancaViewModel(perfil: perfil, api: api, bloqueios: BloqueiosDaSessao())
        model.motivo = motivo
        model.relato = "  Relato válido de um ocorrido.  "
        await model.denunciar()
        let enviada = try #require(api.denuncias.first)
        #expect(enviada.alvo == Alvo(perfil))
        #expect(enviada.motivo == motivo)
        #expect(enviada.relato == "Relato válido de um ocorrido.")
        #expect(enviada.turnoID == nil)
        #expect(model.protocolo == (try await api.base.denunciar(enviada)))
        await model.denunciar()
        #expect(api.denuncias.count == 1)
    }

    @Test("422 e sem rede preservam formulário e não anunciam sucesso", arguments: [
        (ErroDaApi(codigo: .campoInvalido, detalhes: "relato"), TextosDaSeguranca.relatoMinimo),
        (ErroDaApi(codigo: .campoInvalido, detalhes: "alvo_id"), TextosDaSeguranca.dadosInvalidos),
        (ErroDaApi(codigo: .semRede), TextosDaSeguranca.semRede)
    ])
    func falhas(_ caso: (falha: ErroDaApi, mensagemEsperada: String)) async throws {
        let api = ApiDeSeguranca(falha: caso.falha)
        let model = SegurancaViewModel(perfil: try await perfil(api), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "Relato com informação suficiente."
        await model.denunciar()
        #expect(model.protocolo == nil)
        #expect(model.erroDenuncia == caso.mensagemEsperada)
        #expect(!model.enviando)
        #expect(model.relato == "Relato com informação suficiente.")
    }

    @Test("Resposta perdida reenvia a mesma chave e recupera o protocolo já gravado")
    func idempotencia() async throws {
        let api = ApiDeSeguranca(perdePrimeiraResposta: true)
        let model = SegurancaViewModel(perfil: try await perfil(api), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "Relato de denúncia para reenvio."
        await model.denunciar()
        #expect(model.erroDenuncia == TextosDaSeguranca.semRede)
        await model.denunciar()
        #expect(api.denuncias.count == 2)
        #expect(api.denuncias[0] == api.denuncias[1])
        #expect(model.protocolo == (try await api.base.denunciar(api.denuncias[0])))
        #expect(model.erroDenuncia == nil)
    }

    @Test("Dois envios concorrentes geram uma única denúncia")
    func toqueDuplo() async throws {
        let api = ApiDeSeguranca()
        let model = SegurancaViewModel(perfil: try await perfil(api), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "Relato de denúncia com dois toques."
        async let primeiro: Void = model.denunciar()
        async let segundo: Void = model.denunciar()
        _ = await (primeiro, segundo)
        #expect(api.denuncias.count == 1)
        #expect(model.protocolo != nil)
    }

    @Test("Editar denúncia recusada gera outra chave")
    func novaChaveAoEditar() async throws {
        let api = ApiDeSeguranca(falha: ErroDaApi(codigo: .campoInvalido, detalhes: "relato"))
        let model = SegurancaViewModel(perfil: try await perfil(api), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "Primeiro relato da denúncia."
        await model.denunciar()
        model.relato = "Relato corrigido da denúncia."
        await model.denunciar()
        #expect(api.denuncias[0].chave != api.denuncias[1].chave)
    }

    @Test("Bloqueio esconde vagas já carregadas, inclusive após resposta antiga e paginação")
    func filtrarLista() async throws {
        let api = ApiClienteEmMemoria()
        let vagas = try await api.vagasAbertas(.todas)
        let perfil = try #require(vagas.first).estabelecimento
        // A fonte conserva a resposta anterior de propósito, simulando uma leitura em voo.
        let feed = FeedVagasViewModel(buscarVagas: { _ in vagas }, buscarFuncoes: { [] }, tamanhoDaPagina: vagas.count)
        await feed.carregar()
        let model = SegurancaViewModel(perfil: perfil, api: api, bloqueios: feed.bloqueios)
        await model.bloquear()
        let esperado = vagas.filter { $0.estabelecimento.id != perfil.id }
        #expect(feed.estado == .carregada(esperado))
        await feed.atualizar()
        await feed.carregarMais()
        #expect(feed.estado == .carregada(esperado))
        #expect(try await api.vagasAbertas(.todas).allSatisfy { $0.estabelecimento.id != perfil.id })
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await api.perfilPublico(id: perfil.id) }
    }

    @Test("Bloqueio recusado não esconde o perfil", arguments: [
        (ErroDaApi(codigo: .semRede), TextosDaSeguranca.semRede),
        (ErroDaApi(codigo: .campoInvalido), TextosDaSeguranca.dadosInvalidos)
    ])
    func bloqueioRecusado(_ caso: (falha: ErroDaApi, mensagemEsperada: String)) async throws {
        let api = ApiDeSeguranca(falha: caso.falha)
        let perfil = try await perfil(api)
        let bloqueios = BloqueiosDaSessao()
        let model = SegurancaViewModel(perfil: perfil, api: api, bloqueios: bloqueios)
        await model.bloquear()
        #expect(!bloqueios.contem(perfil))
        #expect(model.erroBloqueio == caso.mensagemEsperada)
        #expect(!model.bloqueando)
    }

    @Test("404 de perfil usa estado indisponível; sem rede continua sendo falha")
    func perfilIndisponivel() async {
        let ausente = PerfilPublicoViewModel(id: UUID(), api: ApiDeSeguranca(falha: ErroDaApi(codigo: .naoEncontrado)))
        await ausente.carregar()
        #expect(ausente.estado == .indisponivel)
        let offline = PerfilPublicoViewModel(id: UUID(), api: ApiDeSeguranca(falha: ErroDaApi(codigo: .semRede)))
        await offline.carregar()
        #expect(offline.estado == .falha(TextosDaSeguranca.semRede))
    }

    @Test("Contratante deixa de consultar perfil do profissional após bloquear")
    func profissionalBloqueado() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let perfil = try await api.perfilPublico(id: UUID(uuidString: "80000000-0000-0000-0000-000000000001")!)
        let model = PerfilPublicoViewModel(id: perfil.id, api: api)
        await model.carregar()
        #expect(model.estado == .carregado(perfil))
        _ = try await api.bloquear(Alvo(perfil))
        await model.carregar()
        #expect(model.estado == .indisponivel)
    }
}
