import Foundation
import FrilaDominio
import OSLog
import SwiftData

@Model
public final class TurnoPersistido {
    @Attribute(.unique) public var id: UUID
    public var conteudo: Data
    public var fim: Date
    public var contatoVisivelAte: Date?
    public var salvoEm: Date

    public init(id: UUID, conteudo: Data, fim: Date, contatoVisivelAte: Date?, salvoEm: Date) {
        self.id = id
        self.conteudo = conteudo
        self.fim = fim
        self.contatoVisivelAte = contatoVisivelAte
        self.salvoEm = salvoEm
    }
}

@Model
public final class FuncaoPersistida {
    @Attribute(.unique) public var id: UUID
    public var conteudo: Data
    public init(id: UUID, conteudo: Data) { self.id = id; self.conteudo = conteudo }
}

@Model
public final class SessaoPersistida {
    @Attribute(.unique) public var chave: String
    public var conteudo: Data

    public init(conteudo: Data) {
        chave = "sessao-atual"
        self.conteudo = conteudo
    }
}

@Model
public final class AcaoPendentePersistida {
    @Attribute(.unique) public var id: UUID
    public var tipo: String
    public var conteudo: Data
    public var instanteDoToque: Date

    public init(id: UUID, tipo: String, conteudo: Data, instanteDoToque: Date) {
        self.id = id
        self.tipo = tipo
        self.conteudo = conteudo
        self.instanteDoToque = instanteDoToque
    }
}

@Model
public final class AcaoRecusadaPersistida {
    @Attribute(.unique) public var id: UUID
    public var conteudo: Data

    public init(id: UUID, conteudo: Data) { self.id = id; self.conteudo = conteudo }
}

@Model
public final class ContatoDoTurnoPersistido {
    @Attribute(.unique) public var turnoID: UUID
    public var conteudo: Data

    public init(turnoID: UUID, conteudo: Data) { self.turnoID = turnoID; self.conteudo = conteudo }
}

/// Os modelos que guardam um valor do domínio como JSON em `conteudo`.
protocol RegistroComConteudo: PersistentModel {
    var conteudo: Data { get }
}

extension TurnoPersistido: RegistroComConteudo {}
extension FuncaoPersistida: RegistroComConteudo {}
extension SessaoPersistida: RegistroComConteudo {}
extension AcaoPendentePersistida: RegistroComConteudo {}
extension AcaoRecusadaPersistida: RegistroComConteudo {}
extension ContatoDoTurnoPersistido: RegistroComConteudo {}

public enum EsquemaFrilaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [TurnoPersistido.self, FuncaoPersistida.self, SessaoPersistida.self, AcaoPendentePersistida.self]
    }
}

public enum EsquemaFrilaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        EsquemaFrilaV1.models + [AcaoRecusadaPersistida.self]
    }
}

public enum MigracaoFrila: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [EsquemaFrilaV1.self, EsquemaFrilaV2.self, EsquemaFrilaV3.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: EsquemaFrilaV1.self, toVersion: EsquemaFrilaV2.self),
         .lightweight(fromVersion: EsquemaFrilaV2.self, toVersion: EsquemaFrilaV3.self)]
    }
}

public enum EsquemaFrilaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        EsquemaFrilaV2.models + [ContatoDoTurnoPersistido.self]
    }
}

public enum PersistenciaFrila {
    public static func criarContainer(emMemoria: Bool = false) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaFrilaV3.self)
        let configuracao: ModelConfiguration
        if emMemoria {
            configuracao = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true)
        } else {
            let suporte = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let diretorio = suporte.appending(path: "Frila", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: diretorio.path()
            )
            configuracao = ModelConfiguration("Frila", schema: esquema, url: diretorio.appending(path: "Frila.store"))
        }
        return try ModelContainer(for: esquema, migrationPlan: MigracaoFrila.self, configurations: [configuracao])
    }
}

@ModelActor
public actor ArmazenamentoSwiftData: CacheLocal, FilaDeAcoes {
    public func salvar(sessao: SessaoUsuario) throws {
        let dados = try JSONEncoder().encode(sessao)
        let chave = "sessao-atual"
        let descritor = FetchDescriptor<SessaoPersistida>(predicate: #Predicate { $0.chave == chave })
        if let existente = try modelContext.fetch(descritor).first {
            existente.conteudo = dados
        } else {
            modelContext.insert(SessaoPersistida(conteudo: dados))
        }
        try modelContext.save()
    }

    public func sessao() throws -> SessaoUsuario? {
        guard let registro = try modelContext.fetch(FetchDescriptor<SessaoPersistida>()).first else { return nil }
        let sessoes: [SessaoUsuario] = try legiveis([registro], JSONDecoder(), origem: "sessao")
        return sessoes.first
    }

    public func salvar(turnos: [Turno], em instante: Date) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for turno in turnos {
            let id = turno.id
            let descritor = FetchDescriptor<TurnoPersistido>(predicate: #Predicate { $0.id == id })
            if let existente = try modelContext.fetch(descritor).first {
                existente.conteudo = try encoder.encode(turno)
                existente.fim = turno.vaga.periodo.fim
                existente.contatoVisivelAte = turno.contatoVisivelAte
                existente.salvoEm = instante
            } else {
                modelContext.insert(TurnoPersistido(
                    id: turno.id,
                    conteudo: try encoder.encode(turno),
                    fim: turno.vaga.periodo.fim,
                    contatoVisivelAte: turno.contatoVisivelAte,
                    salvoEm: instante
                ))
            }
        }
        try modelContext.save()
    }

    public func turnosValidos(em instante: Date) throws -> [Turno] {
        let limite = instante.addingTimeInterval(-24 * 60 * 60)
        let todos = try modelContext.fetch(FetchDescriptor<TurnoPersistido>())
        let vencidos = todos.filter { $0.fim <= limite }
        vencidos.forEach(modelContext.delete)
        if !vencidos.isEmpty { try modelContext.save() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let turnos: [Turno] = try legiveis(todos.filter { $0.fim > limite }, decoder, origem: "turnos")
        return try turnos.map { turno in
            guard !turno.cancelado, turno.contatoVisivel(em: instante) else { return turno.com(contato: nil) }
            let guardado = try contato(doTurno: turno.id, em: instante) ?? turno.contato
            return turno.com(contato: guardado?.estaVisivel(em: instante) == true ? guardado : nil)
        }
    }

    public func salvar(contato: Contato, doTurno turnoID: UUID) throws {
        // Conserva também as frações de segundo do prazo recebido do servidor.
        let dados = try JSONEncoder().encode(contato)
        let descritor = FetchDescriptor<ContatoDoTurnoPersistido>(predicate: #Predicate { $0.turnoID == turnoID })
        if let existente = try modelContext.fetch(descritor).first {
            existente.conteudo = dados
        } else {
            modelContext.insert(ContatoDoTurnoPersistido(turnoID: turnoID, conteudo: dados))
        }
        try modelContext.save()
    }

    public func contato(doTurno turnoID: UUID, em instante: Date) throws -> Contato? {
        let descritor = FetchDescriptor<ContatoDoTurnoPersistido>(predicate: #Predicate { $0.turnoID == turnoID })
        guard let registro = try modelContext.fetch(descritor).first else { return nil }
        let contatos: [Contato] = try legiveis([registro], JSONDecoder(), origem: "contato")
        guard let contato = contatos.first else { return nil }
        guard contato.estaVisivel(em: instante) else {
            modelContext.delete(registro)
            try modelContext.save()
            return nil
        }
        return contato
    }

    public func removerContato(doTurno turnoID: UUID) throws {
        try modelContext.delete(model: ContatoDoTurnoPersistido.self, where: #Predicate { $0.turnoID == turnoID })
        try modelContext.save()
    }

    public func salvar(funcoes: [Funcao]) throws {
        let encoder = JSONEncoder()
        for funcao in funcoes {
            let id = funcao.id
            let descritor = FetchDescriptor<FuncaoPersistida>(predicate: #Predicate { $0.id == id })
            if let existente = try modelContext.fetch(descritor).first {
                existente.conteudo = try encoder.encode(funcao)
            } else {
                modelContext.insert(FuncaoPersistida(id: id, conteudo: try encoder.encode(funcao)))
            }
        }
        try modelContext.save()
    }

    public func funcoes() throws -> [Funcao] {
        try legiveis(try modelContext.fetch(FetchDescriptor<FuncaoPersistida>()), JSONDecoder(), origem: "funcoes")
    }

    public func enfileirar(_ acao: AcaoPendente) throws {
        let idRecusado = acao.id
        // Um aviso já gravado é terminal para este envio, mesmo se uma tela antiga guardar a ação.
        if try modelContext.fetch(FetchDescriptor<AcaoRecusadaPersistida>(predicate: #Predicate { $0.id == idRecusado })).first != nil { return }
        // A fila também protege dois modelos da mesma tela: mantém a primeira resposta por autor/turno.
        if acao.tipo == .avaliacao, let contaID = acao.contaID,
           try pendentes().contains(where: { $0.tipo == .avaliacao && $0.contaID == contaID && $0.turnoID == acao.turnoID }) {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let id = acao.id
        let descritor = FetchDescriptor<AcaoPendentePersistida>(predicate: #Predicate { $0.id == id })
        let conteudo = try encoder.encode(acao)
        if let existente = try modelContext.fetch(descritor).first {
            existente.tipo = acao.tipo.rawValue
            existente.conteudo = conteudo
            existente.instanteDoToque = acao.instanteDoToque
        } else {
            modelContext.insert(AcaoPendentePersistida(
                id: acao.id,
                tipo: acao.tipo.rawValue,
                conteudo: conteudo,
                instanteDoToque: acao.instanteDoToque
            ))
        }
        try modelContext.save()
    }

    public func pendentes() throws -> [AcaoPendente] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let descritor = FetchDescriptor<AcaoPendentePersistida>(sortBy: [SortDescriptor(\.instanteDoToque)])
        return try legiveis(try modelContext.fetch(descritor), decoder, origem: "fila")
    }

    public func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) throws {
        let id = acao.id
        // Se a sessão foi encerrada durante o envio, a limpeza já retirou a ação: não recria o aviso.
        guard try modelContext.fetch(FetchDescriptor<AcaoPendentePersistida>(predicate: #Predicate { $0.id == id })).first != nil else { return }
        do {
            let registro = AcaoRecusada(acao: acao, codigo: codigo)
            modelContext.insert(AcaoRecusadaPersistida(id: id, conteudo: try JSONEncoder().encode(registro)))
            try modelContext.delete(model: AcaoPendentePersistida.self, where: #Predicate { $0.id == id })
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        NotificationCenter.default.post(name: .filaDeAcoesAtualizada, object: nil)
    }

    public func recusadas() throws -> [AcaoRecusada] {
        try legiveis(try modelContext.fetch(FetchDescriptor<AcaoRecusadaPersistida>()), JSONDecoder(), origem: "recusadas")
    }

    public func remover(id: UUID) throws {
        try modelContext.delete(model: AcaoPendentePersistida.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    /// Decodifica registro a registro. O que não decodifica foi gravado por um build com outro modelo
    /// (ou ficou corrompido): sai do banco e da lista, em vez de uma única linha ilegível inutilizar
    /// o cache ou a fila inteira até a saída da conta. Só a origem e a quantidade vão ao log.
    private func legiveis<Registro: RegistroComConteudo, Valor: Decodable>(
        _ registros: [Registro], _ decoder: JSONDecoder, origem: String
    ) throws -> [Valor] {
        var ilegiveis = 0
        let valores = registros.compactMap { registro -> Valor? in
            guard let valor = try? decoder.decode(Valor.self, from: registro.conteudo) else {
                modelContext.delete(registro)
                ilegiveis += 1
                return nil
            }
            return valor
        }
        if ilegiveis > 0 {
            try modelContext.save()
            Self.log.warning("registros_ilegiveis origem=\(origem, privacy: .public) apagados=\(ilegiveis, privacy: .public)")
        }
        return valores
    }

    private static let log = Logger(subsystem: "com.frila.org.app", category: "cache")

    public func limpar() throws {
        try modelContext.delete(model: TurnoPersistido.self)
        try modelContext.delete(model: FuncaoPersistida.self)
        try modelContext.delete(model: SessaoPersistida.self)
        try modelContext.delete(model: AcaoPendentePersistida.self)
        try modelContext.delete(model: AcaoRecusadaPersistida.self)
        try modelContext.delete(model: ContatoDoTurnoPersistido.self)
        try modelContext.save()
    }
}
