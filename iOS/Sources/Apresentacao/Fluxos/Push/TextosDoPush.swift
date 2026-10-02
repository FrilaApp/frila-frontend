// TEXTOS PROVISÓRIOS do push (#8). Não há texto aprovado no frila-docs: a atividade "Permissões e
// notificações" do Design e do Produto ainda não aconteceu. Tudo o que o push escreve na tela e
// ainda não foi aprovado fica só neste arquivo; quando o texto chegar, muda aqui.

import Foundation

enum TextosDoPush {
    /// O aviso trouxe um turno que não está entre os da conta que está no aparelho.
    enum Turno {
        static let naoEncontradoTitulo = String(localized: "Não encontramos este turno", bundle: bundleApresentacao)
        static let naoEncontradoMensagem = String(localized: "Ele não está entre os turnos desta conta.", bundle: bundleApresentacao)
        static let verMeusTurnos = String(localized: "Ver meus turnos", bundle: bundleApresentacao)
        static let falha = String(localized: "Não foi possível abrir este turno.", bundle: bundleApresentacao)
    }
}
