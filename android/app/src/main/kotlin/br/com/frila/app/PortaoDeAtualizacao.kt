package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import br.com.frila.core.designsystem.componentes.ComparadorDeVersao
import br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Modelo de configuração pública do app (paridade com `ConfiguracaoDoApp` do contrato OpenAPI 0.2.45).
 */
@Serializable
data class ConfiguracaoDoAppDto(
    val plataforma: String,
    @SerialName("versao_minima")
    val versaoMinima: String,
    @SerialName("versao_recomendada")
    val versaoRecomendada: String? = null,
    @SerialName("url_da_loja")
    val urlDaLoja: String? = null,
    val mensagem: String? = null,
)

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
