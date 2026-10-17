import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Modelos de Cache e Fila de Ações")
struct CacheModelosTests {

    private func turnoDeExemplo(id: UUID = UUID()) throws -> Turno {
        let fim = Date(timeIntervalSince1970: 1_800_000_000)
        let inicio = fim.addingTimeInterval(-6 * 3600)
        let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: "Rua A, 1", regiaoAdministrativa: "Plano Piloto",
                              periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 10_000))
        let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô",
                                        reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0))
        return Turno(id: id, posicaoID: UUID(), vaga: vaga, contraparte: contraparte, contatoVisivelAte: fim.addingTimeInterval(7 * 86_400),
                     verificacao: .pendente, valorAcordado: Dinheiro(centavos: 10_000), podeAvaliar: false)
    }

    // MARK: - LeituraDeTurnos

    @Test("LeituraDeTurnos preserva lista e origem com igualdade estrutural")
    func leituraDeTurnosIgualdade() throws {
        let turno1 = try turnoDeExemplo()
        let turno2 = try turnoDeExemplo()

        let leituraRede1 = LeituraDeTurnos(turnos: [turno1], origem: .rede)
        let leituraRede1Clone = LeituraDeTurnos(turnos: [turno1], origem: .rede)
        let leituraCache1 = LeituraDeTurnos(turnos: [turno1], origem: .cache)
        let leituraRede2 = LeituraDeTurnos(turnos: [turno2], origem: .rede)

        #expect(leituraRede1 == leituraRede1Clone)
        #expect(leituraRede1.origem == .rede)
        #expect(leituraCache1.origem == .cache)
        #expect(leituraRede1 != leituraCache1)
        #expect(leituraRede1 != leituraRede2)
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
        let alvoID = try #require(UUID(uuidString: "55555555-6666-7777-8888-999999999999"))
        let estabID = try #require(UUID(uuidString: "66666666-7777-8888-9999-000000000000"))
        let instante = Date(timeIntervalSince1970: 1_790_000_000)
        let periodo = try Periodo(inicio: instante.addingTimeInterval(3600), fim: instante.addingTimeInterval(7200))
        let republicacao = RepublicacaoVaga(vagaID: alvoID, periodo: periodo)
        let publicacao = PublicacaoVaga(
            estabelecimentoID: estabID,
            funcaoID: UUID(),
            periodo: periodo,
            local: "Rua A",
            regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.78, longitude: -47.93),
            valor: Dinheiro(centavos: 12_000),
            posicoes: 1,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Carlos",
            chave: UUID()
        )

        let original = AcaoPendente(
            id: acaoID,
            tipo: .publicacaoVaga,
            turnoID: turnoID,
            contaID: contaOriginal,
            instanteDoToque: instante,
            chave: chave,
            distanciaMetros: 25,
            resposta: true,
            publicacao: publicacao,
            republicacao: republicacao,
            alvoID: alvoID,
            motivo: "Motivo de teste"
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
        #expect(atualizada.publicacao == original.publicacao)
        #expect(atualizada.republicacao == original.republicacao)
        #expect(atualizada.alvoID == original.alvoID)
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

    @Test("AcaoRecusada extrai campos de acordo com a semântica de cada tipo de ação")
    func acaoRecusadaExtracaoDeCampos() throws {
        let posicaoID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let estabID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let contaID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let periodo = try Periodo(inicio: Date(), fim: Date().addingTimeInterval(3600))

        // cancelamentoPosicao tem alvoID (a posição), portanto vagaID DEVE ser nil
        let acaoPosicao = AcaoPendente(
            tipo: .cancelamentoPosicao,
            contaID: contaID,
            instanteDoToque: Date(),
            chave: UUID(),
            alvoID: posicaoID,
            motivo: "Imprevisto"
        )
        let recusadaPosicao = AcaoRecusada(acao: acaoPosicao, codigo: .posicaoNaoCancelavel)
        #expect(recusadaPosicao.vagaID == nil)
        #expect(recusadaPosicao.contaID == contaID)

        // publicacaoVaga preenche estabelecimentoID a partir de publicacao
        let publicacao = PublicacaoVaga(
            estabelecimentoID: estabID,
            funcaoID: UUID(),
            periodo: periodo,
            local: "Local",
            regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.78, longitude: -47.93),
            valor: Dinheiro(centavos: 10_000),
            posicoes: 1,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Responsavel",
            chave: UUID()
        )
        let acaoPublicacao = AcaoPendente(
            tipo: .publicacaoVaga,
            contaID: contaID,
            instanteDoToque: Date(),
            chave: UUID(),
            publicacao: publicacao
        )
        let recusadaPublicacao = AcaoRecusada(acao: acaoPublicacao, codigo: .vagaEncerrada)
        #expect(recusadaPublicacao.estabelecimentoID == estabID)
        #expect(recusadaPublicacao.contaID == contaID)
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

    @Test("AcaoRecusada.corresponde(a:) valida alvoID, estabelecimentoID e contaID")
    func acaoRecusadaCorrespondeDiferencas() throws {
        let vagaA = try #require(UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111"))
        let vagaB = try #require(UUID(uuidString: "bbbbbbbb-2222-2222-2222-222222222222"))
        let estabA = try #require(UUID(uuidString: "cccccccc-3333-3333-3333-333333333333"))
        let estabB = try #require(UUID(uuidString: "dddddddd-4444-4444-4444-444444444444"))
        let contaX = try #require(UUID(uuidString: "eeeeeeee-5555-5555-5555-555555555555"))
        let contaY = try #require(UUID(uuidString: "ffffffff-6666-6666-6666-666666666666"))

        // cancelamentoVaga com alvoID diferente não corresponde
        let acaoVagaA = AcaoPendente(tipo: .cancelamentoVaga, instanteDoToque: Date(), chave: UUID(), alvoID: vagaA)
        let acaoVagaB = AcaoPendente(tipo: .cancelamentoVaga, instanteDoToque: Date(), chave: UUID(), alvoID: vagaB)
        let recusadaVagaA = AcaoRecusada(acao: acaoVagaA, codigo: .vagaEncerrada)
        #expect(recusadaVagaA.corresponde(a: acaoVagaA))
        #expect(!recusadaVagaA.corresponde(a: acaoVagaB))

        // publicacaoVaga com estabelecimentos diferentes não corresponde
        let periodo = try Periodo(inicio: Date(), fim: Date().addingTimeInterval(3600))
        let pubA = PublicacaoVaga(
            estabelecimentoID: estabA,
            funcaoID: UUID(),
            periodo: periodo,
            local: "L",
            regiaoAdministrativa: "RA",
            ponto: try Coordenada(latitude: -15.7, longitude: -47.9),
            valor: Dinheiro(centavos: 10_000),
            posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "R",
            chave: UUID()
        )
        let pubB = PublicacaoVaga(
            estabelecimentoID: estabB,
            funcaoID: UUID(),
            periodo: periodo,
            local: "L",
            regiaoAdministrativa: "RA",
            ponto: try Coordenada(latitude: -15.7, longitude: -47.9),
            valor: Dinheiro(centavos: 10_000),
            posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "R",
            chave: UUID()
        )
        let acaoPubA = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: Date(), chave: UUID(), publicacao: pubA)
        let acaoPubB = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: Date(), chave: UUID(), publicacao: pubB)
        let recusadaPubA = AcaoRecusada(acao: acaoPubA, codigo: .vagaEncerrada)
        #expect(recusadaPubA.corresponde(a: acaoPubA))
        #expect(!recusadaPubA.corresponde(a: acaoPubB))

        // contaID X não corresponde a contaID Y
        let acaoContaX = AcaoPendente(tipo: .checkin, turnoID: UUID(), contaID: contaX, instanteDoToque: Date(), chave: UUID())
        let acaoContaY = AcaoPendente(tipo: .checkin, turnoID: acaoContaX.turnoID, contaID: contaY, instanteDoToque: Date(), chave: UUID())
        let recusadaContaX = AcaoRecusada(acao: acaoContaX, codigo: .foraDaJanela)
        #expect(recusadaContaX.corresponde(a: acaoContaX))
        #expect(!recusadaContaX.corresponde(a: acaoContaY))

        // recusada com contaID == nil corresponde a qualquer conta da mesma ação
        let acaoSemConta = AcaoPendente(tipo: .checkin, turnoID: acaoContaX.turnoID, contaID: nil, instanteDoToque: Date(), chave: UUID())
        let recusadaSemConta = AcaoRecusada(acao: acaoSemConta, codigo: .foraDaJanela)
        #expect(recusadaSemConta.corresponde(a: acaoContaX))
        #expect(recusadaSemConta.corresponde(a: acaoContaY))
    }
}
