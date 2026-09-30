import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Dublê de API")
struct ApiEmMemoriaTests {
    static let inclusos = Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false)

    @Test("Sem rede, o fluxo passa por entrada → publicar → lista → candidatar → meu turno")
    func fluxoPrincipal() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        try await api.solicitarCodigo(email: "casa@frila.app")
        try await api.verificarCodigo(email: "casa@frila.app", codigo: "123456")
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await api.minhaConta() }

        let conta = try await api.criarConta(CadastroConta(
            nome: "Casa Teste", telefone: "+5561988887777", nascimento: try DataCivil("1990-01-31"),
            perfil: .contratante, versaoTermos: "2026-09-22"
        ))
        #expect(try await api.minhaConta() == conta)

        let ponto = try Coordenada(latitude: -15.8121, longitude: -47.8997)
        let casa = try await api.cadastrarEstabelecimento(CadastroEstabelecimento(
            nome: "Casa Teste", documento: "11222333000181", tipo: .foodService, endereco: "SCS, Brasília - DF", ponto: ponto
        ))
        #expect(try await api.meusEstabelecimentos().contains { $0.id == casa.id && $0.papel == .administrador })

        let funcao = try #require(await api.funcoes().first)
        let inicio = Date.now.addingTimeInterval(172_800)
        let publicada = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)),
            local: casa.endereco, ponto: ponto, valor: Dinheiro(centavos: 15000), posicoes: 1,
            inclusos: Self.inclusos, responsavelLocal: "Marina", chave: UUID()
        ))
        #expect(try await api.vagasAbertas().contains { $0.id == publicada.vagaID })

        let candidatura = try await api.candidatar(vagaID: publicada.vagaID)
        #expect(candidatura.estado == .confirmada)
        let turnoID = try #require(candidatura.turnoID)
        let turno = try #require(try await api.meusTurnos().first { $0.id == turnoID })
        #expect(turno.vaga.id == publicada.vagaID)
        #expect(turno.contraparte.id == casa.id)
        #expect(turno.contato == nil)
        #expect(try await api.contatoDoTurno(id: turnoID) == candidatura.contato)

        await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) { try await api.candidatar(vagaID: publicada.vagaID) }
        #expect(try await api.vagasAbertas().contains { $0.id == publicada.vagaID } == false)
        let painel = try await api.painelEstabelecimento(id: casa.id, periodo: try Periodo(inicio: .now, fim: inicio.addingTimeInterval(86_400)))
        #expect(painel.vagas.first?.posicoes.contains { $0.turnoID == turnoID } == true)
    }

    @Test("Toda operação do Sprint 1 do profissional tem resposta simulada")
    func sprint1Profissional() async throws {
        let api = ApiClienteEmMemoria()
        try await api.entrarDemonstracao(email: "revisao@frila.app", codigo: "codigo-da-revisao")
        let conta = try await api.minhaConta()
        #expect(conta.perfil == .profissional)

        let perfil = try await api.meuPerfilProfissional()
        let funcoes = try await api.funcoes()
        let atualizado = try await api.atualizarPerfilProfissional(AlteracaoPerfilProfissional(funcoes: funcoes.map(\.id)))
        #expect(atualizado.funcoes == funcoes)
        await #expect(throws: ErroDaApi(codigo: .perfilJaExiste)) {
            try await api.criarPerfilProfissional(DadosPerfilProfissional(funcoes: [funcoes[0].id], pontoBase: perfil.pontoBase, disponibilidades: []))
        }

        let vaga = try #require(try await api.vagasAbertas().first)
        #expect(try await api.detalheDaVaga(id: vaga.id).responsavelLocal.isEmpty == false)
        #expect(try await api.perfilPublico(id: vaga.estabelecimento.id).nome == vaga.estabelecimento.nome)
        let candidatura = try await api.candidatar(vagaID: vaga.id)
        let turnoID = try #require(candidatura.turnoID)
        #expect(try await api.meusTurnos().map(\.id) == [turnoID])
        _ = try await api.contatoDoTurno(id: turnoID)

        await #expect(throws: ErroDaApi(codigo: .registroNoFuturo)) {
            try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: 10, registradoEm: .now.addingTimeInterval(3_600))
        }
        let registro = try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: 38, registradoEm: .now.addingTimeInterval(-60))
        #expect(registro.tipo == .geolocalizado && registro.verificacao == .verificado)
        // O check-out mantém tipo e verificação do check-in, como o backend.
        let saida = try await api.fazerCheckout(turnoID: turnoID, distanciaMetros: nil, registradoEm: .now.addingTimeInterval(-30))
        #expect(saida.tipo == .geolocalizado && saida.verificacao == .verificado)
        _ = try await api.configuracaoDoApp()
        try await api.removerDispositivo(tokenFCM: "token-de-teste")
    }

    @Test("Toda operação do Sprint 1 do contratante tem resposta simulada, e a conta errada é recusada")
    func sprint1Contratante() async throws {
        let profissional = ApiClienteEmMemoria()
        let ponto = try Coordenada(latitude: -15.8121, longitude: -47.8997)
        let cadastro = CadastroEstabelecimento(nome: "Casa", documento: "11222333000181", tipo: .evento, endereco: "SCS", ponto: ponto)
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) { try await profissional.cadastrarEstabelecimento(cadastro) }

        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        _ = try await api.criarConta(CadastroConta(nome: "Casa", telefone: "+5561988887777", nascimento: try DataCivil("1990-01-31"), perfil: .contratante, versaoTermos: "2026-09-22"))
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) {
            try await api.criarPerfilProfissional(DadosPerfilProfissional(funcoes: [], pontoBase: ponto, disponibilidades: []))
        }
        let existente = try #require(try await api.meusEstabelecimentos().first)
        await #expect(throws: ErroDaApi(codigo: .documentoJaCadastrado)) {
            try await api.cadastrarEstabelecimento(CadastroEstabelecimento(nome: "Outra", documento: "12345678000190", tipo: .varejo, endereco: "SCS", ponto: ponto))
        }
        let vaga = try #require(try await api.vagasAbertas().first)
        let inicio = Date.now.addingTimeInterval(259_200)
        let novaData = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400))
        let republicada = try await api.republicarVaga(id: vaga.id, periodo: novaData, chave: UUID())
        #expect(try await api.detalheDaVaga(id: republicada.vagaID).periodo == novaData)
        let painel = try await api.painelEstabelecimento(id: existente.id, periodo: try Periodo(inicio: .now, fim: inicio.addingTimeInterval(86_400)))
        #expect(painel.vagas.count == 2)
    }

    @Test("Cenários previsíveis cobrem conflito, inelegibilidade, offline e suspensão")
    func cenarios() async throws {
        let preenchida = ApiClienteEmMemoria(cenario: .vagaPreenchida)
        let vagaID = try #require(try? await ApiClienteEmMemoria().vagasAbertas().first?.id)
        await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) { try await preenchida.candidatar(vagaID: vagaID) }
        await #expect(throws: ErroDaApi(codigo: .inelegivel, detalhes: "turno_sobreposto")) {
            try await ApiClienteEmMemoria(cenario: .inelegivel).candidatar(vagaID: vagaID)
        }
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await ApiClienteEmMemoria(cenario: .semRede).funcoes() }
        await #expect(throws: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa")) {
            try await ApiClienteEmMemoria(cenario: .contaSuspensa).funcoes()
        }
    }

    private static func criarVagasDeTeste() throws -> [Vaga] {
        let base = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))

        var resultado: [Vaga] = []
        for i in 1...5 {
            let componentes = DateComponents(year: 2026, month: 10, day: i <= 2 ? 1 : 2, hour: 12 + i, minute: 0)
            let inicio = try #require(calendario.date(from: componentes))
            let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400))
            let ponto = try Coordenada(latitude: -15.8121 - Double(i) * 0.05, longitude: -47.8997)
            let vaga = Vaga(
                id: UUID(), estabelecimento: base.estabelecimento, funcao: base.funcao, periodo: periodo,
                local: base.local, ponto: ponto, distanciaKm: Double(i), valor: base.valor,
                posicoes: 1, posicoesAbertas: 1, inclusos: base.inclusos,
                responsavelLocal: base.responsavelLocal, traje: base.traje,
                participaRateio: base.participaRateio, observacoes: base.observacoes,
                modo: base.modo, estado: .publicada, publicadoEm: inicio.addingTimeInterval(-86_400)
            )
            resultado.append(vaga)
        }
        return resultado
    }

    @Test("vagasAbertas respeita o filtro de data no fuso de São Paulo")
    func vagasAbertasFiltroData() async throws {
        let vagas = try Self.criarVagasDeTeste()
        let api = ApiClienteEmMemoria(vagas: vagas)

        let dia1 = try await api.vagasAbertas(FiltroVagas(data: try DataCivil("2026-10-01")))
        #expect(dia1.count == 2)
        #expect(dia1.map(\.id) == [vagas[0].id, vagas[1].id])

        let dia2 = try await api.vagasAbertas(FiltroVagas(data: try DataCivil("2026-10-02")))
        #expect(dia2.count == 3)
        #expect(dia2.map(\.id) == [vagas[2].id, vagas[3].id, vagas[4].id])

        let diaSemVagas = try await api.vagasAbertas(FiltroVagas(data: try DataCivil("2026-10-03")))
        #expect(diaSemVagas.isEmpty)

        let todas = try await api.vagasAbertas(.todas)
        #expect(todas.count == 5)
    }

    @Test("vagasAbertas respeita limite e deslocamento na paginação")
    func vagasAbertasPaginacao() async throws {
        let vagas = try Self.criarVagasDeTeste()
        let api = ApiClienteEmMemoria(vagas: vagas)

        let pagina1 = try await api.vagasAbertas(FiltroVagas(limite: 2, deslocamento: 0))
        #expect(pagina1.count == 2)
        #expect(pagina1.map(\.id) == [vagas[0].id, vagas[1].id])

        let pagina2 = try await api.vagasAbertas(FiltroVagas(limite: 2, deslocamento: 2))
        #expect(pagina2.count == 2)
        #expect(pagina2.map(\.id) == [vagas[2].id, vagas[3].id])

        let pagina3 = try await api.vagasAbertas(FiltroVagas(limite: 2, deslocamento: 4))
        #expect(pagina3.count == 1)
        #expect(pagina3.map(\.id) == [vagas[4].id])

        let paginaAlem = try await api.vagasAbertas(FiltroVagas(limite: 2, deslocamento: 5))
        #expect(paginaAlem.isEmpty)

        let deslocamentoMuitoGrande = try await api.vagasAbertas(FiltroVagas(limite: 2, deslocamento: 50))
        #expect(deslocamentoMuitoGrande.isEmpty)
    }

    @Test("vagasAbertas valida limites fora de 1..100 e deslocamento negativo")
    func vagasAbertasValidacaoParametros() async throws {
        let api = ApiClienteEmMemoria()

        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "limite")) {
            try await api.vagasAbertas(FiltroVagas(limite: 0))
        }

        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "limite")) {
            try await api.vagasAbertas(FiltroVagas(limite: 101))
        }

        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "deslocamento")) {
            try await api.vagasAbertas(FiltroVagas(deslocamento: -1))
        }
    }
}
