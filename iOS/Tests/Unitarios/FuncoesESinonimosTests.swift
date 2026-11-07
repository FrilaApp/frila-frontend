import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@Suite("I1 · Funções novas e sinônimos no catálogo (Fatia F1)")
struct FuncoesESinonimosTests {
    private let decoder = JSONDecoder()

    @Test("Funcao decodifica aditivamente campos de 0.2.52 e tolera ausência deles (0.2.51)")
    func decodificacaoAditiva() throws {
        let jsonLegado = """
        {
            "id": "20000000-0000-0000-0000-000000000001",
            "nome": "Garçom",
            "categoria": "Salão"
        }
        """.data(using: .utf8)!

        let funcaoLegada = try decoder.decode(Funcao.self, from: jsonLegado)
        #expect(funcaoLegada.id == UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        #expect(funcaoLegada.nome == "Garçom")
        #expect(funcaoLegada.categoria == "Salão")
        #expect(funcaoLegada.formatoPadrao == nil)
        #expect(funcaoLegada.grupoBusca == nil)
        #expect(funcaoLegada.dicaPerfil == nil)
        #expect(funcaoLegada.exemploPerfil == nil)

        let jsonNovo = """
        {
            "id": "20000000-0000-0000-0000-000000000031",
            "nome": "Faxina residencial",
            "categoria": "Casa",
            "formato_padrao": "servico",
            "grupo_busca": "faxina",
            "dica_perfil": "Conte sua experiência com limpeza.",
            "exemplo_perfil": "Faço faxina residencial completa."
        }
        """.data(using: .utf8)!

        let funcaoNova = try decoder.decode(Funcao.self, from: jsonNovo)
        #expect(funcaoNova.id == UUID(uuidString: "20000000-0000-0000-0000-000000000031"))
        #expect(funcaoNova.nome == "Faxina residencial")
        #expect(funcaoNova.categoria == "Casa")
        #expect(funcaoNova.formatoPadrao == .servico)
        #expect(funcaoNova.grupoBusca == "faxina")
        #expect(funcaoNova.dicaPerfil == "Conte sua experiência com limpeza.")
        #expect(funcaoNova.exemploPerfil == "Faço faxina residencial completa.")
    }

    @Test("RegiaoAdministrativa decodifica conforme catálogo oficial")
    func decodificacaoRegiaoAdministrativa() throws {
        let json = """
        {
            "id": 1,
            "numero": "I",
            "nome": "Plano Piloto",
            "ativo": true
        }
        """.data(using: .utf8)!

        let ra = try decoder.decode(RegiaoAdministrativa.self, from: json)
        #expect(ra.id == 1)
        #expect(ra.numero == "I")
        #expect(ra.nome == "Plano Piloto")
        #expect(ra.ativo == true)
    }

    @Test("resolverServico devolve função canônica ao buscar por sinônimo conhecido sem duplicar")
    func resolverServicoComSinonimos() async throws {
        let api = ApiClienteEmMemoria()
        let funcoes = try await api.funcoes()

        // Garante que o catálogo em memória possui as novas funções
        #expect(funcoes.contains { $0.nome == "Faxina residencial" && $0.categoria == "Casa" })
        #expect(funcoes.contains { $0.nome == "Churrasqueiro" && $0.categoria == "Festa e eventos sociais" })

        // "diarista" -> Faxina residencial
        let resultadoDiarista = try await api.resolverServico(termo: "diarista")
        #expect(!resultadoDiarista.isEmpty)
        #expect(resultadoDiarista.first?.nome == "Faxina residencial")
        #expect(resultadoDiarista.first?.categoria == "Casa")

        // "faxineira" -> Faxina residencial
        let resultadoFaxineira = try await api.resolverServico(termo: "faxineira")
        #expect(resultadoFaxineira.first?.nome == "Faxina residencial")

        // "churrasqueira" -> Churrasqueiro
        let resultadoChurrasqueira = try await api.resolverServico(termo: "churrasqueira")
        #expect(resultadoChurrasqueira.first?.nome == "Churrasqueiro")
        #expect(resultadoChurrasqueira.first?.categoria == "Festa e eventos sociais")

        // Não há duplicatas de ID
        let idsDiarista = resultadoDiarista.map(\.id)
        #expect(Set(idsDiarista).count == idsDiarista.count)
    }

    @Test("resolverServico com menos de 2 caracteres acusa termo inválido")
    func resolverServicoTermoCurto() async throws {
        let api = ApiClienteEmMemoria()
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.resolverServico(termo: "a")
        }
    }

    @Test("resolverServico com termo sem correspondência retorna lista vazia")
    func resolverServicoSemCorrespondencia() async throws {
        let api = ApiClienteEmMemoria()
        let resultado = try await api.resolverServico(termo: "astronauta")
        #expect(resultado.isEmpty)
    }

    @Test("OrganizacaoDeFuncoes.agrupar traz a categoria e função canônica ao buscar por sinônimo")
    func agruparComSinonimos() async throws {
        let api = ApiClienteEmMemoria()
        let todas = try await api.funcoes()

        let grupos = OrganizacaoDeFuncoes.agrupar(todas, busca: "diarista", categoriaVazia: "Outras")
        #expect(!grupos.isEmpty)
        let grupoCasa = try #require(grupos.first { $0.categoria == "Casa" })
        #expect(grupoCasa.funcoes.contains { $0.nome == "Faxina residencial" })

        // Termo inexistente retorna nenhum grupo
        let vazio = OrganizacaoDeFuncoes.agrupar(todas, busca: "astronauta", categoriaVazia: "Outras")
        #expect(vazio.isEmpty)
    }

    @Test("FrilaRoleCatalog.match resolve sinônimos canônicos para a função do catálogo")
    func catalogoMatchSinonimos() {
        let papelDiarista = FrilaRoleCatalog.match("diarista")
        #expect(papelDiarista?.name == "Faxina residencial")

        let papelChurrasco = FrilaRoleCatalog.match("churrasco")
        #expect(papelChurrasco?.name == "Churrasqueiro")

        let papelInexistente = FrilaRoleCatalog.match("astronauta")
        #expect(papelInexistente == nil)
    }

    @MainActor
    @Test("Casa servico_domestico publica vaga normal de Faxina residencial com funcao_id do catálogo")
    func publicacaoVagaNormalCasa() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let funcoes = try await api.funcoes()
        let funcaoFaxina = try #require(funcoes.first { $0.nome == "Faxina residencial" })

        let agoraFixo = Date(timeIntervalSince1970: 1_800_000_000)
        let resumo = try #require(try await api.meusEstabelecimentos().first)
        let casaExistente = try await api.meuEstabelecimento(id: resumo.id)
        let casa = Estabelecimento(
            id: casaExistente.id,
            nome: "Residência Família Silva",
            tipo: .servicoDomestico,
            endereco: casaExistente.endereco,
            regiaoAdministrativa: casaExistente.regiaoAdministrativa,
            ponto: casaExistente.ponto
        )

        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let vagaVM = PublicarVagaViewModel(
            estabelecimento: casa,
            funcoes: funcoes,
            fila: fila,
            agora: { agoraFixo },
            publicar: { try await api.publicarVaga($0) }
        )
        vagaVM.funcaoID = funcaoFaxina.id
        vagaVM.valorTexto = "18000"
        vagaVM.posicoesTexto = "1"
        vagaVM.responsavelLocal = "Mariana"
        vagaVM.inicio = agoraFixo.addingTimeInterval(4 * 3600)
        vagaVM.fim = vagaVM.inicio.addingTimeInterval(8 * 3600)

        #expect(vagaVM.validar())
        await vagaVM.publicar()

        let resultado = try #require(vagaVM.resultado)
        #expect(resultado.posicoes.count == 1)
        #expect(vagaVM.mensagemErro == nil)
    }

    @MainActor
    @Test("Termo sem correspondência como custom role não preenche funcaoID e impede avanço na publicação")
    func termoSemCorrespondenciaNaoPublica() async throws {
        let api = ApiClienteEmMemoria()
        let funcoes = try await api.funcoes()

        let agoraFixo = Date(timeIntervalSince1970: 1_800_000_000)
        let casa = Estabelecimento(
            id: UUID(),
            nome: "Casa Teste",
            tipo: .servicoDomestico,
            endereco: "Rua 1, Lago Sul",
            regiaoAdministrativa: "Lago Sul",
            ponto: try Coordenada(latitude: -15.83, longitude: -47.85)
        )

        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let vagaVM = PublicarVagaViewModel(api: api, fila: fila, estabelecimento: casa, agora: { agoraFixo })
        vagaVM.funcoes = funcoes
        let formulario = FormularioEstudioDeVaga(vaga: vagaVM, agora: { agoraFixo })

        var rascunho = formulario.rascunhoInicial
        rascunho.role = "Astronauta"
        rascunho.roleOrigin = .custom
        rascunho.payPerPosition = 200
        rascunho.positionsCount = 1
        rascunho.contactPerson = "Responsável"

        formulario.aplicar(rascunho)
        #expect(vagaVM.funcaoID == nil)
        #expect(!vagaVM.validar())
        #expect(vagaVM.erros[.funcao] != nil)
    }
}
