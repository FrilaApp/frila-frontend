@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// `publicar_escala` (0.2.96) no formato do contrato: o pedido que o app monta e a resposta que ele lê.
@Suite("Contrato da escala de evento (publicar_escala, 0.2.96)")
struct ContratoDaEscalaTests {
    static func pedido() throws -> PublicacaoEscala {
        let garcom = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        let bartender = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        let semInclusos = Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false)
        let primeira = VagaDaEscala(
            funcaoID: garcom,
            periodo: try Periodo(inicio: try #require(ContratoAPI.instante("2026-12-12T21:00:00Z")), fim: try #require(ContratoAPI.instante("2026-12-13T02:00:00Z"))),
            valor: Dinheiro(centavos: 16_000), posicoes: 6, inclusos: semInclusos, responsavelLocal: "Marina"
        )
        let segunda = VagaDaEscala(
            funcaoID: bartender,
            periodo: try Periodo(inicio: try #require(ContratoAPI.instante("2026-12-12T20:00:00Z")), fim: try #require(ContratoAPI.instante("2026-12-13T02:00:00Z"))),
            valor: Dinheiro(centavos: 18_000), posicoes: 2, inclusos: semInclusos, responsavelLocal: "Marina"
        )
        return PublicacaoEscala(
            estabelecimentoID: try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000001")),
            evento: EventoDaEscala(
                nome: "Formatura de Direito", data: try DataCivil("2026-12-12"), local: "CLS 405, Asa Sul, Brasília - DF",
                regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
            ),
            vagas: [primeira, segunda],
            chave: try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000002"))
        )
    }

    @Test("O pedido sai com o evento, o dia de Brasília, as vagas e a chave, igual à requisição do contrato")
    func pedidoNoFormatoDoContrato() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.NovaEscala(Self.pedido())) == ContratoTests.fixture("requisicao-publicar-escala"))
    }

    @Test("Campos opcionais que a casa não preencheu não saem no pedido, e os que ela preencheu saem")
    func opcionais() throws {
        let base = try Self.pedido()
        let completa = VagaDaEscala(
            funcaoID: base.vagas[0].funcaoID, periodo: base.vagas[0].periodo, valor: base.vagas[0].valor, posicoes: 1,
            inclusos: base.vagas[0].inclusos, responsavelLocal: "Marina", traje: "Camisa preta", participaRateio: true,
            observacoes: "Entrada pela lateral", modo: .selecao, alertaAntecedenciaMinutos: 120
        )
        let corpo = try ContratoTests.objeto(ContratoAPI.NovaEscala(PublicacaoEscala(
            estabelecimentoID: base.estabelecimentoID, evento: base.evento, vagas: [base.vagas[0], completa], chave: base.chave
        )))
        let itens = try #require(corpo["vagas"] as? [NSDictionary])

        #expect(itens[0]["traje"] == nil && itens[0]["observacoes"] == nil && itens[0]["alerta_antecedencia_min"] == nil)
        #expect(itens[0]["participa_rateio"] == nil, "o rateio sai nulo (omitido), como na web e no Android")
        #expect(itens[1]["traje"] as? String == "Camisa preta")
        #expect(itens[1]["observacoes"] as? String == "Entrada pela lateral")
        #expect(itens[1]["modo"] as? String == "selecao")
        #expect(itens[1]["alerta_antecedencia_min"] as? Int == 120)
        #expect(itens[1]["participa_rateio"] as? Bool == true)
    }

    @Test("A resposta traz o evento e uma vaga publicada por item, na ordem do pedido")
    func respostaDoContrato() throws {
        let escala = try FixturesDoContrato.carregar("escala-publicada", como: ContratoAPI.EscalaPublicadaDTO.self).dominio()

        #expect(escala.eventoID == UUID(uuidString: "70000000-0000-0000-0000-000000000001"))
        #expect(escala.vagas.count == 2)
        #expect(escala.vagas[0].vagaID == UUID(uuidString: "40000000-0000-0000-0000-000000000011"))
        #expect(escala.vagas.map(\.posicoes.count) == [2, 1])
    }
}
