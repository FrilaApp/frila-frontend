import Foundation
import FrilaDominio
import Observation

/// A permissão de notificação como as telas a veem (#8): o estado, a tela de explicação e o pedido
/// do sistema. Um por app, entregue às telas pelo ambiente do SwiftUI.
///
/// O pedido do sistema só aparece uma vez na vida do app, então ele nunca sai sozinho: primeiro a
/// tela de explicação, no momento em que a notificação passa a fazer sentido (o profissional salvou
/// funções e horários; o contratante publicou a vaga), e o pedido só depois de "Ativar notificações".
/// A explicação aparece no máximo uma vez por sessão do app (uma abertura); o caminho de volta é
/// o aviso fixo em Vagas e em Minhas vagas.
@MainActor @Observable
public final class PermissaoDePushModelo {
    /// `nil` até a primeira leitura.
    public private(set) var estado: EstadoDaPermissaoDePush?
    public var explicacaoVisivel = false {
        didSet {
            if explicacaoVisivel { jaMostradaNaSessao = true }
        }
    }
    public private(set) var pedindo = false
    /// Estado em memória: a explicação só aparece sozinha uma vez por sessão (#8).
    public private(set) var jaMostradaNaSessao = false

    private let permissao: any PermissaoDePush
    private let abrirAjustesDoSistema: @MainActor () -> Void

    public init(permissao: any PermissaoDePush, abrirAjustes: @escaping @MainActor () -> Void = {}) {
        self.permissao = permissao
        abrirAjustesDoSistema = abrirAjustes
    }

    /// Na abertura e a cada volta ao primeiro plano: a pessoa pode ter mudado a permissão nos Ajustes.
    public func atualizar() async {
        estado = await permissao.estado()
    }

    /// O momento certo de explicar (#8). Só mostra a explicação sozinha a quem o sistema ainda não
    /// perguntou e no máximo uma vez por sessão do app: quem já viu (e adiou com "Agora não" ou
    /// dispensou) nesta abertura não é interrompido de novo; quem já respondeu ao sistema não vê
    /// o pedido de novo.
    public func oferecer() async {
        guard !jaMostradaNaSessao else { return }
        await atualizar()
        guard !jaMostradaNaSessao else { return }
        if estado == .naoPedida {
            jaMostradaNaSessao = true
            explicacaoVisivel = true
        }
    }

    /// Reabre a explicação a pedido da pessoa, pelo aviso fixo em Vagas ou em Minhas vagas (#8).
    /// Abre mesmo que a explicação já tenha aparecido nesta sessão.
    public func reabrir() async {
        await atualizar()
        if estado == .naoPedida {
            jaMostradaNaSessao = true
            explicacaoVisivel = true
        }
    }

    /// "Ativar notificações" na explicação: só aqui o pedido do sistema aparece.
    public func ativar() async {
        guard !pedindo else { return }
        pedindo = true
        defer { pedindo = false }
        estado = await permissao.pedir()
        explicacaoVisivel = false
    }

    /// "Agora não": a explicação fecha e o sistema não pergunta nada. O pedido fica guardado para
    /// quando a pessoa quiser, pelo aviso em Vagas ou em Minhas vagas.
    public func agoraNao() {
        explicacaoVisivel = false
    }

    public func abrirAjustes() {
        abrirAjustesDoSistema()
    }
}
