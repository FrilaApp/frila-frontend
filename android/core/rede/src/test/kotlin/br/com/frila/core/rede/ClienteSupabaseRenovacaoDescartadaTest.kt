package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Nits do #1067 (wo61FqLa, P3): o que acontece depois de uma renovação de A descartada porque B entrou. Duas renovações da mesma
 * conta juntas já têm teste (`ClienteSupabaseRefreshTest`, "requisicoes concorrentes com 401 compartilham uma unica renovacao").
 */
class ClienteSupabaseRenovacaoDescartadaTest {

    private fun sessao(conta: String, versao: Int = 1) =
        Sessao("access-$conta-$versao", "refresh-$conta-$versao", "bearer", 3_600L, vinculoId = "vinculo-$conta")

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val expirado = """{"code":"PGRST301","message":"JWT expired"}"""

    @Test
    fun `renovacao de A descartada pela entrada de B nao repete a chamada de A, e a seguinte de B vai com o token de B`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao("A")) }
        val autorizacoes = CopyOnWriteArrayList<String?>()
        val renovacaoEmVoo = CompletableDeferred<Unit>()
        val portao = CompletableDeferred<Unit>()
        val engine = MockEngine { pedido ->
            if (pedido.url.encodedPath == "/auth/v1/token") {
                renovacaoEmVoo.complete(Unit)
                portao.await()
                respond("""{"access_token":"access-A-2","refresh_token":"refresh-A-2","token_type":"bearer","expires_in":3600}""", HttpStatusCode.OK, json)
            } else {
                val autorizacao = pedido.headers[HttpHeaders.Authorization]
                autorizacoes += autorizacao
                if (autorizacao == "Bearer access-A-1") {
                    respond(expirado, HttpStatusCode.Unauthorized, headersOf(HttpHeaders.WWWAuthenticate, "Bearer"))
                } else {
                    respond("{}", HttpStatusCode.OK, json)
                }
            }
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", armazenamentoDeSessao = armazenamento, engine = engine)

        val chamadaDeA = async(Dispatchers.Default) { runCatching { cliente.http.get(cliente.urlRpc("minha_conta")) } }
        renovacaoEmVoo.await()
        armazenamento.limparSessao()
        armazenamento.salvarSessao(sessao("B"))
        portao.complete(Unit)
        val respostaDeA = chamadaDeA.await().getOrThrow()

        // A renovação descartada não devolve o token novo de A: a chamada de A não é repetida depois que A saiu.
        assertEquals(HttpStatusCode.Unauthorized, respostaDeA.status)
        assertEquals(listOf("Bearer access-A-1"), autorizacoes.toList())
        autorizacoes.clear()

        val deB = cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals(HttpStatusCode.OK, deB.status)
        assertEquals(listOf("Bearer access-B-1"), autorizacoes.toList())
        assertEquals(sessao("B"), armazenamento.obterSessao())
    }
}
