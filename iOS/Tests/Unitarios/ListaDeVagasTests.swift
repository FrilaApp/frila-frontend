import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private func instante(_ iso: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: iso))
}

/// Guarda os filtros que o view model mandou, e responde o que o teste pediu.
private actor FonteDeVagas {
    private(set) var filtros: [FiltroVagas] = []
    private var respostas: [Result<[VagaNaLista], ErroDaApi>]

    init(_ respostas: [Result<[VagaNaLista], ErroDaApi>]) { self.respostas = respostas }

    func buscar(_ filtro: FiltroVagas) throws -> [VagaNaLista] {
        filtros.append(filtro)
        let resposta = respostas.isEmpty ? .success([]) : respostas.removeFirst()
        return try resposta.get()
    }
}

private actor Contador {
    private var valor = 0
    func somar() -> Int { valor += 1; return valor }
}

private func vagasDoDuble() async throws -> [VagaNaLista] {
    try await ApiClienteEmMemoria().vagasAbertas(.todas)
}

private func clonarComOutroID(_ vaga: VagaNaLista, id: UUID = UUID()) -> VagaNaLista {
    VagaNaLista(
        id: id,
        funcao: vaga.funcao,
        estabelecimento: vaga.estabelecimento,
        periodo: vaga.periodo,
        local: vaga.local,
        distanciaKm: vaga.distanciaKm,
        valor: vaga.valor,
        posicoesAbertas: vaga.posicoesAbertas,
        inclusos: vaga.inclusos,
        modo: vaga.modo
    )
}

@Suite("Dia de São Paulo para o filtro de data")
struct DiaDeSaoPauloTests {
    @Test("22:30 em São Paulo ainda é o mesmo dia, embora em UTC já seja o seguinte")
    func noiteEmSaoPaulo() throws {
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-26T22:30:00-03:00")) == (try DataCivil("2026-09-26")))
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-27T01:30:00Z")) == (try DataCivil("2026-09-26")))
    }

    @Test("Instantes escritos no fuso de Los Angeles e de Tóquio caem no dia certo de São Paulo")
    func outrosFusos() throws {
        // 19:59 em LA (UTC−7) = 23:59 em São Paulo do mesmo dia.
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-26T19:59:00-07:00")) == (try DataCivil("2026-09-26")))
        // 20:00 em LA = 00:00 do dia seguinte em São Paulo.
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-26T20:00:00-07:00")) == (try DataCivil("2026-09-27")))
        // 10:30 de 27/09 em Tóquio (UTC+9) = 22:30 de 26/09 em São Paulo.
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-27T10:30:00+09:00")) == (try DataCivil("2026-09-26")))
    }

    @Test("Amanhã é o dia seguinte no calendário de São Paulo")
    func amanha() throws {
        #expect(DataCivil.deSaoPaulo(try instante("2026-09-26T22:30:00-03:00"), somandoDias: 1) == (try DataCivil("2026-09-27")))
    }
}

@MainActor
@Suite("Lista de vagas (#104): estados, filtros e paginação")
struct FeedVagasViewModelTests {
    private func viewModel(_ fonte: FonteDeVagas, agora: Date = .now, pagina: Int = 30) -> FeedVagasViewModel {
        FeedVagasViewModel(
            buscarVagas: { try await fonte.buscar($0) },
            buscarFuncoes: { try await ApiClienteEmMemoria().funcoes() },
            relogio: RelogioFixo(agora: agora),
            tamanhoDaPagina: pagina
        )
    }

    @Test("Carregada: a lista vem na ordem do servidor")
    func carregada() async throws {
        let vagas = try await vagasDoDuble()
        let vm = viewModel(FonteDeVagas([.success(vagas)]))
        #expect(vm.estado == .ociosa)
        await vm.carregar()
        #expect(vm.estado == .carregada(vagas))
        #expect(!vm.funcoes.isEmpty)
    }

    @Test("Carregando: enquanto o servidor não responde, o estado é carregando")
    func carregando() async throws {
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let vm = FeedVagasViewModel(
            buscarVagas: { _ in
                avisarChegada.yield()
                for await _ in liberar { break }
                return []
            },
            buscarFuncoes: { [] }
        )
        let carga = Task { await vm.carregar() }
        for await _ in chegou { break }
        #expect(vm.estado == .carregando)
        sinal.yield()
        await carga.value
        #expect(vm.estado == .carregada([]))
    }

    @Test("Vazia não é falha: é a lista carregada sem itens")
    func vazia() async {
        let vm = viewModel(FonteDeVagas([.success([])]))
        await vm.carregar()
        #expect(vm.estado == .carregada([]))
    }

    @Test("Falhas tipadas: sem conexão, sem ponto de referência, perfil incompatível e erro da API",
          arguments: [
              (ErroDaApi(codigo: .semRede), FalhaDaLista.semConexao),
              (ErroDaApi(codigo: .campoObrigatorio, detalhes: "latitude"), .semPontoDeReferencia),
              (ErroDaApi(codigo: .perfilIncompativel), .perfilIncompativel),
              (ErroDaApi(codigo: .limiteExcedido), .erro(ErroDaApi(codigo: .limiteExcedido))),
          ])
    func falhas(erro: ErroDaApi, esperada: FalhaDaLista) async {
        let vm = viewModel(FonteDeVagas([.failure(erro)]))
        await vm.carregar()
        #expect(vm.estado == .falha(esperada))
    }

    @Test("Os três filtros viram o FiltroVagas do contrato, com a data no dia de São Paulo")
    func filtros() async throws {
        let fonte = FonteDeVagas([])
        // 22:30 de 26/09 em São Paulo (01:30 de 27/09 em UTC).
        let vm = viewModel(fonte, agora: try instante("2026-09-27T01:30:00Z"))
        let funcao = UUID()
        await vm.selecionar(funcao: funcao)
        await vm.selecionar(data: .hoje)
        await vm.selecionar(distancia: .ate(km: 10))
        await vm.selecionar(data: .amanha)

        let enviados = await fonte.filtros
        #expect(enviados.count == 4)
        let ultimo = try #require(enviados.last)
        #expect(ultimo.funcaoID == funcao)
        #expect(ultimo.distanciaMaximaKm == 10)
        #expect(ultimo.data == (try DataCivil("2026-09-27")))
        #expect(enviados[1].data == (try DataCivil("2026-09-26")))
        #expect(ultimo.referencia == nil, "sem referência, o servidor usa o ponto base do perfil")
        #expect(ultimo.limite == 30)
        #expect(ultimo.deslocamento == 0)
    }

    @Test("Resposta de uma carga antiga não sobrescreve a da carga nova (filtro trocado no meio)")
    func descartaRespostaAntiga() async throws {
        let vaga = try #require(try await vagasDoDuble().first)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let chamadas = Contador()
        let vm = FeedVagasViewModel(
            buscarVagas: { _ in
                // A primeira carga fica retida; a segunda responde vazia na hora.
                if await chamadas.somar() == 1 {
                    avisarChegada.yield()
                    for await _ in liberar { break }
                    return [vaga]
                }
                return []
            },
            buscarFuncoes: { [] }
        )
        let primeira = Task { await vm.carregar() }
        for await _ in chegou { break }
        await vm.selecionar(distancia: .ate(km: 5))
        #expect(vm.estado == .carregada([]))
        sinal.yield()
        await primeira.value
        #expect(vm.estado == .carregada([]), "a resposta antiga foi descartada")
    }

    @Test("Puxar para atualizar mantém a lista na tela enquanto busca")
    func atualizarMantemALista() async throws {
        let vaga = try #require(try await vagasDoDuble().first)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let chamadas = Contador()
        let vm = FeedVagasViewModel(
            buscarVagas: { _ in
                if await chamadas.somar() == 2 {
                    avisarChegada.yield()
                    for await _ in liberar { break }
                }
                return [vaga]
            },
            buscarFuncoes: { [] }
        )
        await vm.carregar()
        let atualizacao = Task { await vm.atualizar() }
        for await _ in chegou { break }
        #expect(vm.estado == .carregada([vaga]), "a lista continua enquanto atualiza")
        sinal.yield()
        await atualizacao.value
        #expect(vm.estado == .carregada([vaga]))
    }

    @Test("Falha ao carregar mais não apaga a lista")
    func falhaNaPaginaSeguinte() async throws {
        let vaga = try #require(try await vagasDoDuble().first)
        let vaga2 = clonarComOutroID(vaga)
        let fonte = FonteDeVagas([.success([vaga, vaga2]), .failure(ErroDaApi(codigo: .semRede))])
        let vm = viewModel(fonte, pagina: 2)
        await vm.carregar()
        await vm.carregarMais()
        #expect(vm.estado == .carregada([vaga, vaga2]))
    }

    @Test("Paginação: a próxima página pede o deslocamento certo e soma à lista")
    func paginacao() async throws {
        let vaga1 = try #require(try await vagasDoDuble().first)
        let vaga2 = clonarComOutroID(vaga1)
        let vaga3 = clonarComOutroID(vaga1)
        let fonte = FonteDeVagas([.success([vaga1, vaga2]), .success([vaga3])])
        let vm = viewModel(fonte, pagina: 2)
        await vm.carregar()
        #expect(vm.haMaisPaginas)
        await vm.carregarMais()
        #expect(vm.estado == .carregada([vaga1, vaga2, vaga3]))
        #expect(!vm.haMaisPaginas)
        #expect(await fonte.filtros.last?.deslocamento == 2)
    }

    @Test("Paginação: remove repetidas por id mantendo a ordem quando a página 2 traz vaga da página 1")
    func paginacaoSemRepetidas() async throws {
        let vaga1 = try #require(try await vagasDoDuble().first)
        let vaga2 = clonarComOutroID(vaga1)
        let vaga3 = clonarComOutroID(vaga1)
        // Página 1 devolve vaga1 e vaga2; página 2 traz vaga2 (já na lista) e vaga3 (nova).
        let fonte = FonteDeVagas([.success([vaga1, vaga2]), .success([vaga2, vaga3])])
        let vm = viewModel(fonte, pagina: 2)
        await vm.carregar()
        #expect(vm.estado == .carregada([vaga1, vaga2]))
        await vm.carregarMais()
        #expect(vm.estado == .carregada([vaga1, vaga2, vaga3]))
    }
}

@MainActor
@Suite("Detalhe da vaga (#104)")
struct DetalheVagaViewModelTests {
    @Test("Carrega a vaga do contrato")
    func carregado() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try #require(try await api.vagasAbertas(.todas).first)
        let vm = DetalheVagaViewModel(vagaID: vaga.id, api: api)
        await vm.carregar()
        guard case let .carregado(detalhe) = vm.estado else { Issue.record("esperado carregado: \(vm.estado)"); return }
        #expect(detalhe.id == vaga.id)
    }

    @Test("Vaga inexistente é naoEncontrada (404), não erro genérico")
    func naoEncontrada() async {
        let vm = DetalheVagaViewModel(vagaID: UUID(), api: ApiClienteEmMemoria())
        await vm.carregar()
        #expect(vm.estado == .naoEncontrada)
    }

    @Test("Sem rede é falha semConexao")
    func semRede() async {
        let vm = DetalheVagaViewModel(vagaID: UUID(), api: ApiClienteEmMemoria(cenario: .semRede))
        await vm.carregar()
        #expect(vm.estado == .falha(.semConexao))
    }

    @Test("O detalhe não tem campo de telefone nem de documento do estabelecimento")
    func semTelefoneNemDocumento() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try await api.detalheDaVaga(id: try #require(try await api.vagasAbertas(.todas).first).id)
        let proibidos = ["telefone", "whatsapp", "documento", "cpf", "cnpj"]
        let campos = Mirror(reflecting: vaga).children.compactMap(\.label)
            + Mirror(reflecting: vaga.estabelecimento).children.compactMap(\.label)
        #expect(campos.filter { campo in proibidos.contains { campo.lowercased().contains($0) } }.isEmpty)
    }

    @Test("Nome do contratante com [x](https://y) e *z* entra como texto literal (verbatim) no AvisoFrila")
    func avisoRN10Literal() {
        let nomeMaldoso = "[x](https://y) e *z*"
        let mensagem = TextosDoProfissional.Detalhe.avisoRN10(nomeMaldoso)
        let aviso = AvisoFrila(verbatim: mensagem, tom: .alerta)
        let descricao = String(describing: aviso.body)
        #expect(descricao.contains("verbatim(\"\(mensagem)\")"))
        #expect(descricao.contains("[x](https://y)"))
        #expect(descricao.contains("*z*"))
    }

    @Test("Cartão de vaga inclui local, inclusos e vagas abertas no rótulo de acessibilidade")
    func rotuloDeAcessibilidadeDoCartao() async throws {
        let vaga = try #require(try await vagasDoDuble().first)
        let cartao = CartaoVaga(vaga)
        let rotulo = cartao.rotuloDeAcessibilidade
        #expect(rotulo.contains(vaga.local))
        #expect(rotulo.contains("\(vaga.posicoesAbertas) vagas abertas"))
        if vaga.inclusos.refeicao {
            #expect(rotulo.contains("Refeição"))
        }
    }

    @Test("Rótulo de acessibilidade usa singular quando há 1 vaga aberta")
    func rotuloDeAcessibilidadeSingular() async throws {
        let base = try #require(try await vagasDoDuble().first)
        let vaga = VagaNaLista(
            id: base.id, funcao: base.funcao, estabelecimento: base.estabelecimento, periodo: base.periodo,
            local: base.local, distanciaKm: base.distanciaKm, valor: base.valor, posicoesAbertas: 1,
            inclusos: base.inclusos, modo: base.modo
        )
        let cartao = CartaoVaga(vaga)
        #expect(cartao.rotuloDeAcessibilidade.contains("1 vaga aberta"))
    }
}
