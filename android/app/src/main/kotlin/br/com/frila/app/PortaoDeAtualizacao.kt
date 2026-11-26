package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import br.com.frila.core.rede.RegistradorDeTelemetria
import br.com.frila.core.rede.EventoDeTelemetria
import org.koin.core.context.GlobalContext
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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Recursos liberados para esta versão do app (contrato OpenAPI 0.2.70).
 */
data class RecursosDoAppDto(
    val fotoDePerfil: Boolean = false,
    val chamadaDireta: Boolean = false,
    val perfilRico: Boolean = false,
    val checkinPorCodigo: Boolean = false,
    /** Busca de profissionais (contrato 0.2.88); desligada por padrão. */
    val buscaProfissionais: Boolean = false,
)

/**
 * Modelo de configuração pública do app (paridade com `ConfiguracaoDoApp` do contrato OpenAPI 0.2.70).
 */
data class ConfiguracaoDoAppDto(
    val plataforma: String,
    val versaoMinima: String,
    val versaoRecomendada: String? = null,
    val urlDaLoja: String? = null,
    val mensagem: String? = null,
    val recursos: RecursosDoAppDto = RecursosDoAppDto(),
)

/**
 * Consulta a configuração pública de versão na API remota Supabase (`GET /rest/v1/rpc/configuracao_do_app?plataforma=android`).
 * Lança [Exception] caso o backend retorne erro ou falhe a rede.
 */
suspend fun consultarConfiguracaoDoApp(
    cliente: ClienteSupabase,
    versaoApp: String? = BuildConfig.VERSION_NAME,
): ConfiguracaoDoAppDto {
    val resposta = cliente.http.get(cliente.urlRpc("configuracao_do_app")) {
        parameter("plataforma", "android")
        versaoApp?.let { parameter("versao_app", it) }
    }
    if (!resposta.status.isSuccess()) {
        throw IllegalStateException("Falha ao consultar configuracao do app: ${resposta.status}")
    }
    return configuracaoDoAppDeJson(Json.parseToJsonElement(resposta.bodyAsText()).jsonObject)
}

/** Lê o JSON de `configuracao_do_app` (o mesmo formato que o app guarda em [CacheDeConfiguracaoDoApp]). */
internal fun configuracaoDoAppDeJson(json: JsonObject): ConfiguracaoDoAppDto {
    val recursos = json["recursos"] as? JsonObject
    return ConfiguracaoDoAppDto(
        plataforma = json["plataforma"]?.jsonPrimitive?.contentOrNull ?: "android",
        versaoMinima = json["versao_minima"]?.jsonPrimitive?.contentOrNull.orEmpty(),
        versaoRecomendada = json["versao_recomendada"]?.jsonPrimitive?.contentOrNull,
        urlDaLoja = json["url_da_loja"]?.jsonPrimitive?.contentOrNull,
        mensagem = json["mensagem"]?.jsonPrimitive?.contentOrNull,
        recursos = RecursosDoAppDto(
            fotoDePerfil = recursos?.get("foto_de_perfil")?.jsonPrimitive?.booleanOrNull ?: false,
            chamadaDireta = recursos?.get("chamada_direta")?.jsonPrimitive?.booleanOrNull ?: false,
            perfilRico = recursos?.get("perfil_rico")?.jsonPrimitive?.booleanOrNull ?: false,
            checkinPorCodigo = recursos?.get("checkin_por_codigo")?.jsonPrimitive?.booleanOrNull ?: false,
            buscaProfissionais = recursos?.get("busca_profissionais")?.jsonPrimitive?.booleanOrNull ?: false,
        ),
    )
}

/**
 * Portão de versão e atualização obrigatória (paridade com `PortaoDeAtualizacao` do iOS).
 *
 * Enquanto a abertura estiver pendente ([verificando] = true), não compõe o conteúdo do app.
 * Essa espera é curta e termina em [carregarConfiguracaoNaAbertura]: na hora, quando há
 * configuração guardada para esta versão do app, ou em até [TEMPO_MAXIMO_ABERTURA_MS] (2 s),
 * quando não há. Depois disso o [conteudo] pode aparecer antes da resposta do servidor, e a
 * resposta, quando chega (até [TEMPO_MAXIMO_CONFIGURACAO_MS]), ainda vale: se a versão atual
 * for inferior à mínima, passa a bloquear a navegação de todo o app (#795). Ou seja, o portão
 * não garante que o feed ou rotas protegidas não apareçam antes da decisão de versão mínima
 * do servidor; garante só a decisão da versão mínima guardada.
 * Se a versão atual for inferior à versão mínima conhecida, exibe a [TelaAtualizacaoObrigatoria]
 * no lugar do app. Caso contrário, compõe o [conteudo] principal.
 */
@Composable
fun PortaoDeAtualizacao(
    versaoAtual: String = BuildConfig.VERSION_NAME,
    versaoMinima: String? = null,
    verificando: Boolean = false,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    aoAtualizar: () -> Unit = {},
    registrarExibicao: () -> Unit = {
        GlobalContext.getOrNull()?.getOrNull<RegistradorDeTelemetria>()
            ?.disparar(EventoDeTelemetria.ATUALIZACAO_OBRIGATORIA_EXIBIDA)
    },
    conteudo: @Composable () -> Unit,
) {
    if (verificando) {
        return
    }

    val precisaAtualizar = remember(versaoAtual, versaoMinima) {
        versaoMinima != null && ComparadorDeVersao.precisaAtualizar(versaoAtual, versaoMinima)
    }

    if (precisaAtualizar) {
        LaunchedEffect(Unit) { registrarExibicao() }
        TelaAtualizacaoObrigatoria(
            aoAtualizar = aoAtualizar,
            mensagem = mensagem,
        )
    } else {
        conteudo()
    }
}
