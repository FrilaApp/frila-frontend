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
    private fun viewModelComEngine(engine: MockEngine, permitirDominioDeTeste: Boolean = false): EntradaViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return EntradaViewModel(ServicoAutenticacao(cliente), escopo = CoroutineScope(Dispatchers.Default), permitirDominioDeTeste = permitirDominioDeTeste)
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

    @Test
    fun `429 do Auth sem message nao derruba o app e mostra a mensagem de limite`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":429,"error_code":"over_email_send_rate_limit"}""",
                    status = HttpStatusCode.TooManyRequests,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()

        assertEquals(MENSAGEM_LIMITE_DE_CODIGOS, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.carregando)
        assertFalse(viewModel.estado.value.otpSolicitado)
    }

    @Test
    fun `429 sem corpo nenhum tambem mostra a mensagem de limite`() = runBlocking {
        val viewModel = viewModelComEngine(MockEngine { respond("", HttpStatusCode.TooManyRequests) })

        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()

        assertEquals(MENSAGEM_LIMITE_DE_CODIGOS, viewModel.estado.value.erro)
    }

    @Test
    fun `corpo de erro que nao e json nao derruba o app`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "<html>Bad Gateway</html>",
                    status = HttpStatusCode.InternalServerError,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
            },
        )

        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()

        assertEquals("Não foi possível enviar o código. Tente de novo em instantes.", viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.carregando)
    }

    @Test
    fun `solicitarCodigo manda o e-mail em minusculas e sem espacos, como o iOS`() = runBlocking {
        var corpo: String? = null
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                corpo = (request.body as io.ktor.http.content.TextContent).text
                respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.aoMudarEmail("  Profissional@Exemplo.COM ")
        viewModel.solicitarCodigo()?.join()

        assertTrue(corpo!!.contains("\"profissional@exemplo.com\""))
        assertEquals("profissional@exemplo.com", viewModel.estado.value.email)
    }

    /** Sem consumir o sinal, voltar da tela do código recompunha a entrada e reabria o código (preso na tela). */
    @Test
    fun `depois de navegar para o codigo o sinal e consumido`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        viewModel.aoMudarEmail("profissional@exemplo.com")
        viewModel.solicitarCodigo()?.join()
        assertTrue(viewModel.estado.value.otpSolicitado)

        viewModel.aoNavegarParaCodigo()

        assertFalse(viewModel.estado.value.otpSolicitado)
        assertEquals("profissional@exemplo.com", viewModel.estado.value.email)
    }

    @Test
    fun `segundo toque com o pedido em voo nao envia de novo`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger(0)
        val viewModel = viewModelComEngine(
            MockEngine {
                chamadas.incrementAndGet()
                kotlinx.coroutines.delay(200)
                respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.aoMudarEmail("profissional@exemplo.com")

        val primeiro = viewModel.solicitarCodigo()
        val segundo = viewModel.solicitarCodigo()
        primeiro?.join()
        segundo?.join()

        assertEquals(1, chamadas.get())
    }

    @ParameterizedTest
    @ValueSource(booleans = [true, false])
    fun `dominio de teste so pula OTP com a permissao de debug`(permitirDominioDeTeste: Boolean) = runBlocking {
        val caminhos = mutableListOf<String>()
        val vm = viewModelComEngine(MockEngine { request ->
            caminhos += request.url.encodedPath
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }, permitirDominioDeTeste)
        vm.aoMudarEmail("  Qualquer@FRILA.TEST  ")
        assertEquals(permitirDominioDeTeste, vm.estado.value.ehContaDeDemonstracao)
        vm.solicitarCodigo()?.join()
        assertTrue(vm.estado.value.otpSolicitado)
        assertEquals(if (permitirDominioDeTeste) emptyList<String>() else listOf("/auth/v1/otp"), caminhos)
    }

}
