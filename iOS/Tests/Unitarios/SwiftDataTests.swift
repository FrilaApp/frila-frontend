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

    @Test("Turno vencido há mais de 24 h apaga o ContatoDoTurnoPersistido e limpa contatos órfãos")
    func contatoDoTurnoVencidoEApagado() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        let agora = Date(timeIntervalSince1970: 1_800_000_000)

        // Turno vencido há 25h com contato ainda dentro da validade teórica
        let turnoVencido = try turno(fim: agora.addingTimeInterval(-25 * 3600), contatoVisivelAte: agora.addingTimeInterval(3600))
        try await armazenamento.salvar(turnos: [turnoVencido], em: agora.addingTimeInterval(-26 * 3600))
        try await armazenamento.salvar(contato: turnoVencido.contato!, doTurno: turnoVencido.id)

        // Contato órfão (turnoID que nem existe mais no cache)
        let orfaoID = UUID()
        let whatsapp = try #require(URL(string: "https://wa.me/5511988887777"))
        let contatoOrfao = Contato(nome: "Órfão", telefone: "+5511988887777", whatsappURL: whatsapp, visivelAte: agora.addingTimeInterval(3600))
        try await armazenamento.salvar(contato: contatoOrfao, doTurno: orfaoID)

        // Contato de turno válido com prazo visivelAte já expirado
        let turnoValido = try turno(fim: agora.addingTimeInterval(3600), contatoVisivelAte: agora.addingTimeInterval(-10))
        try await armazenamento.salvar(turnos: [turnoValido], em: agora)
        try await armazenamento.salvar(contato: turnoValido.contato!, doTurno: turnoValido.id)

        // Controle positivo: turno ativo com contato visível DEVE permanecer
        let turnoAtivo = try turno(fim: agora.addingTimeInterval(7200), contatoVisivelAte: agora.addingTimeInterval(3600))
        try await armazenamento.salvar(turnos: [turnoAtivo], em: agora)
        try await armazenamento.salvar(contato: turnoAtivo.contato!, doTurno: turnoAtivo.id)

        let contexto = ModelContext(container)
        #expect(try contexto.fetchCount(FetchDescriptor<ContatoDoTurnoPersistido>()) == 4)

        // Ao ler turnos válidos, deve apagar o TurnoPersistido vencido E os contatos vencidos/órfãos/expirados,
        // preservando o contato do turno ativo
        let validos = try await armazenamento.turnosValidos(em: agora)
        #expect(Set(validos.map(\.id)) == Set([turnoValido.id, turnoAtivo.id]))

        // Apenas o contato do turno ativo deve restar no banco
        let contatosRestantes = try contexto.fetch(FetchDescriptor<ContatoDoTurnoPersistido>())
        #expect(contatosRestantes.count == 1)
        #expect(contatosRestantes.first?.turnoID == turnoAtivo.id)
        #expect(try await armazenamento.contato(doTurno: turnoAtivo.id, em: agora) == turnoAtivo.contato)
        #expect(try await armazenamento.contato(doTurno: turnoVencido.id, em: agora) == nil)
        #expect(try await armazenamento.contato(doTurno: orfaoID, em: agora) == nil)
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

    @Test("Banco V3 migra para V4 conservando turnos, contato, pendentes, recusadas, funções e sessão")
    func migracaoEsquemaV3ParaV4ConservaDadosEContato() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appending(path: "frila-migracao-v3-v4-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let url = diretorio.appending(path: "FrilaV3.store")

        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let turnoID = UUID()
        let periodo = try Periodo(inicio: agora, fim: agora.addingTimeInterval(14_400))
        let resumo = VagaResumo(id: UUID(), funcao: "Barista", local: "Asa Norte", regiaoAdministrativa: "Brasília", periodo: periodo, valor: Dinheiro(centavos: 15_000))
        let reputacao = Reputacao(positivas: 5, total: 5, taxaComparecimento: 1, turnosConsiderados: 5, turnosRealizados: 5)
        let contato = Contato(nome: "Gerente Café", telefone: "+5561988887777", whatsappURL: try #require(URL(string: "https://wa.me/5561988887777")), visivelAte: agora.addingTimeInterval(86_400))
        let turno = Turno(id: turnoID, posicaoID: UUID(), vaga: resumo, contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Café Gourmet", reputacao: reputacao), contatoVisivelAte: agora.addingTimeInterval(86_400), verificacao: .pendente, valorAcordado: Dinheiro(centavos: 15_000), podeAvaliar: false, contato: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let acao = AcaoPendente(tipo: .checkin, turnoID: turnoID, instanteDoToque: agora, chave: UUID(), distanciaMetros: 15)
        let acaoRecusada = AcaoRecusada(acao: acao, codigo: .vagaEncerrada)
        let funcao = Funcao(id: UUID(), nome: "Barista", categoria: "Cafeteria")
        let sessao = SessaoUsuario(usuarioID: UUID(), perfil: .profissional)

        let dadosTurno = try encoder.encode(turno)
        let dadosContato = try JSONEncoder().encode(contato)
        let dadosAcao = try encoder.encode(acao)
        let dadosRecusada = try JSONEncoder().encode(acaoRecusada)
        let dadosFuncao = try JSONEncoder().encode(funcao)
        let dadosSessao = try JSONEncoder().encode(sessao)

        do {
            let esquemaV3 = Schema(versionedSchema: EsquemaFrilaV3.self)
            let configV3 = ModelConfiguration("FrilaV3", schema: esquemaV3, url: url)
            let containerV3 = try ModelContainer(for: esquemaV3, configurations: [configV3])
            let contextoV3 = ModelContext(containerV3)

            contextoV3.insert(TurnoPersistido(id: turnoID, conteudo: dadosTurno, fim: periodo.fim, contatoVisivelAte: turno.contatoVisivelAte, salvoEm: agora))
            contextoV3.insert(ContatoDoTurnoPersistido(turnoID: turnoID, conteudo: dadosContato))
            contextoV3.insert(AcaoPendentePersistida(id: acao.id, tipo: acao.tipo.rawValue, conteudo: dadosAcao, instanteDoToque: acao.instanteDoToque))
            contextoV3.insert(AcaoRecusadaPersistida(id: acaoRecusada.id, conteudo: dadosRecusada))
            contextoV3.insert(FuncaoPersistida(id: funcao.id, conteudo: dadosFuncao))
            contextoV3.insert(SessaoPersistida(conteudo: dadosSessao))
            try contextoV3.save()
        }

        let esquemaV4 = Schema(versionedSchema: EsquemaFrilaV4.self)
        let configV4 = ModelConfiguration("FrilaV3", schema: esquemaV4, url: url)
        do {
            let containerV4 = try ModelContainer(for: esquemaV4, migrationPlan: MigracaoFrila.self, configurations: [configV4])
            let cache = ArmazenamentoSwiftData(modelContainer: containerV4)

            let turnos = try await cache.turnosValidos(em: agora)
            #expect(turnos.count == 1)
            #expect(turnos.first?.id == turnoID)
            #expect(turnos.first?.vaga.funcao == "Barista")
            #expect(turnos.first?.contato?.telefone == "+5561988887777")

            let lidoContato = try await cache.contato(doTurno: turnoID, em: agora)
            #expect(lidoContato?.telefone == "+5561988887777")
            #expect(lidoContato?.nome == "Gerente Café")

            let pendentes = try await cache.pendentes()
            #expect(pendentes.count == 1)
            #expect(pendentes.first?.id == acao.id)
            #expect(pendentes.first?.distanciaMetros == 15)

            let recusadas = try await cache.recusadas()
            #expect(recusadas.count == 1)
            #expect(recusadas.first?.id == acaoRecusada.id)
            #expect(recusadas.first?.codigo == .vagaEncerrada)

            let funcoes = try await cache.funcoes()
            #expect(funcoes.count == 1)
            #expect(funcoes.first?.id == funcao.id)

            let lidaSessao = try await cache.sessao()
            #expect(lidaSessao?.usuarioID == sessao.usuarioID)
            #expect(lidaSessao?.perfil == .profissional)

            let contextoV4 = ModelContext(containerV4)

            // Comparação campo a campo dos modelos persistidos no container migrado
            let turnosPersistidos = try contextoV4.fetch(FetchDescriptor<TurnoPersistido>())
            #expect(turnosPersistidos.count == 1)
            let turnoPersistido = try #require(turnosPersistidos.first)
            #expect(turnoPersistido.id == turnoID)
            #expect(turnoPersistido.fim == periodo.fim)
            #expect(turnoPersistido.salvoEm == agora)
            #expect(turnoPersistido.contatoVisivelAte == turno.contatoVisivelAte)
            #expect(turnoPersistido.conteudo == dadosTurno)

            let contatosPersistidos = try contextoV4.fetch(FetchDescriptor<ContatoDoTurnoPersistido>())
            #expect(contatosPersistidos.count == 1)
            let contatoPersistido = try #require(contatosPersistidos.first)
            #expect(contatoPersistido.turnoID == turnoID)
            #expect(contatoPersistido.conteudo == dadosContato)

            let pendentesPersistidas = try contextoV4.fetch(FetchDescriptor<AcaoPendentePersistida>())
            #expect(pendentesPersistidas.count == 1)
            let pendentePersistida = try #require(pendentesPersistidas.first)
            #expect(pendentePersistida.id == acao.id)
            #expect(pendentePersistida.tipo == acao.tipo.rawValue)
            #expect(pendentePersistida.instanteDoToque == acao.instanteDoToque)
            #expect(pendentePersistida.conteudo == dadosAcao)

            let recusadasPersistidas = try contextoV4.fetch(FetchDescriptor<AcaoRecusadaPersistida>())
            #expect(recusadasPersistidas.count == 1)
            let recusadaPersistida = try #require(recusadasPersistidas.first)
            #expect(recusadaPersistida.id == acaoRecusada.id)
            #expect(recusadaPersistida.conteudo == dadosRecusada)

            let funcoesPersistidas = try contextoV4.fetch(FetchDescriptor<FuncaoPersistida>())
            #expect(funcoesPersistidas.count == 1)
            let funcaoPersistida = try #require(funcoesPersistidas.first)
            #expect(funcaoPersistida.id == funcao.id)
            #expect(funcaoPersistida.conteudo == dadosFuncao)

            let sessoesPersistidas = try contextoV4.fetch(FetchDescriptor<SessaoPersistida>())
            #expect(sessoesPersistidas.count == 1)
            let sessaoPersistida = try #require(sessoesPersistidas.first)
            #expect(sessaoPersistida.chave == "sessao-atual")
            #expect(sessaoPersistida.conteudo == dadosSessao)

            let evento = EventoDeTelemetriaPersistido(id: UUID(), conteudo: Data("{}".utf8), guardadoEm: agora)
            contextoV4.insert(evento)
            try contextoV4.save()
            #expect(try contextoV4.fetchCount(FetchDescriptor<EventoDeTelemetriaPersistido>()) == 1)
        }
    }

    @Test("Banco V3 pré-gravado (fixture binário) migra para V4 sem instanciar EsquemaFrilaV3 no teste")
    func migracaoEsquemaV3ParaV4ComFixtureBinario() async throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixtureOriginal = raiz.appending(path: "Tests/Fixtures/SwiftData/FrilaV3-gravado-esquema-v3.store")
        guard FileManager.default.fileExists(atPath: fixtureOriginal.path) else {
            Issue.record("Fixture binário não encontrado em \(fixtureOriginal.path)")
            return
        }

        let diretorio = FileManager.default.temporaryDirectory.appending(path: "frila-migracao-fixture-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let urlDestino = diretorio.appending(path: "FrilaV3.store")
        try FileManager.default.copyItem(at: fixtureOriginal, to: urlDestino)

        let esquemaV4 = Schema(versionedSchema: EsquemaFrilaV4.self)
        let configV4 = ModelConfiguration("FrilaV3", schema: esquemaV4, url: urlDestino)
        let containerV4 = try ModelContainer(for: esquemaV4, migrationPlan: MigracaoFrila.self, configurations: [configV4])
        let cache = ArmazenamentoSwiftData(modelContainer: containerV4)

        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let turnos = try await cache.turnosValidos(em: agora)
        #expect(turnos.count == 1)
        #expect(turnos.first?.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(turnos.first?.vaga.funcao == "Barista")
        #expect(turnos.first?.contato?.telefone == "+5561988887777")

        let pendentes = try await cache.pendentes()
        #expect(pendentes.count == 1)
        #expect(pendentes.first?.tipo == .checkin)
        #expect(pendentes.first?.distanciaMetros == 15)

        let recusadas = try await cache.recusadas()
        #expect(recusadas.count == 1)
        #expect(recusadas.first?.codigo == .vagaEncerrada)

        let funcoes = try await cache.funcoes()
        #expect(funcoes.count == 1)
        #expect(funcoes.first?.nome == "Barista")

        let sessao = try await cache.sessao()
        #expect(sessao?.usuarioID == UUID(uuidString: "66666666-7777-8888-9999-000000000000"))
        #expect(sessao?.perfil == .profissional)

        // Valida que o container migrado aceita novo registro V4
        let evento = EventoDeTelemetriaPersistido(id: UUID(), conteudo: Data("{}".utf8), guardadoEm: agora)
        let contextoV4 = ModelContext(containerV4)
        contextoV4.insert(evento)
        try contextoV4.save()
        #expect(try contextoV4.fetchCount(FetchDescriptor<EventoDeTelemetriaPersistido>()) == 1)
    }

    @Test("Container persistente exclui o diretório Frila de backups (iCloud e Finder)")
    func diretorioExcluidoDeBackup() throws {
        let suporte = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let diretorio = suporte.appending(path: "Frila", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        var valoresIniciais = URLResourceValues()
        valoresIniciais.isExcludedFromBackup = false
        var diretorioMutavel = diretorio
        try diretorioMutavel.setResourceValues(valoresIniciais)
        let antes = try diretorio.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(antes.isExcludedFromBackup == false)

        _ = try PersistenciaFrila.criarContainer(emMemoria: false)
        var diretorioAposCriar = suporte.appending(path: "Frila", directoryHint: .isDirectory)
        diretorioAposCriar.removeAllCachedResourceValues()
        let valores = try diretorioAposCriar.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(valores.isExcludedFromBackup == true)
    }
}
