import Foundation
import FrilaDados
import FrilaDominio
import SwiftData
import Testing

@Suite("Cache e fila SwiftData")
struct SwiftDataTests {
    @Test("Republicação sobrevive à reabertura do banco com ID, origem, chave e período")
    func republicacaoPendenteNoDisco() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appending(path: "frila-republicacao-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let esquema = Schema([TurnoPersistido.self, FuncaoPersistida.self, SessaoPersistida.self, AcaoPendentePersistida.self])
        let configuracao = ModelConfiguration("FilaRepublicacaoTeste", schema: esquema, url: diretorio.appending(path: "Fila.store"))
        var container: ModelContainer? = try ModelContainer(for: esquema, configurations: [configuracao])
        var fila: ArmazenamentoSwiftData? = ArmazenamentoSwiftData(modelContainer: container!)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let periodo = try Periodo(inicio: base.addingTimeInterval(10800), fim: base.addingTimeInterval(25200))
        let acao = AcaoPendente(tipo: .republicacaoVaga, instanteDoToque: base, chave: UUID(),
                                republicacao: RepublicacaoVaga(vagaID: UUID(), periodo: periodo))
        try await fila!.enfileirar(acao)
        try await fila!.enfileirar(acao)
        fila = nil
        container = nil
        let reaberta = ArmazenamentoSwiftData(modelContainer: try ModelContainer(for: esquema, configurations: [configuracao]))
        #expect(try await reaberta.pendentes() == [acao])
        try await reaberta.remover(id: acao.id)
        #expect(try await reaberta.pendentes().isEmpty)
    }

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

    @Test("Publicação pendente preserva o payload e a chave na fila persistente")
    func publicacaoPendentePersistePayload() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appending(path: "frila-publicacao-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let esquema = Schema([TurnoPersistido.self, FuncaoPersistida.self, SessaoPersistida.self, AcaoPendentePersistida.self])
        let caminho = diretorio.appending(path: "Fila.store")
        let configuracao = ModelConfiguration("FilaPublicacaoTeste", schema: esquema, url: caminho)
        var containerAntesDeFechar: ModelContainer? = try ModelContainer(for: esquema, configurations: [configuracao])
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        let chave = UUID()
        let periodo = try Periodo(inicio: instante.addingTimeInterval(14_400), fim: instante.addingTimeInterval(25_200))
        let publicacao = PublicacaoVaga(
            estabelecimentoID: UUID(), funcaoID: UUID(), periodo: periodo, local: "Rua das Flores, 10",
            regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.78, longitude: -47.93), valor: Dinheiro(centavos: 14_000), posicoes: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false), responsavelLocal: "Renata",
            modo: .urgencia, alertaAntecedenciaMinutos: 180, chave: chave
        )
        var antesDeFechar: ArmazenamentoSwiftData? = ArmazenamentoSwiftData(modelContainer: containerAntesDeFechar!)
        let acao = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: instante, chave: chave, publicacao: publicacao)
        try await antesDeFechar!.enfileirar(acao)
        try await antesDeFechar!.enfileirar(acao)
        antesDeFechar = nil
        containerAntesDeFechar = nil

        let containerReaberto = try ModelContainer(for: esquema, configurations: [configuracao])
        let depoisDeAbrir = ArmazenamentoSwiftData(modelContainer: containerReaberto)
        let restaurada = try #require(await depoisDeAbrir.pendentes().first)

        #expect(try await depoisDeAbrir.pendentes().count == 1)
        #expect(restaurada.publicacao == publicacao)
        #expect(restaurada.chave == chave)
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
