import Foundation
import FrilaDominio

/// Última leitura de rede guardada na memória: o detalhe da vaga e a primeira página da lista.
/// Serve para mostrar algo na hora, e para o Meu turno e a presença não pedirem o mesmo detalhe
/// duas vezes. Some ao sair da conta e ao encerrar o app; nada vai para o disco.
public final class CacheDeLeituras: @unchecked Sendable {
    public static let compartilhado = CacheDeLeituras()

    /// O detalhe usado só para o responsável e o ponto (que quase não mudam) vale por este prazo.
    static let validade: TimeInterval = 300

    private struct Detalhe { let vaga: Vaga; let salvoEm: Date }

    private let trava = NSLock()
    private var detalhes: [UUID: Detalhe] = [:]
    private var listas: [String: [VagaNaLista]] = [:]
    private var detalhesEmVoo: [UUID: Task<Vaga, Error>] = [:]
    private var epocaAtual: UInt64 = 0
    private let agora: @Sendable () -> Date

    /// Identifica a sessão do cache; respostas iniciadas antes de limpar não podem repovoá-lo.
    public var epoca: UInt64 { trava.withLock { epocaAtual } }

    public init(agora: @escaping @Sendable () -> Date = { Date() }) {
        self.agora = agora
    }

    // MARK: Detalhe da vaga

    /// O último detalhe guardado, qualquer que seja a idade. Para mostrar enquanto atualiza.
    public func detalheGuardado(id: UUID) -> Vaga? {
        trava.withLock { detalhes[id]?.vaga }
    }

    /// Detalhe dentro da validade; senão busca. Pedidos iguais ao mesmo tempo viram um só.
    public func detalhe(id: UUID, buscar: @escaping @Sendable () async throws -> Vaga) async throws -> Vaga {
        try await detalhe(id: id, aceitandoGuardado: true, buscar: buscar)
    }

    /// Sempre vai à rede, mas junta com um pedido igual que já esteja em voo.
    public func detalheAtual(id: UUID, buscar: @escaping @Sendable () async throws -> Vaga) async throws -> Vaga {
        try await detalhe(id: id, aceitandoGuardado: false, buscar: buscar)
    }

    private func detalhe(
        id: UUID,
        aceitandoGuardado: Bool,
        buscar: @escaping @Sendable () async throws -> Vaga
    ) async throws -> Vaga {
        enum Caminho { case guardado(Vaga), emVoo(Task<Vaga, Error>), novo(Task<Vaga, Error>, UInt64) }
        let caminho = trava.withLock { () -> Caminho in
            if aceitandoGuardado, let d = detalhes[id], agora().timeIntervalSince(d.salvoEm) < Self.validade {
                return .guardado(d.vaga)
            }
            if let voo = detalhesEmVoo[id] { return .emVoo(voo) }
            let tarefa = Task { try await buscar() }
            detalhesEmVoo[id] = tarefa
            return .novo(tarefa, epocaAtual)
        }
        switch caminho {
        case let .guardado(vaga): return vaga
        case let .emVoo(tarefa): return try await tarefa.value
        case let .novo(tarefa, epoca):
            do {
                let vaga = try await tarefa.value
                trava.withLock {
                    if epoca == epocaAtual {
                        detalhes[id] = Detalhe(vaga: vaga, salvoEm: agora())
                    }
                    if detalhesEmVoo[id] == tarefa { detalhesEmVoo[id] = nil }
                }
                return vaga
            } catch {
                trava.withLock {
                    if detalhesEmVoo[id] == tarefa { detalhesEmVoo[id] = nil }
                }
                throw error
            }
        }
    }

    // MARK: Lista

    public func lista(chave: String) -> [VagaNaLista]? {
        trava.withLock { listas[chave] }
    }

    public func guardar(lista: [VagaNaLista], chave: String, epoca: UInt64) {
        trava.withLock {
            guard epoca == epocaAtual else { return }
            listas[chave] = lista
        }
    }

    // MARK: Limpeza

    public func limpar() {
        trava.withLock {
            epocaAtual &+= 1
            detalhes = [:]
            listas = [:]
            detalhesEmVoo.values.forEach { $0.cancel() }
            detalhesEmVoo = [:]
        }
    }
}
