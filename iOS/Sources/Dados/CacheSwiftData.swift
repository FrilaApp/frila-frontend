import Foundation
import FrilaDominio
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

public enum PersistenciaFrila {
    public static func criarContainer(emMemoria: Bool = false) throws -> ModelContainer {
        let esquema = Schema([TurnoPersistido.self, FuncaoPersistida.self, SessaoPersistida.self, AcaoPendentePersistida.self])
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
        return try ModelContainer(for: esquema, configurations: [configuracao])
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
        return try JSONDecoder().decode(SessaoUsuario.self, from: registro.conteudo)
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
                existente.contatoVisivelAte = turno.contato?.visivelAte
                existente.salvoEm = instante
            } else {
                modelContext.insert(TurnoPersistido(
                    id: turno.id,
                    conteudo: try encoder.encode(turno),
                    fim: turno.vaga.periodo.fim,
                    contatoVisivelAte: turno.contato?.visivelAte,
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
        return try todos.filter { $0.fim > limite }.map { registro in
            let turno = try decoder.decode(Turno.self, from: registro.conteudo)
            guard let contato = turno.contato, !contato.estaVisivel(em: instante) else { return turno }
            return Turno(
                id: turno.id,
                posicaoID: turno.posicaoID,
                vaga: turno.vaga,
                verificacao: turno.verificacao,
                valorAcordado: turno.valorAcordado,
                contato: nil
            )
        }
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
        let decoder = JSONDecoder()
        return try modelContext.fetch(FetchDescriptor<FuncaoPersistida>()).map {
            try decoder.decode(Funcao.self, from: $0.conteudo)
        }
    }

    public func enfileirar(_ acao: AcaoPendente) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        modelContext.insert(AcaoPendentePersistida(
            id: acao.id,
            tipo: acao.tipo.rawValue,
            conteudo: try encoder.encode(acao),
            instanteDoToque: acao.instanteDoToque
        ))
        try modelContext.save()
    }

    public func pendentes() throws -> [AcaoPendente] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let descritor = FetchDescriptor<AcaoPendentePersistida>(sortBy: [SortDescriptor(\.instanteDoToque)])
        return try modelContext.fetch(descritor).map { try decoder.decode(AcaoPendente.self, from: $0.conteudo) }
    }

    public func remover(id: UUID) throws {
        try modelContext.delete(model: AcaoPendentePersistida.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    public func limpar() throws {
        try modelContext.delete(model: TurnoPersistido.self)
        try modelContext.delete(model: FuncaoPersistida.self)
        try modelContext.delete(model: SessaoPersistida.self)
        try modelContext.delete(model: AcaoPendentePersistida.self)
        try modelContext.save()
    }
}
