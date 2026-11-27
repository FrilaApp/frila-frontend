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
import io.ktor.client.network.sockets.ConnectTimeoutException
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
            assertEquals("/functions/v1/autenticar-senha", request.url.encodedPath)
            respond(
                content = """{"status":"autenticado","sessao":{"access_token":"tok-1","refresh_token":"ref-1","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
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
        var corpo = """{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}"""
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
        corpo = """{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}"""
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

    @Test
    fun `entrada com desafio_otp limpa senha, nao abre sessao e expoe desafioOtp`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val engine = MockEngine {
            respond(
                content = """{"status":"desafio_otp","desafio_id":"des-android-1","expira_em":"2026-11-25T15:00:00Z","descartar_device_token":false}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine))
        val vm = EntradaComSenhaViewModel(servico, armazenamento, escopo = escopo())

        vm.aoMudarEmail("prof@exemplo.test")
        vm.aoMudarSenha("SenhaSintetica#2026")
        vm.entrar()?.join()

        assertFalse(vm.estado.value.autenticado)
        assertEquals("", vm.estado.value.senha)
        assertEquals(DesafioOtpPendente("prof@exemplo.test", "des-android-1"), vm.estado.value.desafioOtp)
        assertFalse(armazenamento.estaAutenticado())
    }

    @Test
    fun `CodigoViewModel em loginDispositivo confirma com lembrarDispositivo e reenvia mantendo desafioId`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val dispositivo = br.com.frila.core.seguranca.ArmazenamentoDeDispositivoEmMemoria()
        var agora = Instant.parse("2026-11-25T12:00:00Z")
        val engine = MockEngine { request ->
            when (request.url.encodedPath) {
                "/functions/v1/reenviar-dispositivo-otp" -> respond(
                    content = """{"ok":true,"desafio_id":"des-android-2","expira_em":"2026-11-25T12:15:00Z","reenviar_em_segundos":45}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                "/functions/v1/confirmar-dispositivo-otp" -> respond(
                    content = """{"sessao":{"access_token":"tok-disp","refresh_token":"ref-disp","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false,"device_token":"tok-30d-android"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                else -> error("Rota inesperada: ${request.url.encodedPath}")
            }
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave", engine = engine), dispositivo)
        val vm = CodigoViewModel(
            email = "prof@exemplo.test",
            servicoAutenticacao = servico,
            armazenamentoDeSessao = armazenamento,
            escopo = escopo(),
            agora = { agora },
            modo = ModoCodigo.LOGIN_DISPOSITIVO,
            desafioIdInicial = "des-android-1",
        )
        vm.aoAlternarLembrarDispositivo(true)
        agora = agora.plusSeconds(60)
        vm.reenviarCodigo()?.join()
        assertEquals(45L, vm.segundosParaReenviar())

        vm.aoMudarCodigo("123456")?.join()
        assertTrue(vm.estado.value.autenticado)
        assertTrue(vm.estado.value.dispositivoLembrado)
        assertEquals("tok-30d-android", dispositivo.obterToken("prof@exemplo.test"))
    }

    @Test
    fun `DefinirSenhaViewModel resolve email da sessao ou JWT para manter dispositivo atual e preservar outras contas`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val dispositivo = br.com.frila.core.seguranca.ArmazenamentoDeDispositivoEmMemoria().apply {
            salvarToken("conta@exemplo.test", "tok-30d-conta")
            salvarToken("outra@exemplo.test", "tok-30d-outra")
        }
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            corpos += (request.body as TextContent).text
            respond(
                content = """{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave", armazenamentoDeSessao = armazenamento, engine = engine),
            dispositivo,
        )

        // 1. Sem emailAtual explícito e sem Sessao.email: decodifica do payload JWT e envia device_token_atual não nulo.
        val payloadBase64 = java.util.Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"uid-1","email":"conta@exemplo.test"}""".toByteArray())
        armazenamento.salvarSessao(Sessao("hdr.$payloadBase64.sig", "ref-jwt", "bearer", 3600))

        val vmManter = DefinirSenhaViewModel(servico, armazenamento, escopo = escopo(), manterDispositivoAtual = true)
        vmManter.aoMudarSenha("SenhaForte#2026")
        vmManter.aoMudarConfirmacao("SenhaForte#2026")
        vmManter.salvar()?.join()

        assertTrue(vmManter.estado.value.concluido)
        assertTrue(corpos.last().contains("\"manter_dispositivo_atual\":true"))
        assertTrue(corpos.last().contains("\"device_token_atual\":\"tok-30d-conta\""))
        assertEquals("tok-30d-conta", dispositivo.obterToken("conta@exemplo.test"))
        assertEquals("tok-30d-outra", dispositivo.obterToken("outra@exemplo.test"))

        // 2. Troca comum (manterDispositivoAtual = false) usando Sessao.email remove só a conta atual e preserva outra@exemplo.test.
        armazenamento.salvarSessao(Sessao("tok-sem-jwt", "ref-2", "bearer", 3600, email = "conta@exemplo.test"))
        val vmTroca = DefinirSenhaViewModel(servico, armazenamento, escopo = escopo(), manterDispositivoAtual = false)
        vmTroca.aoMudarSenha("SenhaNova#2026")
        vmTroca.aoMudarConfirmacao("SenhaNova#2026")
        vmTroca.salvar()?.join()

        assertTrue(vmTroca.estado.value.concluido)
        assertEquals(null, dispositivo.obterToken("conta@exemplo.test"))
        assertEquals("tok-30d-outra", dispositivo.obterToken("outra@exemplo.test"))
    }


    // ---- 429 e sem rede ao definir a senha (cartão N3C2942I, 122): só teste, o mapeamento já existe ----

    private fun definirSenhaComSessao(engine: MockEngine): DefinirSenhaViewModel {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        armazenamento.salvarSessao(Sessao("tok-ativo", "ref-ativo", "bearer", 3600))
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave", armazenamentoDeSessao = armazenamento, engine = engine),
        )
        return DefinirSenhaViewModel(servico, armazenamento, escopo = escopo()).apply {
            aoMudarSenha("SenhaForte#2026")
            aoMudarConfirmacao("SenhaForte#2026")
        }
    }

    @Test
    fun `definir senha com 429 pede para aguardar alguns minutos`() = runBlocking {
        // O GoTrue responde 429 com error_code de limite, ou só o status.
        for (corpo in listOf("""{"code":429,"error_code":"over_request_rate_limit","msg":"x"}""", """{"code":429,"msg":"x"}""")) {
            val vm = definirSenhaComSessao(
                MockEngine { respond(corpo, HttpStatusCode.TooManyRequests, headersOf(HttpHeaders.ContentType, "application/json")) },
            )

            vm.salvar()!!.join()

            assertEquals(corpo, "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo.", vm.estado.value.erro)
            assertFalse(corpo, vm.estado.value.concluido)
            assertFalse(corpo, vm.estado.value.carregando)
        }
    }

    @Test
    fun `definir senha sem rede mostra a mensagem de sem conexao`() = runBlocking {
        // O cliente converte a falha de conexão em ErroDaApi(SEM_REDE) (ClienteSupabase, HttpResponseValidator).
        val vm = definirSenhaComSessao(MockEngine { throw ConnectTimeoutException("sem rede") })

        vm.salvar()!!.join()

        assertEquals("Sem conexão. Verifique sua internet e tente de novo.", vm.estado.value.erro)
        assertFalse(vm.estado.value.concluido)
        assertFalse(vm.estado.value.carregando)
    }
}
