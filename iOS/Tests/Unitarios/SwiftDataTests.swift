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

    // MARK: Registro ilegível (robustez: build anterior com outro modelo, ou linha corrompida)

    private func turnoDeExemplo(id: UUID = UUID(), fim: Date) throws -> Turno {
        let inicio = fim.addingTimeInterval(-6 * 3600)
        let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: "Rua A, 1", regiaoAdministrativa: "Plano Piloto",
                              periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 10_000))
        let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô",
                                        reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0))
        return Turno(id: id, posicaoID: UUID(), vaga: vaga, contraparte: contraparte, contatoVisivelAte: fim.addingTimeInterval(7 * 86_400),
                     verificacao: .pendente, valorAcordado: Dinheiro(centavos: 10_000), podeAvaliar: false)
    }

    @Test("Turno ilegível no cache sai do banco sozinho, e os outros continuam abrindo em modo avião")
    func turnoIlegivelSai() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let bom = try turnoDeExemplo(fim: agora.addingTimeInterval(86_400))
        try await armazenamento.salvar(turnos: [bom], em: agora)
        // Gravado "por um build anterior": o JSON não tem os campos que o modelo de hoje exige.
        let contexto = ModelContext(container)
        contexto.insert(TurnoPersistido(id: UUID(), conteudo: Data(#"{"id":"não é um turno"}"#.utf8),
                                        fim: agora.addingTimeInterval(86_400), contatoVisivelAte: nil, salvoEm: agora))
        try contexto.save()

        let lidos = try await armazenamento.turnosValidos(em: agora)
        #expect(lidos.map(\.id) == [bom.id])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<TurnoPersistido>()) == 1)
    }

    @Test("Ação ilegível na fila não trava as outras: sai do banco, e as legíveis seguem para o envio")
    func acaoIlegivelSai() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        let boa = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: Date(timeIntervalSince1970: 1_700_000_100), chave: UUID(), distanciaMetros: 10)
        try await armazenamento.enfileirar(boa)
        let contexto = ModelContext(container)
        contexto.insert(AcaoPendentePersistida(id: UUID(), tipo: "tipo_de_outro_build", conteudo: Data("{}".utf8),
                                               instanteDoToque: Date(timeIntervalSince1970: 1_700_000_000)))
        try contexto.save()

        #expect(try await armazenamento.pendentes().map(\.id) == [boa.id])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<AcaoPendentePersistida>()) == 1)
    }

    @Test("Sessão, funções, contato e recusadas ilegíveis saem sem derrubar a leitura")
    func demaisRegistrosIlegiveis() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        let funcao = Funcao(id: UUID(), nome: "Garçom", categoria: "salão")
        try await armazenamento.salvar(funcoes: [funcao])
        let contexto = ModelContext(container)
        contexto.insert(SessaoPersistida(conteudo: Data("[]".utf8)))
        contexto.insert(FuncaoPersistida(id: UUID(), conteudo: Data("null".utf8)))
        contexto.insert(ContatoDoTurnoPersistido(turnoID: funcao.id, conteudo: Data("{}".utf8)))
        contexto.insert(AcaoRecusadaPersistida(id: UUID(), conteudo: Data("{}".utf8)))
        try contexto.save()

        #expect(try await armazenamento.sessao() == nil)
        #expect(try await armazenamento.funcoes() == [funcao])
        #expect(try await armazenamento.contato(doTurno: funcao.id, em: .now) == nil)
        #expect(try await armazenamento.recusadas().isEmpty)
        let restante = ModelContext(container)
        #expect(try restante.fetchCount(FetchDescriptor<SessaoPersistida>()) == 0)
        #expect(try restante.fetchCount(FetchDescriptor<FuncaoPersistida>()) == 1)
        #expect(try restante.fetchCount(FetchDescriptor<ContatoDoTurnoPersistido>()) == 0)
        #expect(try restante.fetchCount(FetchDescriptor<AcaoRecusadaPersistida>()) == 0)
    }
}
