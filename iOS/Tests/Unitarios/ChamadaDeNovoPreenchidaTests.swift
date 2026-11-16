import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private final class ApiSemLeituraDaVagaAnterior: ApiClienteEncaminhador, @unchecked Sendable {
    override func detalheDaVaga(id: UUID) async throws -> Vaga {
        Issue.record("Chamar de novo não deve consultar detalheDaVaga com a conta da casa")
        throw ErroDaApi(codigo: .perfilIncompativel)
    }
}

@Suite("Chamar de novo: dados da vaga anterior e local da casa")
@MainActor
struct ChamadaDeNovoPreenchidaTests {
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

    private func data(_ texto: String) throws -> Date {
        try Date(texto, strategy: .iso8601)
    }

    private func vaga(funcao: String = "Garçom", centavos: Int = 18_050,
                      duracaoHoras: Double = 6) throws -> VagaResumo {
        let inicio = try data("2026-11-13T19:30:00-03:00") // sexta, em São Paulo
        return try VagaResumo(id: UUID(), funcao: funcao, local: "Outro endereço sintético",
            regiaoAdministrativa: "Outra região", periodo: Periodo(inicio: inicio,
                fim: inicio.addingTimeInterval(duracaoHoras * 3600)), valor: Dinheiro(centavos: centavos))
    }

    private func preparar(_ vaga: VagaResumo? = nil, agoraTexto: String = "2026-11-19T10:00:00-03:00")
        async throws -> (ApiClienteEmMemoria, ChamadaDiretaViewModel) {
        let agora = try data(agoraTexto)
        let base = ApiClienteEmMemoria(cenario: .chamadaDireta, relogio: RelogioFixo(agora: agora))
        let casa = try #require(try await base.meusEstabelecimentos().first)
        let modelo = ChamadaDiretaViewModel(api: ApiSemLeituraDaVagaAnterior(base: base),
            profissionalID: profissionalID, estabelecimentoID: casa.id, vagaAnterior: vaga, agora: { agora })
        await modelo.carregar()
        #expect(modelo.erro == nil)
        #expect(modelo.recursoHabilitado)
        return (base, modelo)
    }

    @Test("Casa a função pelo nome ignorando caixa, acentos e espaços nas pontas",
          arguments: ["Maître", "  MAITRE ", "\nmaÎtre\t"])
    func funcaoPeloNome(nome: String) async throws {
        let (_, modelo) = try await preparar(vaga(funcao: nome))
        let esperada = try #require(modelo.funcoes.first { $0.nome == "Maître" })
        #expect(modelo.funcaoID == esperada.id)
        #expect(modelo.funcaoID != modelo.funcoes.first?.id)
    }

    @Test("Função ausente no catálogo mantém a primeira opção")
    func funcaoSemCasamento() async throws {
        let (_, modelo) = try await preparar(vaga(funcao: "Função inexistente"))
        #expect(modelo.funcaoID == modelo.funcoes.first?.id)
    }

    @Test("Copia o valor em reais e centavos, exigindo confirmar o total", arguments: [18_000, 18_050, 18_005])
    func valorDaVaga(centavos: Int) async throws {
        let (_, modelo) = try await preparar(vaga(centavos: centavos))
        let textos = [18_000: "180", 18_050: "180,50", 18_005: "180,05"]
        #expect(modelo.valorTexto == textos[centavos])
        #expect(modelo.valorCentavos == centavos)
        #expect(!modelo.totalConfirmado)
        #expect(!modelo.podeEnviar)
    }

    @Test("Escolhe a próxima sexta às 19h30 em SP respeitando agora mais duas horas",
          arguments: [
            ["2026-11-20T18:00:00-03:00", "2026-11-27T19:30:00-03:00"],
            ["2026-11-19T10:00:00-03:00", "2026-11-20T19:30:00-03:00"],
            ["2026-11-20T17:30:00-03:00", "2026-11-20T19:30:00-03:00"],
            ["2026-11-20T17:30:01-03:00", "2026-11-27T19:30:00-03:00"]
          ])
    func horario(caso: [String]) async throws {
        let anterior = try vaga()
        let (_, modelo) = try await preparar(anterior, agoraTexto: caso[0])
        #expect(modelo.inicio == (try data(caso[1])))
        #expect(modelo.inicio >= modelo.inicioMinimo)
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = FormatadorFrila.fuso
        for componente in [Calendar.Component.weekday, .hour, .minute] {
            #expect(calendario.component(componente, from: modelo.inicio)
                    == calendario.component(componente, from: anterior.periodo.inicio))
        }
    }

    @Test("Copia a duração e limita os extremos a duas e dezesseis horas",
          arguments: [[6.5, 6.5], [1, 2], [20, 16]])
    func duracao(caso: [Double]) async throws {
        let (_, modelo) = try await preparar(vaga(duracaoHoras: caso[0]))
        #expect(modelo.fim.timeIntervalSince(modelo.inicio) == caso[1] * 3600)
        #expect(modelo.faixaDoTermino.contains(modelo.fim))
    }

    @Test("Local, região, ponto e responsável são da casa, e inclusos ficam desmarcados")
    func dadosDaCasa() async throws {
        let anterior = try vaga()
        let (api, modelo) = try await preparar(anterior)
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let casa = try await api.meuEstabelecimento(id: casaID)
        #expect(modelo.local == casa.endereco)
        #expect(modelo.local != anterior.local)
        #expect(modelo.responsavel == casa.nome)
        #expect(!modelo.refeicao && !modelo.transporte && !modelo.materialProprio)
        modelo.totalConfirmado = true
        await modelo.enviar()
        let trabalho = try #require(await api.pedidosChamadaRecebidos.first).trabalho
        #expect(trabalho.local == casa.endereco)
        #expect(trabalho.regiaoAdministrativa == casa.regiaoAdministrativa)
        #expect(trabalho.ponto == casa.ponto)
        #expect(trabalho.responsavelLocal == casa.nome)
        #expect(!trabalho.inclusos.refeicao && !trabalho.inclusos.transporte && !trabalho.inclusos.exigeMaterialProprio)
        #expect(modelo.resultado != nil)
    }

    @Test("Sem vaga anterior mantém os padrões da Equipe de confiança")
    func semVagaAnterior() async throws {
        let (api, modelo) = try await preparar()
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let casa = try await api.meuEstabelecimento(id: casaID)
        let agora = try data("2026-11-19T10:00:00-03:00")
        #expect(modelo.local == casa.endereco)
        #expect(modelo.responsavel == casa.nome)
        #expect(modelo.funcaoID == modelo.funcoes.first?.id)
        #expect(modelo.valorTexto.isEmpty && modelo.valorCentavos == 0)
        #expect(!modelo.totalConfirmado)
        #expect(modelo.inicio == agora.addingTimeInterval(24 * 3600))
        #expect(modelo.fim == agora.addingTimeInterval(28 * 3600))
        #expect(!modelo.refeicao && !modelo.transporte && !modelo.materialProprio)
    }
}
