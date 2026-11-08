package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class SincronizadorDeTokenTest {

    private val sessaoDeTeste = Sessao(
        accessToken = "access",
        refreshToken = "refresh",
        tokenType = "bearer",
        expiresIn = 3600,
        vinculoId = "vinculo-antigo",
    )

    private fun servicoComEngine(engine: MockEngine): ServicoDispositivo {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return ServicoDispositivo(cliente)
    }

    @Test
    fun `com sessao ativa e vinculo_id novo, atualiza a sessao guardada`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-novo"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDeTeste) }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals("vinculo-novo", armazenamento.obterSessao()?.vinculoId)
        // Resto da sessão (tokens) não é tocado pela sincronização de vínculo.
        assertEquals(sessaoDeTeste.accessToken, armazenamento.obterSessao()?.accessToken)
    }

    @Test
    fun `sem sessao ativa, nao tenta salvar nada (nao ha a quem vincular)`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-novo"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertFalse(armazenamento.estaAutenticado())
        assertNull(armazenamento.obterSessao())
    }

    @Test
    fun `backend anterior a 0_2_30 sem vinculo_id nao sobrescreve o vinculo guardado`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDeTeste) }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals("vinculo-antigo", armazenamento.obterSessao()?.vinculoId)
    }
}
