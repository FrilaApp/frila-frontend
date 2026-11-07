import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Chamada direta: total, J7 e contrato 0.2.55")
@MainActor
struct ChamadaDiretaTests {
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

    private func preparar(_ cenario: ApiClienteEmMemoria.Cenario = .chamadaDireta) async throws
        -> (ApiClienteEmMemoria, ChamadaDiretaViewModel) {
        let api = ApiClienteEmMemoria(cenario: cenario)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let perfil = try await api.perfilPublico(id: profissionalID)
        let model = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id)
        await model.carregar()
        model.funcaoID = try #require(model.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        model.valorCentavos = 25_075
        return (api, model)
    }

    @Test("Sem confirmar o total, nenhuma chamada é enviada; a alteração do valor pede nova confirmação")
    func totalExplicito() async throws {
        let (api, model) = try await preparar()
        #expect(!model.podeEnviar)
        await model.enviar()
        #expect(await api.pedidosChamadaRecebidos.isEmpty)
        model.totalConfirmado = true
        model.valorCentavos += 1
        #expect(!model.totalConfirmado)
        model.totalConfirmado = true
        await model.enviar()
        let pedido = try #require(await api.pedidosChamadaRecebidos.first)
        #expect(pedido.trabalho.valor.centavos == 25_076)
        #expect(!pedido.confirmoRecorrencia)
        #expect(model.resultado?.estado == .aberta)
    }

    @Test("Recado aceita 300 caracteres e recusa 301 antes de chamar a API")
    func limiteRecado() async throws {
        let (api, model) = try await preparar()
        model.totalConfirmado = true
        model.recado = String(repeating: "a", count: 301)
        await model.enviar()
        #expect(await api.pedidosChamadaRecebidos.isEmpty)
        model.recado = String(repeating: "a", count: 300)
        await model.enviar()
        #expect(model.resultado?.recado?.count == 300)
    }

    @Test("J7 não reenvia automaticamente; só a confirmação explícita reenvia os mesmos dados e chave")
    func recorrencia() async throws {
        let (api, model) = try await preparar(.chamadaRecorrente)
        model.totalConfirmado = true
        await model.enviar(confirmoRecorrencia: true)
        #expect(await api.pedidosChamadaRecebidos.isEmpty)
        await model.enviar()
        #expect(model.resultado == nil)
        #expect(model.mostrarJ7)
        #expect(await api.pedidosChamadaRecebidos.count == 1)
        model.mostrarJ7 = false // Cancelamento do diálogo não envia.
        #expect(await api.pedidosChamadaRecebidos.count == 1)
        await model.enviar() // Tentar outra vez sem aceitar ainda é recusa.
        #expect(model.mostrarJ7)
        await model.enviar(confirmoRecorrencia: true)
        let pedidos = await api.pedidosChamadaRecebidos
        #expect(pedidos.count == 3)
        #expect(pedidos[0].trabalho == pedidos[2].trabalho)
        #expect(!pedidos[0].confirmoRecorrencia)
        #expect(pedidos[2].confirmoRecorrencia)
        #expect(model.resultado != nil)
    }

    @Test("Chave repetida devolve a mesma chamada; outra chave para o mesmo par é chamada_ja_aberta")
    func idempotencia() async throws {
        let (api, model) = try await preparar()
        model.totalConfirmado = true
        await model.enviar()
        let pedido = try #require(model.tentativa)
        #expect(try await api.chamarProfissional(pedido) == model.resultado)
        let t = pedido.trabalho
        let outro = PublicacaoVaga(estabelecimentoID: t.estabelecimentoID, funcaoID: t.funcaoID,
            periodo: t.periodo, local: t.local, regiaoAdministrativa: t.regiaoAdministrativa,
            ponto: t.ponto, valor: t.valor, posicoes: 1, inclusos: t.inclusos,
            responsavelLocal: t.responsavelLocal, modo: .urgencia, chave: UUID())
        await #expect(throws: ErroDaApi(codigo: .chamadaJaAberta)) {
            try await api.chamarProfissional(PedidoChamada(profissionalID: profissionalID, trabalho: outro))
        }
        let lista = try await api.vagasAbertas(.todas)
        #expect(!lista.contains { $0.id == model.resultado?.vagaID })
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await api.detalheDaVaga(id: #require(model.resultado).vagaID)
        }
    }

    @Test("Recurso ausente ou desligado não permite enviar e permanece falso no cenário padrão")
    func recursoDesligado() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let model = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id)
        await model.carregar()
        #expect(!model.recursoHabilitado)
        #expect(!model.podeEnviar)
        #expect(try await api.configuracaoDoApp().recursos.chamadaDireta == false)
        let json = #"{"versao_minima":"1.0.0","versao_recomendada":"1.0.0","url_da_loja":"https://apps.apple.com/"}"#
        let dto = try JSONDecoder().decode(ContratoAPI.ConfiguracaoDoAppDTO.self, from: Data(json.utf8))
        #expect(dto.dominio().recursos.chamadaDireta == false)
    }

    @Test("Payload usa os nomes planos de chamar_profissional, centavos inteiros e confirmação J7")
    func payloadContrato() async throws {
        let (_, model) = try await preparar(.chamadaRecorrente)
        model.totalConfirmado = true
        await model.enviar()
        await model.enviar(confirmoRecorrencia: true)
        let pedido = try #require(model.tentativa)
        let dados = try JSONEncoder().encode(ContratoAPI.ChamarProfissional(pedido: pedido))
        let corpo = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])
        #expect(corpo["valor_centavos"] as? Int == 25_075)
        #expect(corpo["confirmo_recorrencia"] as? Bool == true)
        #expect(corpo["profissional_id"] as? String == profissionalID.uuidString)
        #expect(corpo["posicoes"] == nil)
        #expect(corpo["modo"] == nil)
        #expect(corpo["trabalho"] == nil)
        #expect(corpo["inicio_em"] as? String != nil)
        #expect(corpo["ponto"] as? [String: Any] != nil)
    }

    @Test("Vaga de servidor anterior continua decodificando sem origem e preserva os campos quando presentes")
    func origemOpcional() throws {
        let dados = try FixturesDoContrato.dados("vaga")
        let antiga = try ContratoAPI.decodificador().decode(ContratoAPI.VagaDTO.self, from: dados).dominio()
        #expect(antiga.origem == nil)
        var json = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let origemID = UUID()
        json["origem"] = "chamada_direta"
        json["vaga_origem_id"] = origemID.uuidString
        let nova = try ContratoAPI.decodificador().decode(ContratoAPI.VagaDTO.self, from: JSONSerialization.data(withJSONObject: json)).dominio()
        #expect(nova.origem == .chamadaDireta)
        #expect(nova.vagaOrigemId == origemID)
        #expect(nova.resumo.origem == .chamadaDireta)
        let cache = try JSONEncoder().encode(nova.resumo)
        #expect(try JSONDecoder().decode(VagaResumo.self, from: cache).vagaOrigemId == origemID)
    }
}
