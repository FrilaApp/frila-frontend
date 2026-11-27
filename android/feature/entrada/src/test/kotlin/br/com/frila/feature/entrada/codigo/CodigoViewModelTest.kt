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
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

/** Ver nota em `EntradaViewModelTest.viewModelComEngine` sobre por que o teste faz `job.join()`. */
class CodigoViewModelTest {

    private fun viewModelComEngine(
        engine: MockEngine,
        email: String = "profissional@exemplo.com",
        armazenamento: ArmazenamentoDeSessaoEmMemoria = ArmazenamentoDeSessaoEmMemoria(),
        agora: () -> Instant = Instant::now,
        aoEntrar: suspend () -> Unit = {},
        permitirDominioDeTeste: Boolean = false,
        modo: ModoCodigo = ModoCodigo.ENTRADA,
    ): Pair<CodigoViewModel, ArmazenamentoDeSessaoEmMemoria> {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val viewModel = CodigoViewModel(
            email,
            ServicoAutenticacao(cliente),
            armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
            agora = agora,
            aoEntrar = aoEntrar,
            permitirDominioDeTeste = permitirDominioDeTeste,
            modo = modo,
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
    fun `confirmarCodigo com sucesso chama confirmar-dispositivo-otp e salva a sessao`() = runBlocking {
        var caminhoChamado: String? = null
        val (viewModel, armazenamento) = viewModelComEngine(
            MockEngine { request ->
                caminhoChamado = request.url.encodedPath
                respond(
                    content = """{"sessao":{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.aoMudarCodigo("123456")
        viewModel.confirmarCodigo()?.join()

        assertEquals("/functions/v1/confirmar-dispositivo-otp", caminhoChamado)
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

    private fun motorQueEntra() = MockEngine {
        respond(
            content = """{"sessao":{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
            status = HttpStatusCode.OK,
            headers = headersOf(HttpHeaders.ContentType, "application/json"),
        )
    }

    @Test
    fun `depois de entrar com o codigo certo, chama aoEntrar uma vez, ja com a sessao salva (C0-10)`() = runBlocking {
        val chamadas = AtomicInteger(0)
        var sessaoNaHora: String? = null
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val (viewModel, _) = viewModelComEngine(motorQueEntra(), armazenamento = armazenamento, aoEntrar = {
            chamadas.incrementAndGet()
            sessaoNaHora = armazenamento.obterSessao()?.accessToken
        })

        viewModel.aoMudarCodigo("123456")
        viewModel.confirmarCodigo()?.join()

        assertEquals(1, chamadas.get())
        assertEquals("tok123", sessaoNaHora, "o registro do aparelho precisa da sessão")
    }

    @Test
    fun `com o codigo errado, aoEntrar nao e chamado`() = runBlocking {
        val chamadas = AtomicInteger(0)
        val (viewModel, _) = viewModelComEngine(motorComCodigoRecusadoPeloAuth(), aoEntrar = { chamadas.incrementAndGet() })

        viewModel.aoMudarCodigo("000000")
        viewModel.confirmarCodigo()?.join()

        assertEquals(0, chamadas.get())
    }

    @Test
    fun `aoEntrar que falha nao desfaz a entrada`() = runBlocking {
        val (viewModel, armazenamento) = viewModelComEngine(motorQueEntra(), aoEntrar = { error("sem rede para registrar") })

        viewModel.aoMudarCodigo("123456")
        viewModel.confirmarCodigo()?.join()

        assertTrue(viewModel.estado.value.autenticado)
        assertTrue(armazenamento.estaAutenticado())
        assertNull(viewModel.estado.value.erro)
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
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            MockEngine { chamadas++; respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            agora = { relogio },
        )
        relogio = relogio.plusSeconds(60) // a espera para reenviar já passou
        // 5 dígitos: completar os 6 agora confirma sozinho (como o iOS) e contaria uma chamada a mais.
        viewModel.aoMudarCodigo("12345")

        viewModel.reenviarCodigo()?.join()

        assertEquals(1, chamadas)
        assertTrue(viewModel.estado.value.reenviado)
        assertEquals("", viewModel.estado.value.codigo)
    }

    /** O que a tela mostra depois do reenvio: tudo o que um olho (ou o leitor de tela) consegue comparar. */
    private data class VisivelAposReenvio(val estado: EstadoCodigo, val segundosParaReenviar: Long)

    private fun reenviarNaRecuperacao(status: HttpStatusCode, corpo: String): VisivelAposReenvio =
        reenviarNaRecuperacao(MockEngine { respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json")) })

    private fun reenviarNaRecuperacao(engine: MockEngine): VisivelAposReenvio = runBlocking {
        var relogio = Instant.parse("2026-11-24T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            engine,
            email = "legado@exemplo.test",
            agora = { relogio },
            modo = ModoCodigo.RECUPERACAO,
        )
        relogio = relogio.plusSeconds(61) // a espera para reenviar já passou
        viewModel.aoMudarCodigo("123") // código parcial digitado antes do reenvio
        viewModel.reenviarCodigo()?.join()
        VisivelAposReenvio(viewModel.estado.value, viewModel.segundosParaReenviar())
    }

    @Test
    fun `na recuperacao o reenvio com conta, sem conta e sem OTP mostra exatamente o mesmo estado`() {
        val comConta = reenviarNaRecuperacao(HttpStatusCode.OK, "{}")
        val otpDesligado = reenviarNaRecuperacao(
            HttpStatusCode.UnprocessableEntity,
            """{"code":422,"error_code":"otp_disabled","msg":"Signups not allowed for otp"}""",
        )
        val semConta = reenviarNaRecuperacao(
            HttpStatusCode.NotFound,
            """{"code":404,"error_code":"user_not_found","msg":"User not found"}""",
        )

        assertEquals("Se houver uma conta com este e-mail, enviamos um novo código.", comConta.estado.mensagemReenvio)
        assertTrue(comConta.estado.reenviado)
        assertNull(comConta.estado.erro)
        assertEquals("", comConta.estado.codigo)
        assertEquals(1, comConta.estado.reenviosFeitos)
        assertEquals(60L, comConta.segundosParaReenviar)
        assertEquals(comConta, otpDesligado)
        assertEquals(comConta, semConta)
    }

    @Test
    fun `na recuperacao 429, 5xx e sem rede continuam como erro e nao viram o aviso neutro`() {
        listOf(
            HttpStatusCode.TooManyRequests to """{"code":429,"error_code":"over_email_send_rate_limit"}""",
            HttpStatusCode.InternalServerError to """{"code":500,"error_code":"unexpected_failure"}""",
        ).map { (status, corpo) -> status.toString() to reenviarNaRecuperacao(status, corpo) }
            .plus("sem rede" to reenviarNaRecuperacao(MockEngine { throw java.io.IOException("sem rede") }))
            .forEach { (cenario, visivel) ->
            assertNotNull(visivel.estado.erro, "$cenario deve ser erro")
            assertFalse(visivel.estado.reenviado)
            assertNull(visivel.estado.mensagemReenvio)
            assertEquals("123", visivel.estado.codigo)
            assertEquals(0L, visivel.segundosParaReenviar)
        }
    }

    @Test
    fun `no modo de criacao o reenvio com 200 continua dizendo Novo codigo enviado`() {
        val (viewModel, _) = run {
            var relogio = Instant.parse("2026-11-24T12:00:00Z")
            val par = viewModelComEngine(
                MockEngine { respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
                agora = { relogio },
                modo = ModoCodigo.ENTRADA,
            )
            relogio = relogio.plusSeconds(61)
            par
        }
        runBlocking { viewModel.reenviarCodigo()?.join() }

        assertTrue(viewModel.estado.value.reenviado)
        assertEquals("Novo código enviado para seu e-mail.", viewModel.estado.value.mensagemReenvio)
    }

    @Test
    fun `reenviarCodigo com 429 do Auth sem message mostra a mensagem de limite`() = runBlocking {
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":429,"error_code":"over_email_send_rate_limit"}""",
                    status = HttpStatusCode.TooManyRequests,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
            agora = { relogio },
        )
        relogio = relogio.plusSeconds(60) // a espera para reenviar já passou

        viewModel.reenviarCodigo()?.join()

        assertEquals(MENSAGEM_LIMITE_DE_CODIGOS, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.reenviado)
        assertFalse(viewModel.estado.value.carregando)
        // Reenvio que falhou não recomeça a contagem (no iOS o temporizador só reinicia no sucesso).
        assertEquals(0L, viewModel.segundosParaReenviar())
    }

    /** Outro código só pode ser pedido após a espera conservadora padrão de 60 s (sem `reenviarEmSegundos` do servidor). */
    @Test
    fun `reenviar antes de 60 segundos nao chama a API`() = runBlocking {
        val chamadas = AtomicInteger(0)
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            MockEngine { chamadas.incrementAndGet(); respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            agora = { relogio },
        )
        assertEquals(60L, viewModel.segundosParaReenviar())
        relogio = relogio.plusSeconds(59)

        viewModel.reenviarCodigo()?.join()

        assertEquals(0, chamadas.get())
        assertEquals(1L, viewModel.segundosParaReenviar())
        assertFalse(viewModel.estado.value.reenviado)
    }

    @Test
    fun `reenviar depois de 60 segundos chama a API e recomeca a contagem`() = runBlocking {
        val chamadas = AtomicInteger(0)
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            MockEngine { chamadas.incrementAndGet(); respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            agora = { relogio },
        )
        relogio = relogio.plusSeconds(60)
        assertEquals(0L, viewModel.segundosParaReenviar())

        viewModel.reenviarCodigo()?.join()
        assertEquals(1, chamadas.get())
        assertTrue(viewModel.estado.value.reenviado)
        assertEquals(60L, viewModel.segundosParaReenviar())

        // Logo em seguida, um segundo reenvio fica barrado.
        viewModel.reenviarCodigo()?.join()
        assertEquals(1, chamadas.get())
    }

    @Test
    fun `teto de 3 reenvios bloqueia o quarto pedido e erro de codigo aguarda nova digitacao`() = runBlocking {
        val chamadas = AtomicInteger(0)
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val (viewModel, _) = viewModelComEngine(
            MockEngine {
                chamadas.incrementAndGet()
                val url = it.url.encodedPath
                if (url.contains("verify")) {
                    respond("""{"code":403,"error_code":"otp_expired"}""", HttpStatusCode.Forbidden, headersOf(HttpHeaders.ContentType, "application/json"))
                } else {
                    respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                }
            },
            agora = { relogio },
        )

        // Erro ao completar 6 digitos -> repetir a mesma string nao dispara nova chamada
        viewModel.aoMudarCodigo("123456")?.join()
        assertEquals(1, chamadas.get())
        assertNotNull(viewModel.estado.value.erro)
        assertNull(viewModel.aoMudarCodigo("123456"))
        assertEquals(1, chamadas.get())

        // Teto de 3 reenvios
        repeat(3) {
            relogio = relogio.plusSeconds(60)
            viewModel.reenviarCodigo()?.join()
        }
        assertEquals(3, viewModel.estado.value.reenviosFeitos)
        relogio = relogio.plusSeconds(60)
        assertNull(viewModel.reenviarCodigo())
        assertNotNull(viewModel.estado.value.erro)
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
                    content = """{"sessao":{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
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
                    content = """{"sessao":{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
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

    @ParameterizedTest
    @ValueSource(booleans = [true, false])
    fun `dominio de teste so confirma e reenvia como demonstracao em debug`(permitirDominioDeTeste: Boolean) = runBlocking {
        val caminhos = mutableListOf<String>()
        var relogio = Instant.parse("2026-11-17T12:00:00Z")
        val (vm, armazenamento) = viewModelComEngine(
            engine = MockEngine { request ->
                caminhos += request.url.encodedPath
                val corpo = if (request.url.encodedPath == "/functions/v1/confirmar-dispositivo-otp") {
                    """{"sessao":{"access_token":"token-teste","refresh_token":"refresh-teste","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}"""
                } else {
                    """{"access_token":"token-teste","refresh_token":"refresh-teste","token_type":"bearer","expires_in":3600}"""
                }
                respond(
                    corpo,
                    HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
            email = "  Qualquer@FRILA.TEST  ",
            agora = { relogio },
            permitirDominioDeTeste = permitirDominioDeTeste,
        )
        vm.aoMudarCodigo("123456")?.join()
        assertTrue(vm.estado.value.autenticado)
        assertTrue(armazenamento.estaAutenticado())
        relogio = relogio.plusSeconds(60)
        vm.reenviarCodigo()?.join()
        assertTrue(vm.estado.value.reenviado)
        assertEquals(
            if (permitirDominioDeTeste) listOf("/functions/v1/entrar-demonstracao") else listOf("/functions/v1/confirmar-dispositivo-otp", "/auth/v1/otp"),
            caminhos,
        )
    }

}
