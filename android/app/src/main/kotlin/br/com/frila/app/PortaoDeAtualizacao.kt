package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import br.com.frila.core.designsystem.componentes.ComparadorDeVersao
import br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Modelo de configuração pública do app (paridade com `ConfiguracaoDoApp` do contrato OpenAPI 0.2.45).
 */
data class ConfiguracaoDoAppDto(
    val plataforma: String,
    val versaoMinima: String,
    val versaoRecomendada: String? = null,
    val urlDaLoja: String? = null,
    val mensagem: String? = null,
)

/**
 * Consulta a configuração pública de versão na API remota Supabase (`GET /rest/v1/rpc/configuracao_do_app?plataforma=android`).
 * Lança [Exception] caso o backend retorne erro ou falhe a rede.
 */
suspend fun consultarConfiguracaoDoApp(
    cliente: ClienteSupabase,
): ConfiguracaoDoAppDto {
    val resposta = cliente.http.get(cliente.urlRpc("configuracao_do_app")) {
        parameter("plataforma", "android")
    }
    if (!resposta.status.isSuccess()) {
        throw IllegalStateException("Falha ao consultar configuracao do app: ${resposta.status}")
    }
    val json = Json.parseToJsonElement(resposta.bodyAsText()).jsonObject
    return ConfiguracaoDoAppDto(
        plataforma = json["plataforma"]?.jsonPrimitive?.contentOrNull ?: "android",
        versaoMinima = json["versao_minima"]?.jsonPrimitive?.contentOrNull.orEmpty(),
        versaoRecomendada = json["versao_recomendada"]?.jsonPrimitive?.contentOrNull,
        urlDaLoja = json["url_da_loja"]?.jsonPrimitive?.contentOrNull,
        mensagem = json["mensagem"]?.jsonPrimitive?.contentOrNull,
    )
}

/**
 * Portão de versão e atualização obrigatória (paridade com `PortaoDeAtualizacao` do iOS).
 *
 * Enquanto a verificação estiver pendente ([verificando] = true), não compõe o conteúdo do app,
 * impedindo que o feed ou rotas protegidas sejam expostos antes da decisão de versão mínima.
 * Se a versão atual for inferior à versão mínima exigida, bloqueia a navegação de todo o app
 * e exibe a [TelaAtualizacaoObrigatoria].
 * Caso contrário, libera a composição do [conteudo] principal.
 */
@Composable
fun PortaoDeAtualizacao(
    versaoAtual: String = BuildConfig.VERSION_NAME,
    versaoMinima: String? = null,
    verificando: Boolean = false,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    aoAtualizar: () -> Unit = {},
    conteudo: @Composable () -> Unit,
) {
    if (verificando) {
        return
    }

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
