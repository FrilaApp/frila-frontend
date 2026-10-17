import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Modelos de Cache e Fila de Ações")
struct CacheModelosTests {

    // MARK: - OrigemDosTurnos e LeituraDeTurnos

    @Test("OrigemDosTurnos diferencia rede e cache")
    func origemDosTurnosDiferenciacao() {
        #expect(OrigemDosTurnos.rede == .rede)
        #expect(OrigemDosTurnos.cache == .cache)
        #expect(OrigemDosTurnos.rede != .cache)
    }

    @Test("LeituraDeTurnos preserva lista e origem com igualdade estrutural")
    func leituraDeTurnosIgualdade() {
        let leituraRedeVazia = LeituraDeTurnos(turnos: [], origem: .rede)
        let leituraCacheVazia = LeituraDeTurnos(turnos: [], origem: .cache)

        #expect(leituraRedeVazia.turnos.isEmpty)
        #expect(leituraRedeVazia.origem == .rede)
        #expect(leituraCacheVazia.origem == .cache)
        #expect(leituraRedeVazia != leituraCacheVazia)
    }

    // MARK: - TipoAcaoPendente

    @Test("TipoAcaoPendente possui todos os 7 casos esperados pelo ciclo de vida offline")
    func tipoAcaoPendenteCasos() throws {
        let esperados: Set<String> = [
            "checkin", "checkout", "avaliacao",
            "publicacaoVaga", "republicacaoVaga",
            "cancelamentoPosicao", "cancelamentoVaga"
        ]

        let obtidos = Set(TipoAcaoPendente.allCases.map(\.rawValue))
        #expect(obtidos == esperados)
        #expect(TipoAcaoPendente.allCases.count == 7)

        for tipo in TipoAcaoPendente.allCases {
            let data = try JSONEncoder().encode(tipo)
            let decodificado = try JSONDecoder().decode(TipoAcaoPendente.self, from: data)
            #expect(decodificado == tipo)
        }
    }

    // MARK: - RepublicacaoVaga

    @Test("RepublicacaoVaga preserva vagaID e periodo em roundtrip Codable")
    func republicacaoVagaCodable() throws {
        let vagaID = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let inicio = Date(timeIntervalSince1970: 1_790_000_000)
        let fim = Date(timeIntervalSince1970: 1_790_014_400)
        let periodo = try Periodo(inicio: inicio, fim: fim)

        let republicacao = RepublicacaoVaga(vagaID: vagaID, periodo: periodo)
        let data = try JSONEncoder().encode(republicacao)
        let decodificado = try JSONDecoder().decode(RepublicacaoVaga.self, from: data)

        #expect(decodificado == republicacao)
        #expect(decodificado.vagaID == vagaID)
        #expect(decodificado.periodo == periodo)
    }

    // MARK: - AcaoPendente e com(contaID:)

    @Test("AcaoPendente.com(contaID:) clona preservando todos os atributos originais e atualiza contaID")
    func acaoPendenteComContaID() throws {
        let acaoID = try #require(UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
        let turnoID = try #require(UUID(uuidString: "22222222-3333-4444-5555-666666666666"))
        let chave = try #require(UUID(uuidString: "33333333-4444-5555-6666-777777777777"))
        let contaOriginal = try #require(UUID(uuidString: "44444444-5555-6666-7777-888888888888"))
        let novaConta = try #require(UUID(uuidString: "99999999-aaaa-bbbb-cccc-dddddddddddd"))
        let instante = Date(timeIntervalSince1970: 1_790_000_000)

        let original = AcaoPendente(
            id: acaoID,
            tipo: .checkin,
            turnoID: turnoID,
            contaID: contaOriginal,
            instanteDoToque: instante,
            chave: chave,
            distanciaMetros: 25,
            resposta: true,
            motivo: "Chegada no horário"
        )

        let atualizada = original.com(contaID: novaConta)

        #expect(atualizada.id == original.id)
        #expect(atualizada.tipo == original.tipo)
        #expect(atualizada.turnoID == original.turnoID)
        #expect(atualizada.instanteDoToque == original.instanteDoToque)
        #expect(atualizada.chave == original.chave)
        #expect(atualizada.distanciaMetros == original.distanciaMetros)
        #expect(atualizada.resposta == original.resposta)
        #expect(atualizada.motivo == original.motivo)
        #expect(atualizada.contaID == novaConta)
        #expect(atualizada.contaID != original.contaID)
    }

    // MARK: - AcaoRecusada

    @Test("AcaoRecusada extrai vagaID de alvoID quando o cancelamento é de vaga")
    func acaoRecusadaCancelamentoVaga() throws {
        let vagaID = try #require(UUID(uuidString: "55555555-6666-7777-8888-999999999999"))
        let acao = AcaoPendente(
            tipo: .cancelamentoVaga,
            instanteDoToque: Date(),
            chave: UUID(),
            alvoID: vagaID,
            motivo: "Falta de movimento"
        )

        let recusada = AcaoRecusada(acao: acao, codigo: .vagaEncerrada)
        #expect(recusada.vagaID == vagaID)
        #expect(recusada.tipo == .cancelamentoVaga)
        #expect(recusada.codigo == .vagaEncerrada)
        #expect(recusada.avisoReconhecido == nil)
        #expect(recusada.corresponde(a: acao))

        let reconhecida = recusada.comAvisoReconhecido()
        #expect(reconhecida.avisoReconhecido == true)
    }

    @Test("AcaoRecusada extrai vagaID da estrutura de republicacao quando o tipo é republicacaoVaga")
    func acaoRecusadaRepublicacaoVaga() throws {
        let vagaID = try #require(UUID(uuidString: "77777777-8888-9999-aaaa-bbbbbbbbbbbb"))
        let inicio = Date(timeIntervalSince1970: 1_790_000_000)
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(3600))
        let acao = AcaoPendente(
            tipo: .republicacaoVaga,
            instanteDoToque: Date(),
            chave: UUID(),
            republicacao: RepublicacaoVaga(vagaID: vagaID, periodo: periodo)
        )

        let recusada = AcaoRecusada(acao: acao, codigo: .republicacaoIndisponivel)
        #expect(recusada.vagaID == vagaID)
        #expect(recusada.corresponde(a: acao))
    }

    @Test("AcaoRecusada não corresponde a ação com tipo ou turnoID diferentes")
    func acaoRecusadaNaoCorresponde() throws {
        let turnoA = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))
        let turnoB = try #require(UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000000"))

        let acao1 = AcaoPendente(tipo: .checkin, turnoID: turnoA, instanteDoToque: Date(), chave: UUID())
        let acao2 = AcaoPendente(tipo: .checkin, turnoID: turnoB, instanteDoToque: Date(), chave: UUID())
        let acao3 = AcaoPendente(tipo: .checkout, turnoID: turnoA, instanteDoToque: Date(), chave: UUID())

        let recusada = AcaoRecusada(acao: acao1, codigo: .foraDaJanela)

        #expect(recusada.corresponde(a: acao1))
        #expect(!recusada.corresponde(a: acao2))
        #expect(!recusada.corresponde(a: acao3))
    }
}
