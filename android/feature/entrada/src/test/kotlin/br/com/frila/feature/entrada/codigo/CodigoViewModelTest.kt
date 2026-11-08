package br.com.frila.feature.entrada.codigo

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Ver nota em `EntradaViewModelTest.viewModelComEngine` sobre por que o teste faz `job.join()`. */
class CodigoViewModelTest {

    private fun viewModelComEngine(
        engine: MockEngine,
        email: String = "profissional@exemplo.com",
        armazenamento: ArmazenamentoDeSessaoEmMemoria = ArmazenamentoDeSessaoEmMemoria(),
    ): Pair<CodigoViewModel, ArmazenamentoDeSessaoEmMemoria> {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val viewModel = CodigoViewModel(
            email,
            ServicoAutenticacao(cliente),
            armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
        return viewModel to armazenamento
    }

    @Test
    fun `aoMudarCodigo so aceita digitos e limita a 6 caracteres`() {
        val (viewModel, _) = viewModelComEngine(MockEngine { respond("{}", HttpStatusCode.OK) })

        viewModel.aoMudarCodigo("1a2b3c4d5e6f7g")

        assertEquals("123456", viewModel.estado.value.codigo)
    }

    @Test
    fun `confirmarCodigo com menos de 6 digitos nao chama a API`() {
        var chamadas = 0
        val (viewModel, _) = viewModelComEngine(MockEngine { chamadas++; respond("{}", HttpStatusCode.OK) })

        viewModel.aoMudarCodigo("123")
        viewModel.confirmarCodigo()

        assertEquals(0, chamadas)
        assertEquals("Informe os 6 dígitos do código.", viewModel.estado.value.erro)
    }

    @Test
    fun `confirmarCodigo com sucesso chama auth v1 verify e salva a sessao`() = runBlocking {
        var caminhoChamado: String? = null
        val (viewModel, armazenamento) = viewModelComEngine(
            MockEngine { request ->
                caminhoChamado = request.url.encodedPath
                respond(
                    content = """{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarCodigo("123456")
        viewModel.confirmarCodigo()?.join()

        assertEquals("/auth/v1/verify", caminhoChamado)
        assertTrue(viewModel.estado.value.autenticado)
        assertTrue(armazenamento.estaAutenticado())
        assertEquals("tok123", armazenamento.obterSessao()?.accessToken)
    }

    @Test
    fun `confirmarCodigo para conta de demonstracao chama entrar-demonstracao, nao auth v1 verify`() = runBlocking {
        var caminhoChamado: String? = null
        val (viewModel, armazenamento) = viewModelComEngine(
            email = "revisao-profissional@frila.app",
            engine = MockEngine { request ->
                caminhoChamado = request.url.encodedPath
                respond(
                    content = """{"access_token":"tok-demo","refresh_token":"ref-demo","token_type":"bearer","expires_in":3600}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarCodigo("000000")
        viewModel.confirmarCodigo()?.join()

        assertEquals("/functions/v1/entrar-demonstracao", caminhoChamado)
        assertTrue(viewModel.estado.value.autenticado)
        assertTrue(armazenamento.estaAutenticado())
    }

    @Test
    fun `confirmarCodigo com codigo errado nao salva sessao e mostra erro`() = runBlocking {
        val (viewModel, armazenamento) = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"campo_invalido","message":"codigo invalido"}""",
                    status = HttpStatusCode.BadRequest,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarCodigo("000000")
        viewModel.confirmarCodigo()?.join()

        assertFalse(viewModel.estado.value.autenticado)
        assertFalse(armazenamento.estaAutenticado())
        assertNull(armazenamento.obterSessao())
        assertEquals("Código incorreto. Confira os 6 dígitos e tente de novo.", viewModel.estado.value.erro)
    }

    @Test
    fun `reenviarCodigo chama solicitarOtp de novo e limpa o campo`() = runBlocking {
        var chamadas = 0
        val (viewModel, _) = viewModelComEngine(
            MockEngine { chamadas++; respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        viewModel.aoMudarCodigo("123456")

        viewModel.reenviarCodigo()?.join()

        assertEquals(1, chamadas)
        assertTrue(viewModel.estado.value.reenviado)
        assertEquals("", viewModel.estado.value.codigo)
    }
}
