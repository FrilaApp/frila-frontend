package br.com.frila.feature.entrada.senha

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ProvedorSocial
import br.com.frila.core.rede.ResultadoCallbackOAuth
import br.com.frila.core.rede.SegurancaOAuthSocial
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import java.net.URI
import java.net.URLDecoder
import java.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LoginSocialViewModelTest {

    private fun escopo() = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private fun fakeJwtComEmail(email: String): String {
        val header = Base64.getUrlEncoder().withoutPadding().encodeToString("""{"alg":"HS256"}""".toByteArray())
        val payload = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"11111111-1111-4111-8111-111111111111","email":"$email"}""".toByteArray())
        return "$header.$payload.sig"
    }

    private fun clienteAutenticarSocialMock(
        statusConclusao: HttpStatusCode = HttpStatusCode.OK,
        corpoConclusao: String = """{"sessao":{"access_token":"${fakeJwtComEmail("ana@frila.test")}","refresh_token":"ref-social","token_type":"bearer","expires_in":3600},"provedor":"google","precisa_definir_senha":false}""",
    ): ClienteSupabase {
        val engine = MockEngine { request ->
            val texto = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
            val json = Json.parseToJsonElement(texto).jsonObject
            val fluxo = json["fluxo"]?.jsonPrimitive?.content
            if (fluxo == "iniciar_pkce") {
                val provedor = json["provedor"]?.jsonPrimitive?.content ?: "google"
                val redirectTo = json["redirect_to"]?.jsonPrimitive?.content ?: SegurancaOAuthSocial.URL_CALLBACK
                val challenge = json["code_challenge"]?.jsonPrimitive?.content ?: ""
                val urlAuth = "https://dev.supabase.co/auth/v1/authorize?provider=$provedor&redirect_to=${java.net.URLEncoder.encode(redirectTo, "UTF-8")}&code_challenge=$challenge&code_challenge_method=s256"
                respond(
                    content = """{"transacao_id":"33333333-3333-4333-8333-333333333333","url_autorizacao":"$urlAuth","expira_em":"2026-11-25T21:10:00Z"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(
                    content = corpoConclusao,
                    status = statusConclusao,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            }
        }
        return ClienteSupabase(
            baseUrl = "https://dev.supabase.co",
            apiKey = "anon-key",
            engine = engine,
        )
    }

    private fun extrairParam(url: String, chave: String): String? {
        val rawQuery = URI(url).rawQuery ?: return null
        return rawQuery.split('&').firstNotNullOfOrNull { par ->
            val idx = par.indexOf('=')
            val k = URLDecoder.decode(if (idx >= 0) par.substring(0, idx) else par, Charsets.UTF_8.name())
            if (k == chave && idx >= 0) URLDecoder.decode(par.substring(idx + 1), Charsets.UTF_8.name()) else null
        }
    }

    @Test
    fun `gera verifier PKCE S256 valido e valida callback com correlacao tx (P2) e conflito`() {
        val verifier = SegurancaOAuthSocial.gerarVerifierPkce()
        val challenge = SegurancaOAuthSocial.desafioPkceS256(verifier)
        assertTrue(SegurancaOAuthSocial.ehVerifierValido(verifier))
        assertEquals(43, verifier.length)
        assertEquals(43, challenge.length)
        assertNotEquals(verifier, challenge)

        assertEquals(
            ResultadoCallbackOAuth.Codigo("cod-1234"),
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?code=cod-1234&tx=s1", stateEsperado = "s1"),
        )
        // P1: callback com code SEM tx/state ou com tx divergente é Ignorado (nunca aceito, nunca zera oauthPendente)
        assertEquals(
            ResultadoCallbackOAuth.Ignorado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?code=cod-1234", stateEsperado = "s1"),
        )
        assertEquals(
            ResultadoCallbackOAuth.Ignorado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?code=cod-1234&tx=outro", stateEsperado = "s1"),
        )
        // P2: scheme, host ou path errados são recusados (Ignorado quando há transação ativa; CallbackInvalido sem transação)
        assertEquals(
            ResultadoCallbackOAuth.Ignorado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://outro/callback?code=cod-1234&tx=s1", stateEsperado = "s1"),
        )
        assertEquals(
            ResultadoCallbackOAuth.Ignorado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/errado?code=cod-1234&tx=s1", stateEsperado = "s1"),
        )
        assertEquals(
            ResultadoCallbackOAuth.CallbackInvalido,
            SegurancaOAuthSocial.analisarCallback("frila-auth://outro/callback?code=cod-1234"),
        )
        assertEquals(
            ResultadoCallbackOAuth.CallbackInvalido,
            SegurancaOAuthSocial.analisarCallback("https://evil.example/callback?code=cod-1234"),
        )
        // P1/P2: callback forjado com ?error=... sem tx correspondente é Ignorado (não limpa transação ativa)
        assertEquals(
            ResultadoCallbackOAuth.Ignorado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?error=access_denied", stateEsperado = "s1"),
        )
        assertEquals(
            ResultadoCallbackOAuth.Cancelado,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?error=access_denied&tx=s1", stateEsperado = "s1"),
        )
        assertEquals(
            ResultadoCallbackOAuth.ConflitoDeIdentidade,
            SegurancaOAuthSocial.analisarCallback("frila-auth://auth/callback?error_code=identity_already_exists&tx=s1", stateEsperado = "s1"),
        )
    }

    @Test
    fun `iniciarEntradaSocial desligado em producao retorna null`() = runBlocking {
        val vm = EntradaComSenhaViewModel(
            servicoAutenticacao = ServicoAutenticacao(clienteAutenticarSocialMock()),
            armazenamentoDeSessao = ArmazenamentoDeSessaoEmMemoria(),
            escopo = escopo(),
            mostrarLoginSocial = false,
        )
        assertNull(vm.iniciarEntradaSocial(ProvedorSocial.GOOGLE) {})
        assertNull(vm.iniciarEntradaSocial(ProvedorSocial.APPLE) {})
    }

    @Test
    fun `Google PKCE usa autenticar-social, ignora erro forjado sem tx (P2) e conclui com bloqueio de replay`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val vm = EntradaComSenhaViewModel(
            servicoAutenticacao = ServicoAutenticacao(clienteAutenticarSocialMock()),
            armazenamentoDeSessao = armazenamento,
            escopo = escopo(),
            mostrarLoginSocial = true,
        )

        var urlAuth: String? = null
        vm.iniciarEntradaSocial(ProvedorSocial.GOOGLE) { urlAuth = it }?.join()
        assertNotNull(urlAuth)
        val redirectTo = extrairParam(urlAuth!!, "redirect_to")!!
        val txLocal = extrairParam(redirectTo, "tx")!!
        assertEquals("google", extrairParam(urlAuth!!, "provider"))
        assertEquals("s256", extrairParam(urlAuth!!, "code_challenge_method"))

        // P1/P2: callbacks forjados (sem tx, tx divergente, host errado, path errado, erro sem tx)
        // NÃO consomem nem apagam oauthPendente
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-forjado"))
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-forjado&tx=divergente"))
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://outro/callback?code=cod-forjado&tx=$txLocal"))
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://auth/outro?code=cod-forjado&tx=$txLocal"))
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://auth/callback?error=access_denied"))
        assertFalse(vm.estado.value.autenticado)

        // Callback legítimo com tx correspondente conclui normalmente (prova que oauthPendente foi preservado)
        vm.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-google-123&tx=$txLocal")?.join()

        assertTrue(vm.estado.value.autenticado)
        assertNull(vm.estado.value.erro)
        assertEquals("ana@frila.test", armazenamento.obterSessao()?.email)
        // Replay do mesmo callback depois de consumido é ignorado
        assertNull(vm.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-google-123&tx=$txLocal"))
    }

    @Test
    fun `Apple trata cancelamento com tx sem erro e conflito de identidade sem salvar sessao`() = runBlocking {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val vm = EntradaComSenhaViewModel(
            servicoAutenticacao = ServicoAutenticacao(
                clienteAutenticarSocialMock(
                    statusConclusao = HttpStatusCode.Conflict,
                    corpoConclusao = """{"code":"conflito_identidade","message":"Conflito"}""",
                ),
            ),
            armazenamentoDeSessao = armazenamento,
            escopo = escopo(),
            mostrarLoginSocial = true,
        )

        // 1. Cancelamento com tx correspondente
        var url1: String? = null
        vm.iniciarEntradaSocial(ProvedorSocial.APPLE) { url1 = it }?.join()
        assertEquals("apple", extrairParam(url1!!, "provider"))
        val tx1 = extrairParam(extrairParam(url1!!, "redirect_to")!!, "tx")!!
        vm.aoReceberCallbackOAuth("frila-auth://auth/callback?error=access_denied&tx=$tx1")
        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.autenticado)

        // 2. Conflito de identidade devolvido por autenticar-social (409)
        var url2: String? = null
        vm.iniciarEntradaSocial(ProvedorSocial.APPLE) { url2 = it }?.join()
        val tx2 = extrairParam(extrairParam(url2!!, "redirect_to")!!, "tx")!!
        vm.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-apple-999&tx=$tx2")?.join()

        assertFalse(vm.estado.value.autenticado)
        assertNull(armazenamento.obterSessao())
        assertEquals(EntradaComSenhaViewModel.MENSAGEM_CONFLITO_IDENTIDADE, vm.estado.value.erro)
    }

    @Test
    fun `transacao OAuth sobrevive a recreation do ViewModel e morte simulada de processo`() = runBlocking {
        val armazenamentoSessao = ArmazenamentoDeSessaoEmMemoria()
        val armazenamentoOAuth = br.com.frila.core.seguranca.ArmazenamentoOAuthPendenteEmMemoria()
        val servicoAuth = ServicoAutenticacao(clienteAutenticarSocialMock())

        // 1ª Instância do ViewModel inicia a transação antes da morte do processo / recreation
        val vmInstancia1 = EntradaComSenhaViewModel(
            servicoAutenticacao = servicoAuth,
            armazenamentoDeSessao = armazenamentoSessao,
            escopo = escopo(),
            mostrarLoginSocial = true,
            armazenamentoOAuthPendente = armazenamentoOAuth,
        )

        var urlAuth: String? = null
        vmInstancia1.iniciarEntradaSocial(ProvedorSocial.GOOGLE) { urlAuth = it }?.join()
        assertNotNull(urlAuth)
        val redirectTo = extrairParam(urlAuth!!, "redirect_to")!!
        val txLocal = extrairParam(redirectTo, "tx")!!

        // Simula recreation da tela (onDispose chamado com limparOAuth = false na rotação/recreation)
        vmInstancia1.cancelarTentativaAtual(limparOAuth = false)

        // 2ª Instância do ViewModel criada após recreation / process death (nova instância de VM recebendo o mesmo armazenamento)
        val vmInstancia2 = EntradaComSenhaViewModel(
            servicoAutenticacao = servicoAuth,
            armazenamentoDeSessao = armazenamentoSessao,
            escopo = escopo(),
            mostrarLoginSocial = true,
            armazenamentoOAuthPendente = armazenamentoOAuth,
        )

        // Callback legítimo chega na nova instância do ViewModel e conclui com sucesso
        vmInstancia2.aoReceberCallbackOAuth("frila-auth://auth/callback?code=cod-google-recreated&tx=$txLocal")?.join()

        assertTrue(vmInstancia2.estado.value.autenticado)
        assertNull(vmInstancia2.estado.value.erro)
        assertEquals("ana@frila.test", armazenamentoSessao.obterSessao()?.email)

        // Garante que a transação foi consumida e limpa no armazenamento persistido
        assertNull(armazenamentoOAuth.obter())
    }
}
