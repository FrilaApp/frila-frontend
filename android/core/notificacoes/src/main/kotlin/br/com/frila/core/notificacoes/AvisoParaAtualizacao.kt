package br.com.frila.core.notificacoes

import br.com.frila.core.dominio.regra.AtualizacaoAutomatica

/**
 * O push que chegou com o app aberto é um sinal para as listas abertas relerem (HaRJJ0L0). Só o push da conta ativa conta: o
 * de outra conta chega neutralizado ([ValidadorIsolamentoConta]) e não mexe em lista nenhuma, como o aviso "da conta na tela" do iOS.
 */
object AvisoParaAtualizacao {
    fun sinalizar(notificacao: NotificacaoParaExibir, atualizacao: AtualizacaoAutomatica) {
        if (!notificacao.neutralizada) atualizacao.avisoChegou()
    }
}
