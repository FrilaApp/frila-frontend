// TEXTOS PROVISÓRIOS do push (#8). Não há texto aprovado no frila-docs: a atividade "Permissões e
// notificações" do Design e do Produto ainda não aconteceu. Tudo o que o push escreve na tela e
// ainda não foi aprovado fica só neste arquivo; quando o texto chegar, muda aqui.

import Foundation
import FrilaDominio

enum TextosDoPush {
    /// A tela de explicação, antes do pedido do sistema.
    enum Explicacao {
        static let titulo = String(localized: "Ative as notificações", bundle: bundleApresentacao)
        static let ativar = String(localized: "Ativar notificações", bundle: bundleApresentacao)
        static let agoraNao = String(localized: "Agora não", bundle: bundleApresentacao)
        static let rodape = String(localized: "Você pode mudar isso quando quiser, nos Ajustes do iPhone.", bundle: bundleApresentacao)

        static func mensagem(_ perfil: PerfilConta) -> String {
            switch perfil {
            case .profissional:
                String(localized: "É pela notificação que você fica sabendo de uma vaga nova perto de você, na hora em que ela é publicada.", bundle: bundleApresentacao)
            case .contratante:
                String(localized: "É pela notificação que você fica sabendo quando alguém aceita a sua vaga e quando a pessoa chega para o turno.", bundle: bundleApresentacao)
            }
        }

        static func itens(_ perfil: PerfilConta) -> [String] {
            switch perfil {
            case .profissional: [
                String(localized: "Vaga nova na sua função e na sua região", bundle: bundleApresentacao),
                String(localized: "Confirmação e lembretes do seu turno", bundle: bundleApresentacao),
                String(localized: "Aviso quando um turno seu é cancelado", bundle: bundleApresentacao),
            ]
            case .contratante: [
                String(localized: "Confirmação de quem vai trabalhar", bundle: bundleApresentacao),
                String(localized: "Check-in, atraso e vaga que ainda está sem ninguém", bundle: bundleApresentacao),
                String(localized: "Aviso quando alguém cancela", bundle: bundleApresentacao),
            ]
            }
        }
    }

    /// O aviso fixo em Vagas e em Minhas vagas.
    enum Aviso {
        static let abrirAjustes = String(localized: "Abrir os Ajustes", bundle: bundleApresentacao)

        /// A pessoa recusou o pedido do sistema, ou desligou as notificações nos Ajustes.
        static func negada(_ perfil: PerfilConta) -> String {
            switch perfil {
            case .profissional:
                String(localized: "As notificações estão desativadas. Você não recebe o aviso de vaga nova nem os lembretes dos seus turnos.", bundle: bundleApresentacao)
            case .contratante:
                String(localized: "As notificações estão desativadas. Você não recebe o aviso de quem aceitou a vaga, de check-in nem de atraso.", bundle: bundleApresentacao)
            }
        }

        /// O sistema ainda não perguntou: a pessoa adiou, ou já usava o app antes de o push existir.
        static func naoPedida(_ perfil: PerfilConta) -> String {
            switch perfil {
            case .profissional:
                String(localized: "Ative as notificações para saber de uma vaga nova na hora.", bundle: bundleApresentacao)
            case .contratante:
                String(localized: "Ative as notificações para saber quando alguém aceita a sua vaga.", bundle: bundleApresentacao)
            }
        }
    }

    /// O aviso trouxe um turno que não está entre os da conta que está no aparelho.
    enum Turno {
        static let naoEncontradoTitulo = String(localized: "Não encontramos este turno", bundle: bundleApresentacao)
        static let naoEncontradoMensagem = String(localized: "Ele não está entre os turnos desta conta.", bundle: bundleApresentacao)
        static let verMeusTurnos = String(localized: "Ver meus turnos", bundle: bundleApresentacao)
        static let falha = String(localized: "Não foi possível abrir este turno.", bundle: bundleApresentacao)
    }
}
