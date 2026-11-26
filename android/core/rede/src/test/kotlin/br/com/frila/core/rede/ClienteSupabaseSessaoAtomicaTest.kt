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
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Follow-up do #794/#1067 (cartão 7567rGRH). Comparar a sessão e gravar em dois passos deixa uma brecha: a troca de conta
 * A para B pode cair entre a leitura e a gravação, e a renovação de A sobrescreve a sessão de B. Aqui a troca é forçada
 * exatamente nesse instante, em todas as iterações; o armazenamento precisa terminar sempre com a sessão de B.
 */
class ClienteSupabaseSessaoAtomicaTest {

    private fun sessao(conta: String) = Sessao(
        accessToken = "access-$conta",
        refreshToken = "refresh-$conta",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = null,
    )

    /** Antes de cada escrita (condicional ou não) feita pelo cliente, a conta B entra no lugar de A, uma vez por iteração. */
    private class ComTrocaNoInstanteDaEscrita(val interno: ArmazenamentoDeSessaoEmMemoria) : ArmazenamentoDeSessao by interno {
        var trocaArmada = false

        private fun trocarParaB() {
            if (!trocaArmada) return
            trocaArmada = false
            interno.limparSessao()
            interno.salvarSessao(Sessao("access-B", "refresh-B", "bearer", 3_600L, null))
        }

        override fun salvarSessao(sessao: Sessao) {
            trocarParaB()
            interno.salvarSessao(sessao)
        }

        override fun limparSessao() {
            trocarParaB()
            interno.limparSessao()
        }

        override fun salvarSeRefreshTokenIgual(esperado: String, nova: Sessao): Boolean {
            trocarParaB()
            return interno.salvarSeRefreshTokenIgual(esperado, nova)
        }

        override fun limparSeRefreshTokenIgual(esperado: String): Boolean {
            trocarParaB()
            return interno.limparSeRefreshTokenIgual(esperado)
        }
    }

    private fun refreshQueTrocaDeContaNaEscrita(statusDoAuth: HttpStatusCode, corpoDoAuth: String): Int = runBlocking {
        var sessoesDeBPerdidas = 0
        repeat(ITERACOES) {
            val armazenamento = ComTrocaNoInstanteDaEscrita(ArmazenamentoDeSessaoEmMemoria())
            val engine = MockEngine { pedido ->
                when {
                    pedido.url.encodedPath == "/auth/v1/token" -> {
                        armazenamento.trocaArmada = true
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
            armazenamento.interno.salvarSessao(sessao("A"))

            runCatching { cliente.http.get(cliente.urlRpc("minha_conta")) }

            if (armazenamento.interno.obterSessao() != sessao("B")) sessoesDeBPerdidas++
        }
        sessoesDeBPerdidas
    }

    @Test
    fun `troca de conta no instante de gravar a renovacao nunca deixa a sessao de A sobre a de B`() {
        val perdidas = refreshQueTrocaDeContaNaEscrita(
            HttpStatusCode.OK,
            """{"access_token":"access-A-2","refresh_token":"refresh-A-2","token_type":"bearer","expires_in":3600}""",
        )

        assertEquals(0, perdidas, "sessões de B sobrescritas em $ITERACOES iterações")
    }

    @Test
    fun `troca de conta no instante de encerrar por refresh recusado nunca apaga a sessao de B`() {
        val perdidas = refreshQueTrocaDeContaNaEscrita(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")

        assertEquals(0, perdidas, "sessões de B apagadas em $ITERACOES iterações")
    }

    private companion object {
        const val ITERACOES = 6_000
    }
}
