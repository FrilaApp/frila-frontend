package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * #789 (risco alto: sessão). O plugin `Auth`/`bearer` do Ktor guarda o token em memória depois do
 * primeiro `loadTokens`. Se a sessão é limpa ("Sair", exclusão, "outra conta", 401) sem recriar o
 * cliente, a conta que entra depois no mesmo processo mandava o token da anterior. Aqui o cliente é
 * o mesmo nos dois logins, de propósito: o token em memória nunca pode divergir da sessão guardada.
 */
class ClienteSupabaseTrocaDeContaTest {

    private fun sessao(conta: String) = Sessao(
        accessToken = "access-$conta",
        refreshToken = "refresh-$conta",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = null,
    )

    private fun cliente(armazenamento: ArmazenamentoDeSessaoEmMemoria, engine: MockEngine) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-anonima-de-teste",
        armazenamentoDeSessao = armazenamento,
        engine = engine,
    )

    @Test
    fun `depois de limpar a sessao a conta seguinte manda so o proprio token`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val autorizacoes = mutableListOf<String?>()
        val cliente = cliente(
            armazenamento,
            MockEngine { pedido ->
                autorizacoes += pedido.headers[HttpHeaders.Authorization]
                respond("{}", HttpStatusCode.OK)
            },
        )

        armazenamento.salvarSessao(sessao("A"))
        cliente.http.get(cliente.urlRpc("minha_conta"))
        armazenamento.limparSessao()
        armazenamento.salvarSessao(sessao("B"))
        cliente.http.get(cliente.urlRpc("minha_conta"))
        cliente.http.get(cliente.urlRpc("minhas_candidaturas"))

        assertEquals(listOf("Bearer access-A", "Bearer access-B", "Bearer access-B"), autorizacoes)
    }

    @Test
    fun `sem sessao depois de sair nenhum pedido leva o token da conta anterior`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val autorizacoes = mutableListOf<String?>()
        val cliente = cliente(
            armazenamento,
            MockEngine { pedido ->
                autorizacoes += pedido.headers[HttpHeaders.Authorization]
                respond("{}", HttpStatusCode.OK)
            },
        )

        armazenamento.salvarSessao(sessao("A"))
        cliente.http.get(cliente.urlRpc("minha_conta"))
        armazenamento.limparSessao()
        cliente.http.get(cliente.urlRpc("configuracao_do_app"))

        assertEquals(listOf("Bearer access-A", null), autorizacoes)
    }

    @Test
    fun `token renovado da conta anterior nao passa para a conta seguinte`() = runTest {
        // Caso raro do parecer do #785: a renovação funciona, o token renovado de A fica em memória
        // e a sessão é limpa depois (ex.: o servidor ainda devolve 401 e o app sai da conta).
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val autorizacoes = mutableListOf<String?>()
        val cliente = cliente(
            armazenamento,
            MockEngine { pedido ->
                if (pedido.url.encodedPath == "/auth/v1/token") {
                    respond(
                        content = """{"access_token":"access-A-renovado","refresh_token":"refresh-A2","token_type":"bearer","expires_in":3600}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                } else {
                    autorizacoes += pedido.headers[HttpHeaders.Authorization]
                    if (autorizacoes.size == 1) {
                        respond(
                            content = """{"code":"PGRST301","message":"JWT expired"}""",
                            status = HttpStatusCode.Unauthorized,
                            headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                        )
                    } else {
                        respond("{}", HttpStatusCode.OK)
                    }
                }
            },
        )

        armazenamento.salvarSessao(sessao("A"))
        cliente.http.get(cliente.urlRpc("minha_conta"))
        armazenamento.limparSessao()
        armazenamento.salvarSessao(sessao("B"))
        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals(listOf("Bearer access-A", "Bearer access-A-renovado", "Bearer access-B"), autorizacoes)
    }
}
