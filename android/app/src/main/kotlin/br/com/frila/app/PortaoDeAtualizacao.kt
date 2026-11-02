package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import br.com.frila.core.designsystem.componentes.ComparadorDeVersao
import br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria

/**
 * Portão de versão e atualização obrigatória (paridade com `PortaoDeAtualizacao` do iOS).
 *
 * Avalia se a versão atual do app instalada é inferior à versão mínima exigida.
 * Se for inferior, bloqueia a navegação de todo o app e exibe a [TelaAtualizacaoObrigatoria].
 * Caso contrário, libera a composição do [conteudo] principal.
 */
@Composable
fun PortaoDeAtualizacao(
    versaoAtual: String = BuildConfig.VERSION_NAME,
    versaoMinima: String? = null,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    aoAtualizar: () -> Unit = {},
    conteudo: @Composable () -> Unit,
) {
    val precisaAtualizar = remember(versaoAtual, versaoMinima) {
        versaoMinima != null && ComparadorDeVersao.precisaAtualizar(versaoAtual, versaoMinima)
    }

    if (precisaAtualizar) {
        TelaAtualizacaoObrigatoria(
            aoAtualizar = aoAtualizar,
            mensagem = mensagem,
        )
    } else {
        conteudo()
    }
}
