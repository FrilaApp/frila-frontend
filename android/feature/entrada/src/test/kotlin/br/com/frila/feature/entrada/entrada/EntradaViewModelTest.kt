package br.com.frila.feature.entrada.entrada

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
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
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class EntradaViewModelTest {

    /**
     * [EntradaViewModel.solicitarCodigo] devolve o `Job` lançado para que o teste possa
     * `job.join()` e esperar de verdade — o cliente Ktor de `:core:rede` processa a resposta
     * do `MockEngine` num dispatcher real por baixo dos panos, então nem um `TestScope`
     * compartilhado com `advanceUntilIdle()` nem um `UnconfinedTestDispatcher` isolado bastam
     * para garantir, de forma determinística, que a corrotina terminou antes da asserção.
     */
    private fun viewModelComEngine(engine: MockEngine): EntradaViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return EntradaViewModel(ServicoAutenticacao(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @ParameterizedTest
    @ValueSource(strings = ["profissional@exemplo.com", "a@b.co", "nome.sobrenome@frila.app"])
    fun `ehEmailValido aceita formatos validos`(email: String) {
        val viewModel = viewModelComEngine(MockEngine { respond("{}", HttpStatusCode.OK) })

        assertTrue(viewModel.ehEmailValido(email))
    }

    @ParameterizedTest
    @ValueSource(strings = ["", "sem-arroba.com", "sem-dominio@", "@sem-usuario.com", "com espaco@exemplo.com"])
    fun `ehEmailValido recusa formatos invalidos`(email: String) {
        val viewModel = viewModelComEngine(MockEngine { respond("{}", HttpStatusCode.OK) })

        assertFalse(viewModel.ehEmailValido(email))
    }

    @Test
    fun `solicitarCodigo com email invalido nao chama a API e mostra erro`() {
        var chamadas = 0
        val viewModel = viewModelComEngine(MockEngine { chamadas++; respond("{}", HttpStatusCode.OK) })

        viewModel.aoMudarEmail("email-invalido")
        viewModel.solicitarCodigo()

        assertEquals(0, chamadas)
        assertEquals("Informe um e-mail válido.", viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.otpSolicitado)
    }

    @Test
    fun `solicitarCodigo com email valido chama auth v1 otp e avanca para codigo`() = runBlocking {
        var caminhoChamado: String? = null
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                caminhoChamado = request.url.encodedPath
                respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()

        assertEquals("/auth/v1/otp", caminhoChamado)
        assertTrue(viewModel.estado.value.otpSolicitado)
        assertEquals(null, viewModel.estado.value.erro)
    }

    @Test
    fun `solicitarCodigo com conta de demonstracao pula a chamada de OTP`() {
        var chamadas = 0
        val viewModel = viewModelComEngine(MockEngine { chamadas++; respond("{}", HttpStatusCode.OK) })

        viewModel.aoMudarEmail("revisao-profissional@frila.app")
        viewModel.solicitarCodigo()

        assertEquals(0, chamadas, "conta de demonstração não deve chamar /auth/v1/otp")
        assertTrue(viewModel.estado.value.otpSolicitado)
    }

    @Test
    fun `aoMudarEmail marca ehContaDeDemonstracao para as contas de revisao`() {
        val viewModel = viewModelComEngine(MockEngine { respond("{}", HttpStatusCode.OK) })

        viewModel.aoMudarEmail("revisao-contratante@frila.app")

        assertTrue(viewModel.estado.value.ehContaDeDemonstracao)
    }

    @Test
    fun `erro 4xx da API vira mensagem amigavel, nunca o texto cru do backend`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"campo_invalido","message":"detalhe tecnico interno do postgres"}""",
                    status = HttpStatusCode.BadRequest,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()

        val erro = viewModel.estado.value.erro
        assertTrue(erro != null && !erro.contains("postgres"))
        assertFalse(viewModel.estado.value.otpSolicitado)
    }
}
