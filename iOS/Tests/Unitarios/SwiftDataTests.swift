import Foundation
import FrilaDados
import FrilaDominio
import SwiftData
import Testing

@Suite("Cache e fila SwiftData")
struct SwiftDataTests {
    @Test("Fila mantém instante do toque e chave idempotente")
    func fila() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let instante = Date(timeIntervalSince1970: 1_700_000_000)
        let chave = UUID()
        let acao = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: instante, chave: chave, distanciaMetros: 42)
        try await armazenamento.enfileirar(acao)
        let lida = try #require(await armazenamento.pendentes().first)
        #expect(lida.instanteDoToque == instante)
        #expect(lida.chave == chave)
        #expect(lida.distanciaMetros == 42)
        try await armazenamento.limpar()
        #expect(try await armazenamento.pendentes().isEmpty)
    }

    @Test("Perfil fica disponível offline e logout limpa todos os dados")
    func perfil() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let sessao = SessaoUsuario(usuarioID: UUID(), perfil: .contratante)
        try await armazenamento.salvar(sessao: sessao)
        #expect(try await armazenamento.sessao() == sessao)
        try await armazenamento.limpar()
        #expect(try await armazenamento.sessao() == nil)
    }

    @Test("Contato expira offline e turno sai do cache 24h após o fim")
    func retencaoDeTurno() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let recente = try turno(fim: agora.addingTimeInterval(-3_600), contatoVisivelAte: agora.addingTimeInterval(-1))
        let antigo = try turno(fim: agora.addingTimeInterval(-25 * 3_600), contatoVisivelAte: agora)
        try await armazenamento.salvar(turnos: [recente, antigo], em: agora)
        let validos = try await armazenamento.turnosValidos(em: agora)
        #expect(validos.map(\.id) == [recente.id])
        #expect(validos.first?.contato == nil)
    }

    @Test("Turno guardado antes do contrato 0.2.20, sem a região da vaga, continua abrindo offline")
    func turnoGuardadoAntesDaRegiaoAdministrativa() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let atual = try turno(fim: agora.addingTimeInterval(3_600), contatoVisivelAte: agora.addingTimeInterval(86_400))
        do {
            // O que o build anterior gravava: o mesmo JSON, sem `regiaoAdministrativa` na vaga.
            let codificador = JSONEncoder()
            codificador.dateEncodingStrategy = .iso8601
            var antigo = try #require(JSONSerialization.jsonObject(with: codificador.encode(atual)) as? [String: Any])
            var vaga = try #require(antigo["vaga"] as? [String: Any])
            #expect(vaga.removeValue(forKey: "regiaoAdministrativa") != nil)
            antigo["vaga"] = vaga
            let contexto = ModelContext(container)
            contexto.insert(TurnoPersistido(
                id: atual.id, conteudo: try JSONSerialization.data(withJSONObject: antigo), fim: atual.vaga.periodo.fim,
                contatoVisivelAte: atual.contatoVisivelAte, salvoEm: agora
            ))
            try contexto.save()
        }

        let lidos = try await ArmazenamentoSwiftData(modelContainer: container).turnosValidos(em: agora)

        #expect(lidos.map(\.id) == [atual.id])
        #expect(lidos.first?.vaga.local == atual.vaga.local)
        #expect(lidos.first?.vaga.regiaoAdministrativa == "")
        #expect(lidos.first?.contato == atual.contato)
    }

    private func turno(fim: Date, contatoVisivelAte: Date) throws -> Turno {
        let inicio = fim.addingTimeInterval(-3_600)
        let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: "Centro", regiaoAdministrativa: "Plano Piloto", periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 10000))
        let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        let whatsapp = try #require(URL(string: "https://wa.me/5511999990000"))
        let contato = Contato(
            nome: "Bistrô", telefone: "+5511999990000",
            whatsappURL: whatsapp, visivelAte: contatoVisivelAte
        )
        return Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: reputacao),
            contatoVisivelAte: contatoVisivelAte, verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false,
            contato: contato
        )
    }
}
