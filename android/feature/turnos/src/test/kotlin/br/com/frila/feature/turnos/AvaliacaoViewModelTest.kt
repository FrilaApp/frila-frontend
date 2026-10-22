package br.com.frila.feature.turnos

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class AvaliacaoViewModelTest {

    private val turnoId = "11111111-1111-1111-1111-111111111111"

    private fun avaliacaoJson(resposta: Boolean) = """
        {
          "turno_id": "$turnoId",
          "resposta": $resposta,
          "criada_em": "2026-11-02T04:00:00Z"
        }
    """.trimIndent()

    private fun viewModelComEngine(engine: MockEngine): AvaliacaoViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return AvaliacaoViewModel(ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `avaliar com resposta positiva resulta em SUCESSO com resposta registrada verdadeira`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = avaliacaoJson(true), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(true, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `avaliar com resposta negativa resulta em SUCESSO com resposta registrada falsa`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = avaliacaoJson(false), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.avaliar(turnoId, false).join()

        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(false, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `avaliar recusado com avaliacao_indisponivel resulta em ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"avaliacao_indisponivel","message":"antes_do_fim"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `avaliar recusado com avaliacao_ja_registrada resulta em ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"avaliacao_ja_registrada","message":"resposta diferente da ja gravada"}""",
                    status = HttpStatusCode.Conflict,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.avaliar(turnoId, false).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `status comeca OCIOSO antes do toque`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = avaliacaoJson(true), status = HttpStatusCode.OK) })

        assertEquals(StatusAvaliacao.OCIOSO, viewModel.estado.value.status)
    }
}
