import Foundation
import FrilaDominio
import Observation

/// As recusas do contrato para as três operações da equipe, com uma mensagem cada. O servidor é
/// quem decide: o `403 sem_permissao` com `sem_turno_cumprido` tem texto próprio.
enum MensagensDaEquipe {
    static func texto(_ erro: Error) -> String {
        guard let erro = erro as? ErroDaApi else { return TextosEquipeDeConfianca.erro }
        switch erro.codigo {
        case .semPermissao where erro.detalhes == "sem_turno_cumprido": return TextosEquipeDeConfianca.semTurnoCumprido
        case .semPermissao where erro.detalhes == "conta_suspensa", .contaSuspensa: return TextosEquipeDeConfianca.contaSuspensa
        case .semPermissao: return TextosEquipeDeConfianca.soAdministrador
        case .naoEncontrado: return TextosEquipeDeConfianca.indisponivel
        case .semRede: return TextosEquipeDeConfianca.semRede
        default: return TextosEquipeDeConfianca.erro
        }
    }
}

/// A tela "Equipe de confiança" do estabelecimento (#24): lista `equipeDeConfianca` e remove com
/// `removerDaEquipe`, depois da confirmação na tela.
@MainActor @Observable
public final class EquipeDeConfiancaViewModel {
    public enum Estado: Equatable, Sendable {
        case carregando
        case vazio
        case conteudo([PerfilPublico])
        case semRede
        case erro
    }

    public private(set) var estado: Estado = .carregando
    /// O profissional cuja remoção está em voo.
    public private(set) var removendo: UUID?
    public private(set) var mensagemErro: String?
    public private(set) var aviso: String?
    public let estabelecimentoID: UUID

    private let listarEquipe: @Sendable (UUID) async throws -> [PerfilPublico]
    private let removerMembro: @Sendable (MembroDaEquipe) async throws -> MembroDaEquipe

    public init(
        estabelecimentoID: UUID,
        listar: @escaping @Sendable (UUID) async throws -> [PerfilPublico],
        remover: @escaping @Sendable (MembroDaEquipe) async throws -> MembroDaEquipe
    ) {
        self.estabelecimentoID = estabelecimentoID
        listarEquipe = listar
        removerMembro = remover
    }

    public convenience init(estabelecimentoID: UUID, api: any ApiCliente) {
        self.init(
            estabelecimentoID: estabelecimentoID,
            listar: { try await api.equipeDeConfianca(estabelecimentoID: $0) },
            remover: { try await api.removerDaEquipe($0) }
        )
    }

    public var membros: [PerfilPublico] {
        if case let .conteudo(membros) = estado { membros } else { [] }
    }

    public func carregar() async {
        estado = .carregando
        mensagemErro = nil
        do {
            let membros = try await listarEquipe(estabelecimentoID)
            estado = membros.isEmpty ? .vazio : .conteudo(membros)
        } catch let erroApi as ErroDaApi where erroApi.codigo == .semRede {
            estado = .semRede
        } catch {
            estado = .erro
        }
    }

    public func remover(_ perfil: PerfilPublico) async {
        guard removendo == nil else { return }
        removendo = perfil.id
        mensagemErro = nil
        aviso = nil
        defer { removendo = nil }
        do {
            _ = try await removerMembro(MembroDaEquipe(estabelecimentoID: estabelecimentoID, profissionalID: perfil.id))
            let restantes = membros.filter { $0.id != perfil.id }
            estado = restantes.isEmpty ? .vazio : .conteudo(restantes)
            aviso = TextosEquipeDeConfianca.removido
        } catch {
            mensagemErro = MensagensDaEquipe.texto(error)
        }
    }
}

/// "Incluir na equipe" onde o contratante vê um profissional que cumpriu turno na casa (#24). Lê a
/// equipe para saber se ele já está nela; a inclusão em si é decidida pelo servidor.
@MainActor @Observable
public final class IncluirNaEquipeViewModel {
    public enum Situacao: Equatable, Sendable {
        case desconhecida
        case foraDaEquipe
        case naEquipe
    }

    public private(set) var situacao: Situacao = .desconhecida
    public private(set) var incluindo = false
    public private(set) var mensagemErro: String?
    public let membro: MembroDaEquipe

    private let listarEquipe: @Sendable (UUID) async throws -> [PerfilPublico]
    private let incluirMembro: @Sendable (MembroDaEquipe) async throws -> MembroDaEquipe

    public init(
        membro: MembroDaEquipe,
        listar: @escaping @Sendable (UUID) async throws -> [PerfilPublico],
        incluir: @escaping @Sendable (MembroDaEquipe) async throws -> MembroDaEquipe
    ) {
        self.membro = membro
        listarEquipe = listar
        incluirMembro = incluir
    }

    public convenience init(membro: MembroDaEquipe, api: any ApiCliente) {
        self.init(
            membro: membro,
            listar: { try await api.equipeDeConfianca(estabelecimentoID: $0) },
            incluir: { try await api.incluirNaEquipe($0) }
        )
    }

    /// Falhou a leitura: o botão aparece mesmo assim, e o servidor responde na inclusão.
    public func carregar() async {
        do {
            let equipe = try await listarEquipe(membro.estabelecimentoID)
            situacao = equipe.contains { $0.id == membro.profissionalID } ? .naEquipe : .foraDaEquipe
        } catch {
            situacao = .foraDaEquipe
        }
    }

    public func incluir() async {
        guard !incluindo, situacao != .naEquipe else { return }
        incluindo = true
        mensagemErro = nil
        defer { incluindo = false }
        do {
            _ = try await incluirMembro(membro)
            situacao = .naEquipe
        } catch {
            mensagemErro = MensagensDaEquipe.texto(error)
        }
    }
}
