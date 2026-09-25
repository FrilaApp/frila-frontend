@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

@Suite("Contrato 0.2.11")
struct ContratoTests {
    static func objeto(_ valor: some Encodable) throws -> NSDictionary {
        let dados = try JSONEncoder().encode(valor)
        return try #require(JSONSerialization.jsonObject(with: dados) as? NSDictionary)
    }

    static func fixture(_ nome: String) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: FixturesDoContrato.dados(nome)) as? NSDictionary)
    }

    @Test("As fixtures declaram a versão do contrato espelhado")
    func versao() throws {
        struct Versao: Decodable { let version: String }
        #expect(try FixturesDoContrato.carregar("contract-version", como: Versao.self).version == "0.2.11")
    }

    @Test("Conta, perfil e estabelecimento do contrato viram domínio")
    func contaEPerfil() throws {
        let conta = try FixturesDoContrato.carregar("usuario", como: ContratoAPI.UsuarioDTO.self).dominio()
        #expect(try conta.nascimento == DataCivil("1998-04-12"))
        #expect(conta.estado == .ativa)

        let perfil = try FixturesDoContrato.carregar("perfil-profissional", como: ContratoAPI.PerfilProfissionalDTO.self).dominio()
        #expect(perfil.usuarioID == conta.id)
        let todasViramANoite = perfil.disponibilidades.allSatisfy(\.atravessaMeiaNoite)
        #expect(todasViramANoite)
        #expect(perfil.reputacao.turnosRealizados == 7)

        let publico = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
        #expect(publico.tipo == .profissional)

        _ = try FixturesDoContrato.carregar("estabelecimento", como: ContratoAPI.EstabelecimentoDTO.self).dominio()
        let casas = try FixturesDoContrato.carregar("meus-estabelecimentos", como: [ContratoAPI.EstabelecimentoDaContaDTO].self)
        #expect(casas.map { $0.dominio().papel } == [.administrador])
    }

    @Test("Vagas, candidatura e turno do contrato viram domínio")
    func vagasETurno() throws {
        let vaga = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
        #expect(vaga.estabelecimento.tipo == .estabelecimento)
        #expect(vaga.traje != nil && vaga.observacoes == nil)

        let lista = try FixturesDoContrato.carregar("vagas-abertas", como: [ContratoAPI.VagaNaListaDTO].self).map { try $0.dominio() }
        #expect(lista.first?.id == vaga.id)

        let publicada = try FixturesDoContrato.carregar("vaga-publicada", como: ContratoAPI.VagaPublicadaDTO.self).dominio()
        #expect(publicada.posicoes.count == vaga.posicoes)

        let urgencia = try FixturesDoContrato.carregar("candidatura-urgencia", como: ContratoAPI.CandidaturaDTO.self).dominio()
        #expect(urgencia.estado == .confirmada && urgencia.contato != nil)
        let selecao = try FixturesDoContrato.carregar("candidatura-selecao", como: ContratoAPI.CandidaturaDTO.self).dominio()
        #expect(selecao.estado == .pendente && selecao.turnoID == nil && selecao.contato == nil)

        let turno = try #require(try FixturesDoContrato.carregar("turnos", como: [ContratoAPI.TurnoDTO].self).first?.dominio())
        #expect(turno.checkin?.tipo == .geolocalizado)
        #expect(turno.checkin?.distanciaMetros == 38)
        #expect(turno.checkout == nil)
        #expect(turno.contato == nil)
        #expect(turno.vaga.id == vaga.id)

        let contato = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
        #expect(contato.visivelAte == turno.contatoVisivelAte)
    }

    @Test("Painel, registro, avaliação e configuração do contrato viram domínio")
    func painelEOutros() throws {
        let painel = try FixturesDoContrato.carregar("painel", como: ContratoAPI.PainelDTO.self).dominio()
        let posicoes = try #require(painel.vagas.first?.posicoes)
        #expect(posicoes.map(\.estado) == [.confirmada, .aberta])
        #expect(posicoes.last?.profissional == nil)

        let registro = try FixturesDoContrato.carregar("resultado-registro", como: ContratoAPI.ResultadoRegistroDTO.self).dominio()
        #expect(registro.verificacao == .verificado)
        _ = try FixturesDoContrato.carregar("avaliacao", como: ContratoAPI.AvaliacaoDTO.self).dominio()

        let configuracao = try FixturesDoContrato.carregar("configuracao-do-app", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
        #expect(configuracao.versaoMinima == "0.1.0")
    }

    @Test("Todo erro de erros.json tem código conhecido pelo app")
    func erros() throws {
        let envelopes = try FixturesDoContrato.carregar("erros", como: [EnvelopeErroAPI].self)
        let desconhecidos = envelopes.filter { DecodificadorErroAPI.mapear(codigo: $0.code, detalhes: $0.details).codigo == .desconhecido }
        #expect(desconhecidos.map(\.code) == [])
    }

    @Test("criar_conta manda termos_versao e nenhuma data de aceite")
    func criarConta() throws {
        let cadastro = CadastroConta(nome: "Ana Cunha", telefone: "+5561988887777", nascimento: try DataCivil("1998-04-12"), perfil: .profissional, versaoTermos: "2026-09-22")
        #expect(try Self.objeto(ContratoAPI.CriarConta(cadastro)) == Self.fixture("requisicao-criar-conta"))
    }

    @Test("Perfil profissional sai no formato do contrato, com janela que atravessa a meia-noite")
    func perfilProfissional() throws {
        let garcom = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        let bartender = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        let noite = { (dia: Int) throws in JanelaDeDisponibilidade(diaDaSemana: dia, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00")) }
        let dados = DadosPerfilProfissional(funcoes: [garcom], pontoBase: try Coordenada(latitude: -15.8267, longitude: -47.9218), disponibilidades: [try noite(5), try noite(6)])
        #expect(try Self.objeto(ContratoAPI.DadosPerfilProfissionalDTO(dados)) == Self.fixture("requisicao-criar-perfil-profissional"))

        let alteracao = AlteracaoPerfilProfissional(funcoes: [garcom, bartender])
        #expect(try Self.objeto(ContratoAPI.AlteracaoPerfilProfissionalDTO(alteracao)) == Self.fixture("requisicao-atualizar-perfil-profissional"))
    }

    @Test("Cadastro do estabelecimento e publicação da vaga saem no formato do contrato")
    func estabelecimentoEVaga() throws {
        let ponto = try Coordenada(latitude: -15.8121, longitude: -47.8997)
        let endereco = "CLS 405, Asa Sul, Brasília - DF"
        let cadastro = CadastroEstabelecimento(nome: "Bistrô Ipê", documento: "12345678000190", tipo: .foodService, endereco: endereco, ponto: ponto)
        #expect(try Self.objeto(ContratoAPI.CadastroEstabelecimentoDTO(cadastro)) == Self.fixture("requisicao-cadastrar-estabelecimento"))

        let inicio = Date(timeIntervalSince1970: 1_791_579_600)
        let publicacao = PublicacaoVaga(
            estabelecimentoID: try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000001")),
            funcaoID: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001")),
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)),
            local: endereco, ponto: ponto, valor: Dinheiro(centavos: 12000), posicoes: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", traje: "Camisa preta e calça escura", participaRateio: true,
            chave: try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000001"))
        )
        #expect(try Self.objeto(ContratoAPI.NovaVaga(publicacao)) == Self.fixture("requisicao-publicar-vaga"))
    }

    @Test("Registro de presença manda distancia_m nulo, e avaliar não manda chave")
    func presencaEAvaliacao() throws {
        let turno = try #require(UUID(uuidString: "60000000-0000-0000-0000-000000000001"))
        let presenca = ContratoAPI.RegistroDePresenca(turnoID: turno, distanciaMetros: nil, registradoEm: ContratoAPI.texto(Date(timeIntervalSince1970: 1_791_579_151)))
        #expect(try Self.objeto(presenca) == Self.fixture("requisicao-registro-de-presenca"))
        #expect(try Self.objeto(ContratoAPI.Avaliar(turnoID: turno, resposta: true)) == Self.fixture("requisicao-avaliar"))
    }

    @Test("Instantes do Postgres, com fração de segundo e offset, chegam iguais", arguments: [
        "2026-10-09T21:00:00Z", "2026-10-09T21:00:00+00:00", "2026-10-09T21:00:00.000+00:00",
        "2026-10-09T21:00:00.000000Z", "2026-10-09T18:00:00-03:00",
    ])
    func instantes(texto: String) {
        #expect(ContratoAPI.instante(texto) == Date(timeIntervalSince1970: 1_791_579_600))
    }

    @Test("Valor fora do domínio vira erro de conversão, nunca queda do app")
    func conversao() throws {
        let janela = Data(#"{"dia_semana":7,"hora_inicio":"18:00","hora_fim":"02:00"}"#.utf8)
        #expect(throws: ErroDeConversao(campo: "dia_semana")) {
            try ContratoAPI.decodificador().decode(ContratoAPI.JanelaDTO.self, from: janela).dominio()
        }
        let usuario = Data(#"{"id":"10000000-0000-0000-0000-000000000001","perfil":"profissional","nome":"Ana","telefone":"+5561988887777","email":"ana@frila.app","nascimento":"1998-02-30","estado":"ativa"}"#.utf8)
        #expect(throws: ErroDeConversao(campo: "nascimento")) {
            try ContratoAPI.decodificador().decode(ContratoAPI.UsuarioDTO.self, from: usuario).dominio()
        }
    }
}
