package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
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
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** #793: o cliente avisa a recusa do refresh só quando ela apagou a sessão de quem pediu a renovação. */
class ClienteSupabaseAvisoDeRecusaTest {

    private val sessao = Sessao("access-antigo", "refresh-antigo", "bearer", 3_600L)

    private fun cliente(armazenamento: ArmazenamentoDeSessao, statusDaRenovacao: HttpStatusCode, avisos: MutableList<Unit>) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        armazenamentoDeSessao = armazenamento,
        aoRecusarSessao = { avisos += Unit },
        engine = MockEngine { requisicao ->
            if (requisicao.url.encodedPath == "/auth/v1/token") {
                respond("""{"error":"invalid_grant"}""", statusDaRenovacao)
            } else {
                respond("""{"code":"PGRST301","message":"JWT expired"}""", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.WWWAuthenticate, "Bearer"))
            }
        },
    )

    @Test
    fun `refresh recusado pelo Auth apaga a sessao e avisa uma vez`() = runTest {
        for (status in listOf(HttpStatusCode.BadRequest, HttpStatusCode.Unauthorized, HttpStatusCode.Forbidden)) {
            val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
            val avisos = mutableListOf<Unit>()
            val cliente = cliente(armazenamento, status, avisos)

            val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))

            assertEquals(HttpStatusCode.Unauthorized, resposta.status, "$status")
            assertNull(armazenamento.obterSessao(), "$status")
            assertEquals(1, avisos.size, "$status")
        }
    }

    @Test
    fun `falha passageira na renovacao mantem a sessao e nao avisa`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
        val avisos = mutableListOf<Unit>()
        val cliente = cliente(armazenamento, HttpStatusCode.ServiceUnavailable, avisos)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertNotNull(armazenamento.obterSessao())
        assertEquals(0, avisos.size)
    }

    @Test
    fun `recusa que chega depois de outra conta entrar nao apaga a nova nem avisa`() = runTest {
        // A conta trocou entre a leitura da sessão e a resposta da renovação: o apagar condicional não encontra o refresh esperado.
        val armazenamento = object : ArmazenamentoDeSessao by ArmazenamentoDeSessaoEmMemoria().apply({ salvarSessao(sessao) }) {
            override fun limparSeRefreshTokenIgual(esperado: String): Boolean = false
            override fun obterSessao(): Sessao? = sessao
        }
        val avisos = mutableListOf<Unit>()
        val cliente = cliente(armazenamento, HttpStatusCode.BadRequest, avisos)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals(0, avisos.size)
    }
}
