package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * #794 (risco alto: sessão). A renovação do token da conta A pode estar em voo quando a pessoa sai e a conta B entra no mesmo
 * processo. A resposta da renovação chega depois: ela não pode regravar a sessão de A (nem apagar a de B), porque a sessão
 * guardada já não é a que originou a renovação.
 *
 * O motor segura a resposta de `/auth/v1/token` num portão, para a troca de conta acontecer durante a espera. O armazenamento é
 * o em memória (a mesma interface do Keystore de produção).
 */
class ClienteSupabaseRefreshEmVooTest {

    private fun sessao(conta: String) = Sessao(
        accessToken = "access-$conta",
        refreshToken = "refresh-$conta",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = null,
    )

    private class Cenario(statusDoAuth: HttpStatusCode, corpoDoAuth: String) {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val portao = CompletableDeferred<Unit>()
        val renovacaoEmVoo = CompletableDeferred<Unit>()
        private val engine = MockEngine { pedido ->
            when {
                pedido.url.encodedPath == "/auth/v1/token" -> {
                    renovacaoEmVoo.complete(Unit)
                    portao.await()
                    respond(corpoDoAuth, statusDoAuth, headersOf(HttpHeaders.ContentType, "application/json"))
                }
                pedido.headers[HttpHeaders.Authorization] == "Bearer access-A" ->
                    respond("{}", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.ContentType, "application/json"))
                else -> respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )
    }

    private fun renovacaoOk(conta: String) =
        """{"access_token":"access-$conta-2","refresh_token":"refresh-$conta-2","token_type":"bearer","expires_in":3600}"""

    /** A pede, o `401` dispara a renovação, e [duranteARenovacao] roda enquanto a resposta dela está retida. */
    private fun comRenovacaoDeAEmVoo(cenario: Cenario, duranteARenovacao: () -> Unit) = runBlocking {
        cenario.armazenamento.salvarSessao(sessao("A"))
        val chamada = async(Dispatchers.Default) { runCatching { cenario.cliente.http.get(cenario.cliente.urlRpc("minha_conta")) } }
        cenario.renovacaoEmVoo.await()
        duranteARenovacao()
        cenario.portao.complete(Unit)
        chamada.await()
    }

    @Test
    fun `renovacao de A que termina depois de Sair e da entrada de B nao regrava a sessao de A`() {
        val cenario = Cenario(HttpStatusCode.OK, renovacaoOk("A"))

        comRenovacaoDeAEmVoo(cenario) {
            cenario.armazenamento.limparSessao()
            cenario.armazenamento.salvarSessao(sessao("B"))
        }

        assertEquals(sessao("B"), cenario.armazenamento.obterSessao())
    }

    @Test
    fun `renovacao de A que termina depois de Sair sem nova entrada nao recria a sessao de A`() {
        val cenario = Cenario(HttpStatusCode.OK, renovacaoOk("A"))

        comRenovacaoDeAEmVoo(cenario) { cenario.armazenamento.limparSessao() }

        assertEquals(null, cenario.armazenamento.obterSessao())
    }

    @Test
    fun `renovacao de A recusada pelo Auth depois da entrada de B nao apaga a sessao de B`() {
        val cenario = Cenario(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")

        comRenovacaoDeAEmVoo(cenario) {
            cenario.armazenamento.limparSessao()
            cenario.armazenamento.salvarSessao(sessao("B"))
        }

        assertEquals(sessao("B"), cenario.armazenamento.obterSessao())
    }

    @Test
    fun `renovacao sem troca de conta continua gravando a sessao renovada`() {
        val cenario = Cenario(HttpStatusCode.OK, renovacaoOk("A"))

        comRenovacaoDeAEmVoo(cenario) {}

        assertEquals("refresh-A-2", cenario.armazenamento.obterSessao()?.refreshToken)
        assertEquals("access-A-2", cenario.armazenamento.obterSessao()?.accessToken)
    }

    @Test
    fun `renovacao recusada sem troca de conta continua encerrando a sessao`() {
        val cenario = Cenario(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")

        comRenovacaoDeAEmVoo(cenario) {}

        assertEquals(null, cenario.armazenamento.obterSessao())
    }
}
