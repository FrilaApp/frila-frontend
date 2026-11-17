package br.com.frila.feature.entrada.codigo

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.entrada.MENSAGEM_LIMITE_DE_CODIGOS
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger
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
        agora: () -> Instant = Instant::now,
    ): Pair<CodigoViewModel, ArmazenamentoDeSessaoEmMemoria> {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val viewModel = CodigoViewModel(
            email,
            ServicoAutenticacao(cliente),
            armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
            agora = agora,
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
        assertEquals("Código incorreto. Confira os números e tente novamente.", viewModel.estado.value.erro)
    }

    @Test
    fun `reenviarCodigo chama solicitarOtp de novo e limpa o campo`() = runBlocking {
        var chamadas = 0
        val (viewModel, _) = viewModelComEngine(
            MockEngine { chamadas++; respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        // 5 dígitos: completar os 6 agora confirma sozinho (como o iOS) e contaria uma chamada a mais.
        viewModel.aoMudarCodigo("12345")

        viewModel.reenviarCodigo()?.join()

        assertEquals(1, chamadas)
        assertTrue(viewModel.estado.value.reenviado)
        assertEquals("", viewModel.estado.value.codigo)
    }

    @Test
    fun `reenviarCodigo com 429 do Auth sem message mostra a mensagem de limite`() = runBlocking {
        val (viewModel, _) = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":429,"error_code":"over_email_send_rate_limit"}""",
                    status = HttpStatusCode.TooManyRequests,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.reenviarCodigo()?.join()

        assertEquals(MENSAGEM_LIMITE_DE_CODIGOS, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.reenviado)
        assertFalse(viewModel.estado.value.carregando)
    }

    /** Corpo REAL do Auth para código errado ou vencido: 403 `otp_expired`, sem o envelope `{code,message}` do PostgREST. */
    private fun motorComCodigoRecusadoPeloAuth(chamadas: AtomicInteger = AtomicInteger(0)) = MockEngine {
        chamadas.incrementAndGet()
        respond(
            content = """{"code":403,"error_code":"otp_expired","msg":"Token has expired or is invalid"}""",
            status = HttpStatusCode.Forbidden,
            headers = headersOf(HttpHeaders.ContentType, "application/json"),
        )
    }

    @Test
    fun `codigo errado dentro da validade mostra Codigo incorreto, como no iOS`() = runBlocking {
        val (viewModel, armazenamento) = viewModelComEngine(motorComCodigoRecusadoPeloAuth())

        viewModel.aoMudarCodigo("000000")?.join()

        assertEquals("Código incorreto. Confira os números e tente novamente.", viewModel.estado.value.erro)
        assertFalse(armazenamento.estaAutenticado())
    }

    @Test
    fun `codigo recusado depois de 10 minutos mostra Codigo expirado`() = runBlocking {
        var agora = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(motorComCodigoRecusadoPeloAuth(), agora = { agora })
        agora = agora.plusSeconds(600)

        viewModel.aoMudarCodigo("000000")?.join()

        assertEquals("Código expirado. Peça um novo código para continuar.", viewModel.estado.value.erro)
    }

    @Test
    fun `completar os 6 digitos confirma sozinho`() = runBlocking {
        val chamadas = AtomicInteger(0)
        val (viewModel, _) = viewModelComEngine(motorComCodigoRecusadoPeloAuth(chamadas))

        viewModel.aoMudarCodigo("12345")
        assertEquals(0, chamadas.get())
        viewModel.aoMudarCodigo("123456")?.join()

        assertEquals(1, chamadas.get())
    }

    @Test
    fun `segundo toque em confirmar com a chamada em voo nao envia de novo`() = runBlocking {
        val chamadas = AtomicInteger(0)
        val (viewModel, _) = viewModelComEngine(
            MockEngine {
                chamadas.incrementAndGet()
                kotlinx.coroutines.delay(200)
                respond(
                    content = """{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        val primeiro = viewModel.aoMudarCodigo("123456")
        val segundo = viewModel.confirmarCodigo()
        val terceiro = viewModel.confirmarCodigo()
        primeiro?.join()
        segundo?.join()
        terceiro?.join()

        assertEquals(1, chamadas.get())
        assertTrue(viewModel.estado.value.autenticado)
    }

    @Test
    fun `o e-mail vai em minusculas e sem espacos na verificacao`() = runBlocking {
        var corpo: String? = null
        val (viewModel, _) = viewModelComEngine(
            MockEngine { request ->
                corpo = (request.body as io.ktor.http.content.TextContent).text
                respond(
                    content = """{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
            email = "  Profissional@Exemplo.COM ",
        )

        viewModel.aoMudarCodigo("123456")?.join()

        assertEquals("profissional@exemplo.com", viewModel.estado.value.email)
        assertTrue(corpo!!.contains("\"profissional@exemplo.com\""))
    }

    @Test
    fun `resposta 200 ilegivel na verificacao sai de carregando com erro`() = runBlocking {
        val (viewModel, armazenamento) = viewModelComEngine(
            MockEngine {
                respond(
                    content = "<html>portal</html>",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
            },
        )

        viewModel.aoMudarCodigo("123456")?.join()

        assertFalse(viewModel.estado.value.carregando)
        assertEquals("Não foi possível confirmar o código. Tente de novo em instantes.", viewModel.estado.value.erro)
        assertFalse(armazenamento.estaAutenticado())
    }
}
