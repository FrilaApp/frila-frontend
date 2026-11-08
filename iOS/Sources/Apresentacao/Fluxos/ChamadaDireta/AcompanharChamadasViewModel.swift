import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class AcompanharChamadasViewModel {
    public let vagaID: UUID
    public private(set) var chamadas: [ChamadaResumo] = []
    public private(set) var carregando = false
    public private(set) var acaoEmVoo = false
    public private(set) var erro: String?
    public private(set) var sucessoMensagem: String?
    public private(set) var vagaPublicadaNovaID: UUID?

    private let api: any ApiCliente
    private let formatador = FormatadorFrila()

    public init(vagaID: UUID, api: any ApiCliente) {
        self.vagaID = vagaID
        self.api = api
    }

    public var temChamadaAceita: Bool {
        chamadas.contains { $0.estado == .aceita }
    }

    public var podePublicarParaTodos: Bool {
        guard !chamadas.isEmpty, !temChamadaAceita, vagaPublicadaNovaID == nil, !acaoEmVoo else { return false }
        // Se todas as chamadas foram recusadas, expiradas ou canceladas
        return chamadas.allSatisfy { $0.estado == .recusada || $0.estado == .expirada || $0.estado == .cancelada || $0.estado == .encerrada }
    }

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        erro = nil
        defer { carregando = false }

        do {
            let todas = try await api.minhasChamadas(estado: nil, cursor: nil, limite: 20)
            chamadas = todas.filter { $0.vagaID == vagaID }
        } catch let apiErro as ErroDaApi {
            if apiErro.recursoDesligado {
                erro = TextosChamadaDireta.desligado
            } else {
                erro = TextosChamadaDireta.erro
            }
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func cancelar(chamadaID: UUID) async {
        guard !acaoEmVoo else { return }
        acaoEmVoo = true
        erro = nil
        sucessoMensagem = nil
        defer { acaoEmVoo = false }

        do {
            _ = try await api.cancelarChamada(id: chamadaID)
            sucessoMensagem = TextosChamadaDireta.chamadaCanceladaSucesso
            await carregar()
        } catch let apiErro as ErroDaApi {
            if apiErro.codigo == .chamadaIndisponivel {
                erro = "A chamada já foi respondida ou não pode mais ser cancelada."
            } else {
                erro = TextosChamadaDireta.erro
            }
            await carregar()
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func publicarParaTodos(chave: UUID = UUID()) async {
        guard podePublicarParaTodos, !acaoEmVoo else { return }
        acaoEmVoo = true
        erro = nil
        sucessoMensagem = nil
        defer { acaoEmVoo = false }

        do {
            let publicada = try await api.publicarAPartirDaChamada(vagaID: vagaID, chave: chave, modo: .urgencia)
            vagaPublicadaNovaID = publicada.id
            sucessoMensagem = TextosChamadaDireta.vagaPublicadaSucesso
            await carregar()
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func rotuloEstado(_ estado: EstadoChamada) -> String {
        switch estado {
        case .aberta: return TextosChamadaDireta.statusAberta
        case .aceita: return TextosChamadaDireta.statusAceita
        case .recusada: return TextosChamadaDireta.statusRecusada
        case .expirada: return TextosChamadaDireta.statusExpirada
        case .cancelada: return TextosChamadaDireta.statusCancelada
        case .encerrada: return TextosChamadaDireta.statusEncerrada
        }
    }
}
