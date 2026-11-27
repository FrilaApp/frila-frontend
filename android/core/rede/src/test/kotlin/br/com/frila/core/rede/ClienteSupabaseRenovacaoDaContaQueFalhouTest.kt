package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.content.TextContent
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test

/**
 * P3 do time do Cauê no #1091 (En8IkArK): a chamada de A tomou 401 e, antes da renovação, B entrou no aparelho. A renovação não
 * pode partir da sessão de B, e a chamada de A não pode ser repetida com o token de B.
 */
class ClienteSupabaseRenovacaoDaContaQueFalhouTest {

    private val contaA = Sessao("access-a", "refresh-a", "bearer", 3_600L, vinculoId = "vinculo-a")
    private val contaB = Sessao("access-b", "refresh-b", "bearer", 3_600L, vinculoId = "vinculo-b")

    @Test
    fun `chamada de A que tomou 401 depois de B entrar nao e repetida com o token de B`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(contaA) }
        val autorizacoes = CopyOnWriteArrayList<String?>()
        val renovacoesPedidas = CopyOnWriteArrayList<String>()
        val json = headersOf(HttpHeaders.ContentType, "application/json")
        val engine = MockEngine { requisicao ->
            if (requisicao.url.encodedPath == "/auth/v1/token") {
                val corpo = (requisicao.body as TextContent).text
                renovacoesPedidas += corpo
                val conta = if ("refresh-b" in corpo) "b" else "a"
                respond("""{"access_token":"access-$conta-2","refresh_token":"refresh-$conta-2","token_type":"bearer","expires_in":3600}""", HttpStatusCode.OK, json)
            } else {
                autorizacoes += requisicao.headers[HttpHeaders.Authorization]
                if (autorizacoes.size == 1) {
                    // A resposta de A ainda não voltou e B entra no aparelho.
                    armazenamento.salvarSessao(contaB)
                    respond("""{"code":"PGRST301","message":"JWT expired"}""", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.WWWAuthenticate, "Bearer"))
                } else {
                    respond("{}", HttpStatusCode.OK, json)
                }
            }
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", armazenamentoDeSessao = armazenamento, engine = engine)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals("Bearer access-a", autorizacoes.first())
        assertFalse(autorizacoes.drop(1).any { it?.contains("access-b") == true }, "a chamada de A foi repetida com o token de B: $autorizacoes")
        assertFalse(renovacoesPedidas.any { "refresh-b" in it }, "a renovação partiu da sessão de B: $renovacoesPedidas")
        assertEquals(contaB, armazenamento.obterSessao(), "a sessão de B não pode ser trocada nem apagada pela renovação de A")
    }

    /**
     * Revisão do #1136 (Ibiki): no Ktor 2.3.12 o `oldTokens` é o que está no `AuthTokenHolder`, não o token da requisição que
     * tomou 401. Se outra chamada recarregou o holder com a sessão de B enquanto a de A estava em voo, o `oldTokens` já é de B.
     */
    @Test
    fun `chamada de A em voo, B entra e outra chamada recarrega o holder, e A nao e repetida com o token de B`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(contaA) }
        val autorizacoesDeA = CopyOnWriteArrayList<String?>()
        val renovacoesPedidas = CopyOnWriteArrayList<String>()
        val aChegou = CompletableDeferred<Unit>()
        val portaoDeA = CompletableDeferred<Unit>()
        val json = headersOf(HttpHeaders.ContentType, "application/json")
        val engine = MockEngine { requisicao ->
            when {
                requisicao.url.encodedPath == "/auth/v1/token" -> {
                    val corpo = (requisicao.body as TextContent).text
                    renovacoesPedidas += corpo
                    val conta = if ("refresh-b" in corpo) "b" else "a"
                    respond("""{"access_token":"access-$conta-2","refresh_token":"refresh-$conta-2","token_type":"bearer","expires_in":3600}""", HttpStatusCode.OK, json)
                }
                requisicao.url.encodedPath.endsWith("/minha_conta") -> {
                    autorizacoesDeA += requisicao.headers[HttpHeaders.Authorization]
                    if (autorizacoesDeA.size == 1) {
                        aChegou.complete(Unit)
                        portaoDeA.await()
                        respond("""{"code":"PGRST301","message":"JWT expired"}""", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.WWWAuthenticate, "Bearer"))
                    } else {
                        respond("{}", HttpStatusCode.OK, json)
                    }
                }
                else -> respond("{}", HttpStatusCode.OK, json)
            }
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", armazenamentoDeSessao = armazenamento, engine = engine)

        val chamadaDeA = async(Dispatchers.Default) { cliente.http.get(cliente.urlRpc("minha_conta")) }
        aChegou.await()
        armazenamento.salvarSessao(contaB)
        // Outra chamada, já com B guardado, recarrega o holder do Auth com a sessão de B.
        cliente.http.get(cliente.urlRpc("minhas_vagas"))
        portaoDeA.complete(Unit)
        chamadaDeA.await()

        assertEquals("Bearer access-a", autorizacoesDeA.first())
        assertFalse(autorizacoesDeA.drop(1).any { it?.contains("access-b") == true }, "a chamada de A foi repetida com o token de B: $autorizacoesDeA")
        assertFalse(renovacoesPedidas.any { "refresh-b" in it }, "a renovação de A girou o refresh de B: $renovacoesPedidas")
        assertEquals(contaB, armazenamento.obterSessao())
    }
}
