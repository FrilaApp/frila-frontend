import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor @Suite("Serviços do profissional — contrato 0.2.53")
struct ServicosDoProfissionalTests {
    private let funcaoID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

    @Test("As seis unidades usam os nomes do contrato")
    func unidades() throws {
        #expect(Set(UnidadePreco.allCases.map(\.rawValue)) == ["hora", "diaria", "evento", "pacote", "por_pessoa", "a_combinar"])
        for unidade in UnidadePreco.allCases {
            #expect(try JSONDecoder().decode(UnidadePreco.self, from: JSONEncoder().encode(unidade)) == unidade)
            var servico = ServicoOferecido(funcaoID: funcaoID, unidade: unidade, valorCentavos: unidade == .aCombinar ? nil : 1000)
            if unidade == .diaria { servico.horasIncluidas = 8 }
            if unidade == .pacote { servico.descricaoPacote = "Serviço completo" }
            if unidade == .porPessoa { servico.minimoPessoas = 10 }
            try servico.validar()
        }
    }

    @Test("Preço aceita os dois limites e recusa centavos fora deles", arguments: [999, 1000, 1000000, 1000001])
    func limites(_ centavos: Int) throws {
        let servico = ServicoOferecido(funcaoID: funcaoID, unidade: .hora, valorCentavos: centavos)
        if (1000...1000000).contains(centavos) { try servico.validar() }
        else { #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "valor_centavos")) { try servico.validar() } }
    }

    @Test("Diária exige de 4 a 12 horas", arguments: [nil, 3, 4, 12, 13] as [Int?])
    func diaria(_ horas: Int?) throws {
        let servico = ServicoOferecido(funcaoID: funcaoID, unidade: .diaria, valorCentavos: 18000, horasIncluidas: horas)
        if let horas, (4...12).contains(horas) { try servico.validar() }
        else { #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "horas_incluidas")) { try servico.validar() } }
    }

    @Test("Campos exigidos, faixas, exclusividade por unidade e limite de texto")
    func condicionais() throws {
        let invalidos: [(ServicoOferecido, String)] = [
            (.init(funcaoID: funcaoID, unidade: .aCombinar, valorCentavos: 1000), "valor_centavos"),
            (.init(funcaoID: funcaoID, unidade: .hora), "valor_centavos"),
            (.init(funcaoID: funcaoID, unidade: .hora, valorCentavos: 2000, valorMaxCentavos: 1000), "valor_max_centavos"),
            (.init(funcaoID: funcaoID, unidade: .evento, valorCentavos: 1000, valorMaxCentavos: 2000), "valor_max_centavos"),
            (.init(funcaoID: funcaoID, unidade: .hora, valorCentavos: 1000, horasIncluidas: 8), "horas_incluidas"),
            (.init(funcaoID: funcaoID, unidade: .evento, valorCentavos: 1000, minimoHoras: 1), "minimo_horas"),
            (.init(funcaoID: funcaoID, unidade: .evento, valorCentavos: 1000, duracaoTipicaH: 25), "duracao_tipica_h"),
            (.init(funcaoID: funcaoID, unidade: .evento, valorCentavos: 1000, atePessoas: 0), "ate_pessoas"),
            (.init(funcaoID: funcaoID, unidade: .pacote, valorCentavos: 1000), "descricao_pacote"),
            (.init(funcaoID: funcaoID, unidade: .porPessoa, valorCentavos: 1000), "minimo_pessoas"),
            (.init(funcaoID: funcaoID, unidade: .aCombinar, itensInclusos: String(repeating: "a", count: 301)), "inclui")
        ]
        for (servico, campo) in invalidos {
            #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: campo)) { try servico.validar() }
        }
    }

    @Test("Preço digitado em reais vira centavos exatos e não arredonda entradas inválidas")
    func moeda() throws {
        #expect(try ServicoEmEdicao.centavos("10,01") == 1001)
        #expect(try ServicoEmEdicao.centavos("10000") == 1000000)
        #expect(try ServicoEmEdicao.centavos("") == nil)
        for texto in ["1,001", "10.99", "abc", "-10", "10000000000000000000"] {
            #expect(throws: ErroDaApi.self) { try ServicoEmEdicao.centavos(texto) }
        }
    }

    @Test("DTO codifica inclui e decodifica serviços do objeto de perfil retornado pela RPC")
    func dto() throws {
        let servico = ServicoOferecido(funcaoID: funcaoID, unidade: .pacote, valorCentavos: 12345, descricaoPacote: "Pacote", itensInclusos: "Montagem")
        let dados = try JSONEncoder().encode(ContratoAPI.ServicoOferecidoDTO(servico))
        let objeto = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])
        #expect(objeto["inclui"] as? String == "Montagem")
        #expect(objeto["valor_centavos"] as? Int == 12345)
        #expect(objeto["descricao_pacote"] as? String == "Pacote")
        let resposta = Data(#"{"servicos":[{"funcao":{"id":"20000000-0000-0000-0000-000000000001","nome":"Garçom","categoria":"Salão"},"unidade":"diaria","valor_centavos":18000,"horas_incluidas":8,"especialidades":[] }]}"#.utf8)
        let perfil = try JSONDecoder().decode(ContratoAPI.ServicosDoPerfil.self, from: resposta)
        #expect(perfil.servicos.first?.dominio().servico.horasIncluidas == 8)
    }

    @Test("Dublê substitui e limpa serviços, valida função e especialidades sem gravação parcial")
    func substituicaoEEspecialidades() async throws {
        let api = ApiClienteEmMemoria()
        let ativas = try await api.especialidades(funcaoID: funcaoID)
        #expect(ativas.count == 9)
        let oito = Array(ativas.prefix(8).map(\.id))
        let servico = ServicoOferecido(funcaoID: funcaoID, unidade: .aCombinar, especialidadeIDs: oito)
        #expect(try await api.definirServicos([servico]).first?.especialidades.count == 8)
        for ids in [ativas.map(\.id), [oito[0], oito[0]], [UUID()]] {
            var invalido = servico; invalido.especialidadeIDs = ids
            await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "especialidade_ids")) { try await api.definirServicos([invalido]) }
        }
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "servicos")) { try await api.definirServicos([servico, servico]) }
        let outraFuncao = UUID()
        await #expect(throws: ErroDaApi(codigo: .funcaoNaoMarcada, detalhes: outraFuncao.uuidString)) {
            try await api.definirServicos([servico, .init(funcaoID: outraFuncao, unidade: .aCombinar)])
        }
        #expect(try await api.meusServicos().first?.servico == servico)
        #expect(try await api.definirServicos([]).isEmpty)
        #expect(try await api.meusServicos().isEmpty)
    }

    @Test("Editor pré-carrega, salva e relê centavos; a combinar dispensa preço")
    func editar() async throws {
        let api = ApiClienteEmMemoria()
        let vm = ServicosDoProfissionalViewModel(api: api)
        await vm.carregar()
        #expect(vm.rascunhos.first?.dados.horasIncluidas == 8)
        vm.rascunhos[0].valor = "195,50"
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(try await api.meusServicos().first?.servico.valorCentavos == 19550)
        vm.rascunhos[0].dados.unidade = .aCombinar; vm.rascunhos[0].trocarUnidade()
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(try await api.meusServicos().first?.servico.valorCentavos == nil)
    }

    @Test("Recusa do servidor preserva rascunho e identifica o campo; sem rede não mostra sucesso",
          arguments: [ApiClienteEmMemoria.Cenario.servicosInclusosRecusados, .servicosSemRede])
    func falhaPreservaRascunho(_ cenario: ApiClienteEmMemoria.Cenario) async throws {
        let vm = ServicosDoProfissionalViewModel(api: ApiClienteEmMemoria(cenario: cenario))
        await vm.carregar()
        vm.rascunhos[0].dados.itensInclusos = "Texto sintético para recusa"
        let antes = vm.rascunhos
        await vm.salvar()
        #expect(!vm.sucesso && !vm.salvando)
        #expect(vm.rascunhos == antes)
        #expect(vm.erro?.codigo == (cenario == .servicosSemRede ? .semRede : .campoInvalido))
        #expect(vm.erro?.detalhes == (cenario == .servicosSemRede ? nil : "inclui"))
    }
}
