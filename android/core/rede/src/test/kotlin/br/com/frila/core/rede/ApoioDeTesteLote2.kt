package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue

/** O que o servidor falso viu do pedido: quantas vezes, método, rota, corpo e cabeçalhos. */
internal class PedidoVisto {
    var vezes = 0
    var metodo: HttpMethod? = null
    var caminho: String? = null
    var corpo: JsonObject? = null
    var apikey: String? = null
    var autorizacao: String? = null
    var tipoDoCorpo: String? = null

    /** Rota, método e cabeçalhos de toda chamada do Lote 2: um POST em `/rest/v1/rpc/<nome>`, com a chave, o token e JSON. */
    fun conferirPost(rpc: String) {
        assertEquals(1, vezes, "a chamada sai uma vez só")
        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/$rpc", caminho)
        assertEquals("chave-teste", apikey)
        assertEquals("Bearer token-teste", autorizacao)
        assertEquals("application/json", tipoDoCorpo)
    }
}

/** Cliente com sessão (token sintético) contra um servidor falso que sempre responde [resposta] com [status]. */
internal fun clienteDeTeste(visto: PedidoVisto, resposta: String, status: HttpStatusCode = HttpStatusCode.OK): ClienteSupabase {
    val engine = MockEngine { request ->
        visto.vezes++
        visto.metodo = request.method
        visto.caminho = request.url.encodedPath
        visto.apikey = request.headers["apikey"]
        visto.autorizacao = request.headers[HttpHeaders.Authorization]
        val corpo = request.body as? TextContent
        visto.tipoDoCorpo = corpo?.contentType?.withoutParameters()?.toString()
        visto.corpo = corpo?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it.text).jsonObject }
        respond(resposta, status, headersOf(HttpHeaders.ContentType, "application/json"))
    }
    return ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        provedorDeToken = ProvedorDeToken { "token-teste" },
        engine = engine,
    )
}

/** Uma recusa que o contrato declara para a ação: status, `code`, `details` e o código de domínio esperado. */
internal data class Recusa(
    val status: HttpStatusCode,
    val codigo: String,
    val esperado: CodigoErroAPI,
    val detalhes: String? = null,
)

/** O envelope de erro do contrato (schema `Erro`): `code`, `message`, `details` e `hint`. */
internal fun envelopeDeErro(codigo: String, detalhes: String? = null): String {
    val details = detalhes?.let { "\"$it\"" } ?: "null"
    return """{"code":"$codigo","message":"$codigo","details":$details,"hint":null}"""
}

internal suspend fun erroDaApiDe(bloco: suspend () -> Unit): ErroDaApi {
    val excecao = runCatching { bloco() }.exceptionOrNull()
    assertTrue(excecao is ErroDaApi, "esperava ErroDaApi, veio $excecao")
    return excecao as ErroDaApi
}

/** Cada recusa vira [ErroDaApi] com o código de domínio, o código cru do servidor e os `details`. */
internal suspend fun conferirRecusas(recusas: List<Recusa>, chamar: suspend (ClienteSupabase) -> Unit) {
    for (recusa in recusas) {
        val cliente = clienteDeTeste(PedidoVisto(), envelopeDeErro(recusa.codigo, recusa.detalhes), recusa.status)

        val erro = erroDaApiDe { chamar(cliente) }

        val caso = "${recusa.status.value} ${recusa.codigo} ${recusa.detalhes.orEmpty()}"
        assertEquals(recusa.esperado, erro.codigo, caso)
        assertEquals(recusa.codigo, erro.codigoOriginal, caso)
        assertEquals(recusa.detalhes, erro.detalhes, caso)
    }
}

internal val TOKEN_VENCIDO = Recusa(HttpStatusCode.Unauthorized, "PGRST301", CodigoErroAPI.NAO_AUTENTICADO)
internal val CONTA_SUSPENSA = Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa")
