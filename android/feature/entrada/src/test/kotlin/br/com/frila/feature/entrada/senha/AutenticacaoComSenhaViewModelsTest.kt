package br.com.frila.feature.entrada.senha

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.ModoCodigo
import br.com.frila.feature.entrada.criar.CriarContaViewModel
import br.com.frila.feature.entrada.entrada.MENSAGEM_LIMITE_DE_CODIGOS
import br.com.frila.feature.entrada.recuperacao.RecuperacaoSenhaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AutenticacaoComSenhaViewModelsTest {

    private fun escopo() = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @Test
    fun `login por senha valido salva sessao no armazenamento e limpa senha da memoria`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val engine = MockEngine { request ->
            assertEquals("/auth/v1/token", request.url.encodedPath)
            assertEquals("grant_type=password", request.url.encodedQuery)
            respond(
                content = """{"access_token":"tok-1","refresh_token":"ref-1","token_type":"bearer","expires_in":3600}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = EntradaComSenhaViewModel(servico, armazenamento, escopo = escopo())

        vm.aoMudarEmail("  Conta@Exemplo.Test ")
        vm.aoMudarSenha("SenhaSintetica#2026")
        vm.entrar()?.join()

        assertTrue(vm.estado.value.autenticado)
        assertEquals("", vm.estado.value.senha)
        assertNull(vm.estado.value.erro)
        assertEquals("tok-1", armazenamento.obterSessao()?.accessToken)
    }

    @Test
    fun `login por senha com erro devolve mensagem neutra anti-enumeracao sem abrir sessao`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val engine = MockEngine {
            respond(
                content = """{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}""",
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = EntradaComSenhaViewModel(servico, armazenamento, escopo = escopo())

        vm.aoMudarEmail("conta@exemplo.test")
        vm.aoMudarSenha("Errada#123")
        vm.entrar()?.join()

        assertFalse(vm.estado.value.autenticado)
        assertEquals(EntradaComSenhaViewModel.MENSAGEM_CREDENCIAIS_NEUTRA, vm.estado.value.erro)
        assertNull(armazenamento.obterSessao())
    }

    @Test
    fun `login por senha bloqueia conta de demonstracao e trata 429 e offline`() = runBlocking {
        var chamadas = 0
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val engine429 = MockEngine {
            chamadas++
            respond(
                content = """{"code":429,"error_code":"over_request_rate_limit"}""",
                status = HttpStatusCode.TooManyRequests,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico429 = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine429))
        val vmDemo = EntradaComSenhaViewModel(servico429, armazenamento, escopo = escopo())
        vmDemo.aoMudarEmail(DemonstracaoContas.EMAIL_PROFISSIONAL)
        vmDemo.aoMudarSenha("Senha#2026")
        assertNull(vmDemo.entrar())
        assertEquals(0, chamadas)
        assertNotNull(vmDemo.estado.value.erro)

        vmDemo.aoMudarEmail("real@exemplo.test")
        vmDemo.entrar()?.join()
        assertTrue(vmDemo.estado.value.erro!!.contains("Muitas tentativas"))

        val servicoOffline = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO),
                engine = engine429,
            ),
        )
        val vmOffline = EntradaComSenhaViewModel(servicoOffline, armazenamento, escopo = escopo())
        vmOffline.aoMudarEmail("real@exemplo.test")
        vmOffline.aoMudarSenha("Senha#2026")
        vmOffline.entrar()?.join()
        assertTrue(vmOffline.estado.value.erro!!.contains("Sem conexão"))
    }

    @Test
    fun `demonstracao abre a conta digitada (profissional ou contratante) e, sem e-mail de demo, a do profissional, sempre sem senha`() {
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            corpos += request.url.encodedPath
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = EntradaComSenhaViewModel(servico, ArmazenamentoDeSessaoEmMemoria(), escopo = escopo())

        assertFalse(vm.digitouContaDeDemonstracao())
        assertEquals(DemonstracaoContas.EMAIL_PROFISSIONAL, vm.emailDaDemonstracao())

        vm.aoMudarEmail("  ${DemonstracaoContas.EMAIL_CONTRATANTE.uppercase()} ")
        assertTrue(vm.digitouContaDeDemonstracao())
        assertEquals(DemonstracaoContas.EMAIL_CONTRATANTE, vm.emailDaDemonstracao())

        vm.aoMudarEmail(DemonstracaoContas.EMAIL_PROFISSIONAL)
        assertTrue(vm.digitouContaDeDemonstracao())
        assertEquals(DemonstracaoContas.EMAIL_PROFISSIONAL, vm.emailDaDemonstracao())

        vm.aoMudarEmail("conta@exemplo.test")
        assertFalse(vm.digitouContaDeDemonstracao())
        assertEquals(DemonstracaoContas.EMAIL_PROFISSIONAL, vm.emailDaDemonstracao())

        // Demo nunca habilita senha: o login por senha continua recusando as duas contas, sem chamar a rede.
        vm.aoMudarSenha("SenhaSintetica#2026")
        vm.aoMudarEmail(DemonstracaoContas.EMAIL_CONTRATANTE)
        assertNull(vm.entrar())
        assertTrue(corpos.isEmpty())
    }

    @Test
    fun `criar conta envia create_user true e bloqueia conta de demonstracao`() = runBlocking {
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            corpos += (request.body as TextContent).text
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = CriarContaViewModel(servico, escopo = escopo())

        vm.aoMudarEmail(DemonstracaoContas.EMAIL_PROFISSIONAL)
        assertNull(vm.solicitarCodigoDeCriacao())
        assertTrue(corpos.isEmpty())

        vm.aoMudarEmail("novo@exemplo.test")
        vm.solicitarCodigoDeCriacao()?.join()
        assertTrue(vm.estado.value.otpSolicitado)
        assertEquals(1, corpos.size)
        assertTrue(corpos[0].contains("\"create_user\":true"))
    }

    @Test
    fun `recuperacao envia create_user false e mostra o MESMO resultado com conta (200) e sem conta (422 otp_disabled)`() = runBlocking {
        val corpos = mutableListOf<String>()
        var statusAtual = HttpStatusCode.OK
        var corpoAtual = "{}"
        val engine = MockEngine { request ->
            corpos += (request.body as TextContent).text
            respond(corpoAtual, statusAtual, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))

        val vmComConta = RecuperacaoSenhaViewModel(servico, escopo = escopo(), emailInicial = "legado@exemplo.test")
        vmComConta.solicitarRecuperacao()?.join()
        assertTrue(corpos.last().contains("\"create_user\":false"))

        statusAtual = HttpStatusCode.UnprocessableEntity
        corpoAtual = """{"code":422,"error_code":"otp_disabled","msg":"Signups not allowed for otp"}"""
        val vmSemConta = RecuperacaoSenhaViewModel(servico, escopo = escopo(), emailInicial = "legado@exemplo.test")
        vmSemConta.solicitarRecuperacao()?.join()
        assertTrue(corpos.last().contains("\"create_user\":false"))

        // Mesmo estado visível: avança para o código, sem erro e sem carregando.
        assertTrue(vmComConta.estado.value.avancarParaCodigo)
        assertEquals(vmComConta.estado.value, vmSemConta.estado.value)
        assertNull(vmSemConta.estado.value.erro)
        assertFalse(vmSemConta.estado.value.carregando)
    }

    @Test
    fun `recuperacao trata user_not_found como sem conta e nao esconde 429, sem rede nem 5xx`() = runBlocking {
        var statusAtual = HttpStatusCode.NotFound
        var corpoAtual = """{"code":404,"error_code":"user_not_found"}"""
        val engine = MockEngine {
            respond(corpoAtual, statusAtual, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = RecuperacaoSenhaViewModel(servico, escopo = escopo())

        vm.aoMudarEmail(DemonstracaoContas.EMAIL_CONTRATANTE)
        assertNull(vm.solicitarRecuperacao())

        vm.aoMudarEmail("inexistente@exemplo.test")
        vm.solicitarRecuperacao()?.join()
        assertTrue(vm.estado.value.avancarParaCodigo)
        assertNull(vm.estado.value.erro)

        statusAtual = HttpStatusCode.TooManyRequests
        corpoAtual = """{"code":429,"error_code":"over_email_send_rate_limit"}"""
        vm.aoNavegarParaCodigo()
        vm.aoMudarEmail("legado@exemplo.test")
        vm.solicitarRecuperacao()?.join()
        assertEquals(MENSAGEM_LIMITE_DE_CODIGOS, vm.estado.value.erro)
        assertFalse(vm.estado.value.avancarParaCodigo)

        statusAtual = HttpStatusCode.InternalServerError
        corpoAtual = """{"code":500,"error_code":"unexpected_failure"}"""
        vm.solicitarRecuperacao()?.join()
        assertEquals("Não foi possível enviar o código. Tente de novo em instantes.", vm.estado.value.erro)
        assertFalse(vm.estado.value.avancarParaCodigo)
    }

    @Test
    fun `cancelamento na recuperacao impede retorno tardio de mutar estado ou avancar`() = runBlocking {
        val iniciou = CompletableDeferred<Unit>()
        val liberar = CompletableDeferred<Unit>()
        val engine = MockEngine {
            iniciou.complete(Unit)
            liberar.await()
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = RecuperacaoSenhaViewModel(servico, escopo = escopo())
        vm.aoMudarEmail("legado@exemplo.test")

        val job = vm.solicitarRecuperacao()!!
        iniciou.await()
        vm.cancelarTentativaAtual()
        liberar.complete(Unit)
        job.join()

        assertFalse(vm.estado.value.avancarParaCodigo)
        assertFalse(vm.estado.value.carregando)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `definir senha valida localmente, exige sessao ativa, limpa campos ao salvar e trata erros do GoTrue`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        var status = HttpStatusCode.OK
        var corpo = """{"id":"uid-1"}"""
        val engine = MockEngine { request ->
            if (request.url.encodedPath == "/auth/v1/token") {
                respond(
                    """{"access_token":"tok-ativo","refresh_token":"ref-ativo","token_type":"bearer","expires_in":3600}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave", armazenamentoDeSessao = armazenamento, engine = engine),
        )
        val vm = DefinirSenhaViewModel(servico, armazenamento, escopo = escopo())

        vm.aoMudarSenha("1234567")
        vm.aoMudarConfirmacao("1234567")
        assertNull(vm.salvar())
        assertTrue(vm.estado.value.erro!!.contains("8 caracteres"))

        vm.aoMudarSenha("SenhaForte#2026")
        vm.aoMudarConfirmacao("OutraSenha#2026")
        assertNull(vm.salvar())
        assertTrue(vm.estado.value.erro!!.contains("não conferem"))

        vm.aoMudarConfirmacao("SenhaForte#2026")
        assertNull(vm.salvar())
        assertTrue(vm.estado.value.erro!!.contains("sessão expirou"))

        armazenamento.salvarSessao(Sessao("tok-ativo", "ref-ativo", "bearer", 3600))
        status = HttpStatusCode.UnprocessableEntity
        corpo = """{"code":422,"error_code":"weak_password"}"""
        vm.salvar()?.join()
        assertTrue(vm.estado.value.erro!!.contains("mais forte"))

        status = HttpStatusCode.Unauthorized
        corpo = """{"code":401,"error_code":"reauthentication_needed"}"""
        vm.salvar()?.join()
        assertTrue(vm.estado.value.erro!!.contains("novo código"))

        status = HttpStatusCode.OK
        corpo = """{"id":"uid-1"}"""
        vm.salvar()?.join()
        assertTrue(vm.estado.value.concluido)
        assertEquals("", vm.estado.value.senha)
        assertEquals("", vm.estado.value.confirmacao)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `CodigoViewModel em modo RECUPERACAO reenvia com create_user false e sem fallback demo`() = runBlocking {
        val corpos = mutableListOf<String>()
        val caminhos = mutableListOf<String>()
        var instante = Instant.parse("2026-11-24T01:00:00Z")
        val engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            corpos += (request.body as TextContent).text
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = CodigoViewModel(
            email = "legado@exemplo.test",
            servicoAutenticacao = servico,
            armazenamentoDeSessao = ArmazenamentoDeSessaoEmMemoria(),
            escopo = escopo(),
            agora = { instante },
            modo = ModoCodigo.RECUPERACAO,
        )

        instante = instante.plusSeconds(61)
        vm.reenviarCodigo()?.join()

        assertEquals(listOf("/auth/v1/otp"), caminhos)
        assertTrue(corpos.single().contains("\"create_user\":false"))
        assertTrue(vm.estado.value.reenviado)
    }

    @Test
    fun `CodigoViewModel em modo DEMO chama exclusivamente entrar-demonstracao`() = runBlocking {
        val caminhos = mutableListOf<String>()
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            respond(
                content = """{"access_token":"tok-demo","refresh_token":"ref-demo","token_type":"bearer","expires_in":3600}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = CodigoViewModel(
            email = DemonstracaoContas.EMAIL_PROFISSIONAL,
            servicoAutenticacao = servico,
            armazenamentoDeSessao = armazenamento,
            escopo = escopo(),
            modo = ModoCodigo.DEMO,
        )

        vm.aoMudarCodigo("123456")?.join()

        assertEquals(listOf("/functions/v1/entrar-demonstracao"), caminhos)
        assertTrue(vm.estado.value.autenticado)
        assertEquals("tok-demo", armazenamento.obterSessao()?.accessToken)
    }
}
