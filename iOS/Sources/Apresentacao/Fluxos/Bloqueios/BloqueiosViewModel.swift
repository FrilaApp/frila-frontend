import Foundation
import FrilaDominio
import Observation

/// Gerencia a listagem e o desbloqueio de usuários e estabelecimentos (decisão A8 da PO, RF26, v0.2.51).
@MainActor @Observable
public final class BloqueiosViewModel {
    public enum Estado: Equatable {
        case carregando
        case vazio
        case conteudo([ItemBloqueio])
        case offline([ItemBloqueio])
        case erro(String)
    }

    public private(set) var estado: Estado = .carregando
    public private(set) var itens: [ItemBloqueio] = []
    public private(set) var desbloqueandoID: UUID?
    public private(set) var mensagemErro: String?
    public private(set) var aviso: String?

    private let api: any ApiCliente
    private let bloqueiosDaSessao: BloqueiosDaSessao?

    public init(api: any ApiCliente, bloqueiosDaSessao: BloqueiosDaSessao? = nil) {
        self.api = api
        self.bloqueiosDaSessao = bloqueiosDaSessao
    }

    public func carregar() async {
        if itens.isEmpty {
            estado = .carregando
        }
        mensagemErro = nil
        aviso = nil
        do {
            let resultado = try await api.bloqueios()
            itens = resultado
            if resultado.isEmpty {
                estado = .vazio
            } else {
                estado = .conteudo(resultado)
            }
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            if !itens.isEmpty {
                estado = .offline(itens)
                aviso = TextosBloqueios.avisoOffline
            } else {
                estado = .erro(TextosBloqueios.semRede)
            }
        } catch {
            if !itens.isEmpty {
                mensagemErro = TextosBloqueios.erroCarregar
            } else {
                estado = .erro(TextosBloqueios.erroCarregar)
            }
        }
    }

    public func desbloquear(_ item: ItemBloqueio) async {
        guard desbloqueandoID == nil else { return }
        desbloqueandoID = item.id
        mensagemErro = nil
        defer { desbloqueandoID = nil }
        do {
            _ = try await api.desbloquear(item.alvo)
            bloqueiosDaSessao?.remover(item.alvo)
            itens.removeAll { $0.id == item.id }
            switch estado {
            case .offline:
                estado = itens.isEmpty ? .vazio : .offline(itens)
            default:
                estado = itens.isEmpty ? .vazio : .conteudo(itens)
            }
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            mensagemErro = TextosBloqueios.semRede
        } catch {
            mensagemErro = TextosBloqueios.erroDesbloquear
        }
    }
}
