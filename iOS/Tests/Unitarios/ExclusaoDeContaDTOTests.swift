import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("DTOs de Exclusão de Conta (LGPD RF25, RN15)")
struct ExclusaoDeContaDTOTests {

    // MARK: - RequisicaoExclusaoConta

    @Test("RequisicaoExclusaoConta: init padrão define confirmar = true")
    func requisicaoPadraoConfirma() {
        let req = RequisicaoExclusaoConta()
        #expect(req.confirmar == true)
    }

    @Test("RequisicaoExclusaoConta: serializa corpo JSON exato {'confirmar': true} conforme OpenAPI")
    func requisicaoSerializaCorpoExatoConformeOpenAPI() throws {
        let req = RequisicaoExclusaoConta()
        let dados = try JSONEncoder().encode(req)
        let objeto = try JSONSerialization.jsonObject(with: dados) as? [String: Any]
        #expect(objeto?.count == 1)
        #expect(objeto?["confirmar"] as? Bool == true)

        let jsonTexto = String(decoding: dados, as: UTF8.self)
        #expect(jsonTexto == "{\"confirmar\":true}")
    }

    // MARK: - DTOExclusaoDeConta

    @Test("DTOExclusaoDeConta: decodifica payload canônico com ContratoAPI.decodificador()")
    func decodificaPayloadCanonico() throws {
        let json = """
        {
            "perfil_removido_em": "2026-10-17T20:30:00Z",
            "dados_apagados_ate": "2026-11-01",
            "turnos_cancelados": 4
        }
        """
        let decoder = ContratoAPI.decodificador()
        let dto = try decoder.decode(DTOExclusaoDeConta.self, from: Data(json.utf8))

        #expect(dto.turnos_cancelados == 4)
        #expect(dto.dados_apagados_ate == "2026-11-01")

        let dominio = try dto.dominio()
        #expect(dominio.turnosCancelados == 4)
        #expect(dominio.dadosApagadosAte.contrato == "2026-11-01")
        #expect(dominio.dadosApagadosAte.ano == 2026)
        #expect(dominio.dadosApagadosAte.mes == 11)
        #expect(dominio.dadosApagadosAte.dia == 1)
        #expect(dominio.perfilRemovidoEm == Date(timeIntervalSince1970: 1_792_269_000))
    }

    @Test("DTOExclusaoDeConta: decodifica payload com milissegundos (.123Z do toISOString da Edge Function)")
    func decodificaPayloadComMilissegundos() throws {
        let json = """
        {
            "perfil_removido_em": "2026-10-17T20:30:00.123Z",
            "dados_apagados_ate": "2026-11-01",
            "turnos_cancelados": 2
        }
        """
        let decoder = ContratoAPI.decodificador()
        let dto = try decoder.decode(DTOExclusaoDeConta.self, from: Data(json.utf8))

        #expect(dto.turnos_cancelados == 2)
        #expect(dto.dados_apagados_ate == "2026-11-01")

        let dominio = try dto.dominio()
        #expect(dominio.turnosCancelados == 2)
        #expect(dominio.dadosApagadosAte.contrato == "2026-11-01")
        #expect(abs(dominio.perfilRemovidoEm.timeIntervalSince1970 - 1_792_269_000.123) < 0.001)
    }

    @Test("DTOExclusaoDeConta: dominio() lança ErroDeConversao quando dados_apagados_ate não é data civil ISO")
    func rejeitaDataCivilInvalida() throws {
        let json = """
        {
            "perfil_removido_em": "2026-10-17T20:30:00Z",
            "dados_apagados_ate": "data_corrompida",
            "turnos_cancelados": 0
        }
        """
        let decoder = ContratoAPI.decodificador()
        let dto = try decoder.decode(DTOExclusaoDeConta.self, from: Data(json.utf8))

        #expect(throws: ErroDeConversao(campo: "dados_apagados_ate")) {
            try dto.dominio()
        }
    }

    @Test("DTOExclusaoDeConta: dominio() rejeita formato com barras DD/MM/AAAA")
    func rejeitaFormatoComBarras() throws {
        let json = """
        {
            "perfil_removido_em": "2026-10-17T20:30:00Z",
            "dados_apagados_ate": "01/11/2026",
            "turnos_cancelados": 0
        }
        """
        let decoder = ContratoAPI.decodificador()
        let dto = try decoder.decode(DTOExclusaoDeConta.self, from: Data(json.utf8))

        #expect(throws: ErroDeConversao(campo: "dados_apagados_ate")) {
            try dto.dominio()
        }
    }

    @Test("DTOExclusaoDeConta: init manual preserva campos e mapeia para domínio com turnosCancelados == 0")
    func initManualContaSemTurnos() throws {
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = DTOExclusaoDeConta(
            perfil_removido_em: instante,
            dados_apagados_ate: "2027-01-15",
            turnos_cancelados: 0
        )

        let dominio = try dto.dominio()
        #expect(dominio.perfilRemovidoEm == instante)
        #expect(dominio.dadosApagadosAte.contrato == "2027-01-15")
        #expect(dominio.turnosCancelados == 0)
    }
}
