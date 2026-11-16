import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança (o dublê guarda a referência e lê `agora` a cada regra).
private final class RelogioAjustavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var instante: Date
    init(_ instante: Date) { self.instante = instante }
    var agora: Date { trava.withLock { instante } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { instante = instante.addingTimeInterval(segundos) } }
}

/// As regras de `buscar_profissionais` (contrato 0.2.88) no dublê: quem aparece, a ordem, as
/// páginas e o limite, e o caminho da busca em `chamar_profissional`.
@Suite("Busca de profissionais no dublê (contrato 0.2.88)")
struct BuscaDeProfissionaisDubleTests {
    /// Segunda-feira, 16/11/2026, 12:00 em Brasília.
    private static let agora = ContratoAPI.instante("2026-11-16T15:00:00Z")!
    private static let casaID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private static let garcomID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private static let bartenderID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private typealias IDs = ApiClienteEmMemoria.IDsDaBusca
    private typealias Simulado = ApiClienteEmMemoria.ProfissionalSimuladoNaBusca

    /// Terça, 20:00 às 23:00 em Brasília: dentro da grade "toda noite" (17:00 às 02:00).
    private static func horarioDeAmanha() throws -> Periodo {
        try Periodo(inicio: ContratoAPI.instante("2026-11-17T23:00:00Z")!, fim: ContratoAPI.instante("2026-11-18T02:00:00Z")!)
    }

    private func api(_ relogio: RelogioAjustavel = RelogioAjustavel(agora)) -> ApiClienteEmMemoria {
        ApiClienteEmMemoria(cenario: .buscaDeProfissionais, relogio: relogio)
    }

    private func filtro(funcao: UUID = garcomID, regiao: Int? = nil, horario: Periodo? = nil) -> FiltroBuscaProfissionais {
        FiltroBuscaProfissionais(estabelecimentoID: Self.casaID, funcaoID: funcao, regiaoID: regiao, horario: horario)
    }

    /// Todas as páginas de uma busca, seguindo o cursor.
    private func todas(_ api: ApiClienteEmMemoria, _ filtro: FiltroBuscaProfissionais) async throws -> [CartaoProfissional] {
        var pagina = try await api.buscarProfissionais(filtro, cursor: nil, limite: nil)
        var itens = pagina.itens
        while let cursor = pagina.proximoCursor {
            pagina = try await api.buscarProfissionais(filtro, cursor: cursor, limite: nil)
            itens += pagina.itens
        }
        return itens
    }

    private func garcom() -> ServicoNoPerfil {
        let funcao = Funcao(id: Self.garcomID, nome: "Garçom", categoria: "Salão")
        return ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcao.id, unidade: .hora, valorCentavos: 3_000))
    }

    private func reputacao(_ positivas: Int, de total: Int) -> Reputacao {
        Reputacao(positivas: positivas, total: total, taxaComparecimento: 1, turnosConsiderados: total, turnosRealizados: total)
    }

    private func pedido(para profissionalID: UUID, inicio: Date, regiaoID: Int? = 1, regiao: String = "Plano Piloto") throws -> PedidoChamada {
        PedidoChamada(profissionalID: profissionalID, trabalho: PublicacaoVaga(
            estabelecimentoID: Self.casaID, funcaoID: Self.garcomID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "SCLS 405", regiaoAdministrativa: regiao, ponto: try Coordenada(latitude: -15.82, longitude: -47.92),
            valor: Dinheiro(centavos: 20_000), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Ana", chave: UUID()
        ), regiaoID: regiaoID)
    }

    // MARK: Quem aparece

    @Test("Só aparece quem aceita chamadas, sem pausa, sem suspensão, com região e com menos de 5 chamadas abertas")
    func quemFicaDeFora() async throws {
        let ids = Set(try await todas(api(), filtro()).map(\.id))
        #expect(ids.count == 25)
        #expect(ids.contains(IDs.disponivel))
        for fora in [IDs.naoAceita, IDs.pausado, IDs.suspenso, IDs.semRegiao, IDs.agendaCheia] {
            #expect(!ids.contains(fora))
        }
    }

    @Test("Sem serviço com preço para a função buscada, ninguém aparece")
    func servicoNaFuncao() async throws {
        let itens = try await todas(api(), filtro(funcao: Self.bartenderID))
        #expect(itens.isEmpty)
    }

    @Test("Outra região: só quem atende todo o DF; sem região vale a da casa (Plano Piloto)")
    func regiaoAtendida() async throws {
        let api = api()
        let gama = try await todas(api, filtro(regiao: 2)).map(\.id)
        #expect(gama == [IDs.longeComReputacaoAlta])
        let semRegiao = try await todas(api, filtro())
        #expect(semRegiao.count == 25)
        await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(filtro(regiao: 999), cursor: nil, limite: nil) }
    }

    @Test("Quem a casa bloqueou sai da busca, e o bloqueio lista o nome com a inicial")
    func bloqueioTiraDaBusca() async throws {
        let api = api()
        _ = try await api.bloquear(Alvo(tipo: .profissional, id: IDs.disponivel))
        let ids = try await todas(api, filtro()).map(\.id)
        #expect(!ids.contains(IDs.disponivel))
        #expect(try await api.bloqueios().first { $0.alvo.id == IDs.disponivel }?.nome == "Maria S.")
    }

    @Test("Quem já tem chamada aberta desta casa sai da lista")
    func chamadaAbertaDaCasaTiraDaLista() async throws {
        let api = api()
        _ = try await api.chamarProfissional(pedido(para: IDs.disponivel, inicio: Self.agora.addingTimeInterval(24 * 3600)))
        let ids = try await todas(api, filtro()).map(\.id)
        #expect(!ids.contains(IDs.disponivel))
        #expect(ids.count == 24)
    }

    @Test("A preferência só-CNPJ tira a casa de pessoa física; a de CNPJ continua vendo")
    func soCnpj() async throws {
        let api = api()
        await api.definirProfissionaisNaBusca([Simulado(nomeCompleto: "Clara Nobre", servicos: [garcom()], aceitaDe: .soCnpj)])
        #expect(try await todas(api, filtro()).count == 1) // a casa de exemplo tem CNPJ
    }

    @Test("Com horário, sai quem a chamada recusaria pela antecedência mínima dele; sem horário, ele aparece")
    func antecedenciaComHorario() async throws {
        let api = api()
        let id = UUID()
        await api.definirProfissionaisNaBusca([Simulado(id: id, nomeCompleto: "Lia Calma", servicos: [garcom()], antecedenciaMinimaH: 48)])
        #expect(try await todas(api, filtro(horario: Self.horarioDeAmanha())).isEmpty)
        #expect(try await todas(api, filtro()).map(\.id) == [id])
    }

    @Test("Turno confirmado no horário não tira ninguém da lista nem muda o selo (0.2.88)")
    func turnoConfirmadoNaoFiltra() async throws {
        let api = api()
        let horario = try Self.horarioDeAmanha()
        let noite = try (0...6).map { JanelaDeDisponibilidade(diaDaSemana: $0, inicio: try HoraDoDia(hora: 17, minuto: 0), fim: try HoraDoDia(hora: 2, minuto: 0)) }
        await api.definirProfissionaisNaBusca([Simulado(nomeCompleto: "Téo Ocupado", servicos: [garcom()], grade: noite, turnosConfirmados: [horario])])
        let itens = try await todas(api, filtro(horario: horario))
        #expect(itens.count == 1)
        #expect(itens.first?.disponivelNoHorario == true)
    }

    // MARK: Ordem

    @Test("Com horário, quem tem a grade livre vem primeiro e com o selo; depois a faixa de distância")
    func ordemPorSeloEFaixa() async throws {
        let itens = try await todas(api(), filtro(horario: Self.horarioDeAmanha()))
        let selos = itens.map { $0.disponivelNoHorario == true }
        #expect(selos.first == true)
        #expect(selos == selos.sorted { $0 && !$1 }, "nenhum sem selo antes de um com selo")
        #expect(itens.first { $0.id == IDs.disponivel }?.disponivelNoHorario == true)
        for grupo in [true, false] {
            let faixas = itens.filter { ($0.disponivelNoHorario == true) == grupo }.map(\.distanciaFaixa)
            let ordem: [FaixaDistancia] = [.ate5km, .de5a15km, .maisDe15km]
            #expect(faixas == faixas.sorted { ordem.firstIndex(of: $0)! < ordem.firstIndex(of: $1)! })
        }
    }

    @Test("Sem horário, o selo não vem")
    func semHorarioSemSelo() async throws {
        let itens = try await todas(api(), filtro())
        #expect(itens.allSatisfy { $0.disponivelNoHorario == nil })
    }

    @Test("A reputação não ordena: a mais alta, longe, vem depois das perto; trocar as reputações não muda a ordem")
    func reputacaoNaoOrdena() async throws {
        let itens = try await todas(api(), filtro())
        let posicaoDaRosa = try #require(itens.firstIndex { $0.id == IDs.longeComReputacaoAlta })
        #expect(itens[..<posicaoDaRosa].contains { $0.distanciaFaixa == .ate5km })

        let ids = (1...6).map { _ in UUID() }
        func lista(_ reputacoes: [Reputacao]) throws -> [Simulado] {
            try zip(ids, reputacoes).map { Simulado(id: $0, nomeCompleto: "Pessoa Teste", servicos: [garcom()], reputacao: $1) }
        }
        let crescente = (1...6).map { reputacao($0, de: 6) }
        let api = api()
        await api.definirProfissionaisNaBusca(try lista(crescente))
        let primeira = try await todas(api, filtro()).map(\.id)
        await api.definirProfissionaisNaBusca(try lista(crescente.reversed()))
        let segunda = try await todas(api, filtro()).map(\.id)
        #expect(primeira == segunda)
    }

    @Test("O embaralhado é estável no mesmo dia e muda no dia seguinte")
    func embaralhadoPorDia() async throws {
        let relogio = RelogioAjustavel(Self.agora)
        let api = api(relogio)
        let manha = try await todas(api, filtro()).map(\.id)
        relogio.avancar(3 * 3600)
        #expect(try await todas(api, filtro()).map(\.id) == manha)
        relogio.avancar(24 * 3600)
        let amanha = try await todas(api, filtro()).map(\.id)
        #expect(Set(amanha) == Set(manha))
        #expect(amanha != manha)
    }

    // MARK: Páginas e limites

    @Test("Páginas de 20 pelo cursor, e no máximo 200 resultados por busca")
    func paginasEMaximo() async throws {
        let api = api()
        let servico = garcom()
        await api.definirProfissionaisNaBusca((1...230).map { Simulado(nomeCompleto: "Pessoa \($0)", servicos: [servico]) })
        let primeira = try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil)
        #expect(primeira.itens.count == 20)
        #expect(primeira.temMais)
        let itens = try await todas(api, filtro())
        #expect(itens.count == 200)
        #expect(Set(itens.map(\.id)).count == 200)
        let curta = try await api.buscarProfissionais(filtro(), cursor: nil, limite: 5)
        #expect(curta.itens.count == 5)
    }

    @Test("A 61ª busca na hora é 429; as páginas pelo cursor não contam; passada a hora, volta")
    func limitePorHora() async throws {
        let relogio = RelogioAjustavel(Self.agora)
        let api = api(relogio)
        var ultima: PaginaBuscaProfissionais?
        for _ in 1...ApiClienteEmMemoria.limiteDeBuscasPorHora {
            ultima = try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil)
        }
        let cursor = try #require(ultima?.proximoCursor)
        #expect(try await api.buscarProfissionais(filtro(), cursor: cursor, limite: nil).itens.count == 5)
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil) }
        #expect(erro?.codigo == .limiteExcedido)
        relogio.avancar(3601)
        #expect(try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil).itens.count == 20)
    }

    @Test("Cursor de outra busca, adulterado ou de outro dia é cursor_invalido")
    func cursorInvalido() async throws {
        let relogio = RelogioAjustavel(Self.agora)
        let api = api(relogio)
        let cursor = try #require(try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil).proximoCursor)
        for (outroFiltro, outroCursor) in [(filtro(regiao: 2), cursor), (filtro(), "adulterado")] {
            let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(outroFiltro, cursor: outroCursor, limite: nil) }
            #expect(erro?.codigo == .cursorInvalido)
        }
        relogio.avancar(24 * 3600)
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(filtro(), cursor: cursor, limite: nil) }
        #expect(erro?.codigo == .cursorInvalido)
    }

    @Test("Com a chave desligada, a busca é sem_permissao com recurso_desligado; horário no passado é campo_invalido")
    func chaveDesligadaEHorarioNoPassado() async throws {
        let api = api()
        let passado = try Periodo(inicio: Self.agora.addingTimeInterval(-3600), fim: Self.agora.addingTimeInterval(3600))
        let invalido = await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(filtro(horario: passado), cursor: nil, limite: nil) }
        #expect(invalido?.codigo == .campoInvalido)

        await api.definirRecursos(RecursosDoApp(chamadaDireta: true, buscaProfissionais: false))
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.buscarProfissionais(filtro(), cursor: nil, limite: nil) }
        #expect(erro?.codigo == .semPermissao)
        #expect(erro?.detalhes == "recurso_desligado")
    }

    @Test("O cartão traz nome com inicial, serviço com preço, regiões, faixa e reputação, sem foto")
    func cartao() async throws {
        let maria = try #require(try await todas(api(), filtro()).first { $0.id == IDs.disponivel })
        #expect(maria.nome == "Maria S.")
        #expect(maria.servico.funcao.id == Self.garcomID)
        #expect(maria.servico.servico.valorCentavos == 3_500)
        #expect(maria.regioes.map(\.nome) == ["Plano Piloto"])
        #expect(maria.distanciaFaixa == .ate5km)
    }

    // MARK: chamar_profissional e perfil_publico pela busca

    @Test("chamar_profissional aceita quem veio da busca, sem vínculo, com o regiao_id copiado da busca")
    func chamarQuemVeioDaBusca() async throws {
        let api = api()
        let chamada = try await api.chamarProfissional(pedido(para: IDs.disponivel, inicio: Self.agora.addingTimeInterval(24 * 3600)))
        #expect(chamada.profissionalID == IDs.disponivel)
        #expect(chamada.estado == .aberta)
        #expect(await api.pedidosChamadaRecebidos.last?.regiaoID == 1)
    }

    @Test("Pela busca: sem aceitar chamadas é a recusa genérica, pausado é pausado e regiao_id de outra região é campo_invalido")
    func recusasPelaBusca() async throws {
        let api = api()
        let inicio = Self.agora.addingTimeInterval(24 * 3600)
        let generica = await #expect(throws: ErroDaApi.self) { _ = try await api.chamarProfissional(pedido(para: IDs.naoAceita, inicio: inicio)) }
        #expect(generica?.detalhes == "nao_aceita_chamadas")
        let pausa = await #expect(throws: ErroDaApi.self) { _ = try await api.chamarProfissional(pedido(para: IDs.pausado, inicio: inicio)) }
        #expect(pausa?.detalhes == "pausado")
        let regiao = await #expect(throws: ErroDaApi.self) { _ = try await api.chamarProfissional(pedido(para: IDs.disponivel, inicio: inicio, regiaoID: 2)) }
        #expect(regiao?.codigo == .campoInvalido)
        // Sem regiao_id, vale a região de mesmo nome do trabalho.
        #expect(try await api.chamarProfissional(pedido(para: IDs.disponivel, inicio: inicio, regiaoID: nil)).estado == .aberta)
    }

    @Test("Com a chave da busca desligada, chamar quem só veio da busca é a recusa genérica")
    func chamarComChaveDesligada() async throws {
        let api = api()
        await api.definirRecursos(RecursosDoApp(chamadaDireta: true, buscaProfissionais: false))
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await api.chamarProfissional(pedido(para: IDs.disponivel, inicio: Self.agora.addingTimeInterval(24 * 3600)))
        }
        #expect(erro?.detalhes == "nao_aceita_chamadas")
    }

    @Test("perfil_publico de quem está na busca: nome com inicial, campos ricos sem foto, com ou sem pausa")
    func perfilPublicoPelaBusca() async throws {
        let api = api()
        let maria = try await api.perfilPublico(id: IDs.disponivel)
        #expect(maria.nome == "Maria S.")
        #expect(maria.fotoURL == nil)
        #expect(maria.servicos.isEmpty == false)
        let pausado = try await api.perfilPublico(id: IDs.pausado)
        #expect(pausado.nome == "Pedro P.")
        #expect(pausado.servicos.isEmpty == false)
        let naoAceita = try await api.perfilPublico(id: IDs.naoAceita)
        #expect(naoAceita.servicos.isEmpty)
    }

    // MARK: "Aceito chamadas diretas"

    @Test("Ligar aceita_chamadas exige a versão do texto, e a resposta diz o que falta para aparecer")
    func aceitaChamadas() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaRecebida, relogio: RelogioAjustavel(Self.agora))
        await api.definirRecursos(RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
        let semVersao = await #expect(throws: ErroDaApi.self) {
            _ = try await api.definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(aceitaChamadas: true))
        }
        #expect(semVersao?.codigo == .campoObrigatorio)
        #expect(semVersao?.detalhes == "versao_texto_busca")

        let ligada = try await api.definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(aceitaChamadas: true, versaoTextoBusca: "busca-v1"))
        #expect(ligada.aceitaChamadas)
        #expect(ligada.pendenciasParaBusca.contains(.semAparelhoAtualizado))
        #expect(!ligada.apareceNaBusca)

        let desligada = try await api.definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(aceitaChamadas: false))
        #expect(!desligada.aceitaChamadas)
        #expect(desligada.pendenciasParaBusca.isEmpty)
        // Mudar outro campo não mexe em aceita_chamadas.
        let outra = try await api.definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(antecedenciaMinimaH: 8))
        #expect(!outra.aceitaChamadas)
    }

    @Test("Com a chave da busca desligada, mandar aceita_chamadas é sem_permissao com recurso_desligado")
    func aceitaChamadasComChaveDesligada() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaRecebida, relogio: RelogioAjustavel(Self.agora))
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await api.definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(aceitaChamadas: true, versaoTextoBusca: "busca-v1"))
        }
        #expect(erro?.codigo == .semPermissao)
        #expect(erro?.detalhes == "recurso_desligado")
    }
}
