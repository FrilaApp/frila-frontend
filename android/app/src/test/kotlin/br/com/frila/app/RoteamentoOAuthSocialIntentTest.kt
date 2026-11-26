package br.com.frila.app

import android.app.Application
import android.content.Intent
import android.net.Uri
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ProvedorSocial
import br.com.frila.core.rede.SegurancaOAuthSocial
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.senha.EntradaComSenhaViewModel
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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class RoteamentoOAuthSocialIntentTest {

    private fun fakeJwt(email: String): String {
        val h = Base64.getUrlEncoder().withoutPadding().encodeToString("""{"alg":"HS256"}""".toByteArray())
        val p = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"11111111-1111-4111-8111-111111111111","email":"$email"}""".toByteArray())
        return "$h.$p.sig"
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
    fun `extrairCallbackOAuthSocialDoIntent aceita apenas ACTION_VIEW com scheme, host auth e path callback exatos`() {
        val valido = Intent(Intent.ACTION_VIEW, Uri.parse("frila-auth://auth/callback?code=abc123&tx=t1"))
        assertEquals(
            "frila-auth://auth/callback?code=abc123&tx=t1",
            extrairCallbackOAuthSocialDoIntent(valido),
        )

        // Rejeita host errado, path errado, scheme diferente e action diferente
        assertNull(extrairCallbackOAuthSocialDoIntent(Intent(Intent.ACTION_VIEW, Uri.parse("frila-auth://outro/callback?code=abc&tx=t1"))))
        assertNull(extrairCallbackOAuthSocialDoIntent(Intent(Intent.ACTION_VIEW, Uri.parse("frila-auth://auth/errado?code=abc&tx=t1"))))
        assertNull(extrairCallbackOAuthSocialDoIntent(Intent(Intent.ACTION_VIEW, Uri.parse("frila://vagas/123"))))
        assertNull(extrairCallbackOAuthSocialDoIntent(Intent(Intent.ACTION_MAIN, Uri.parse("frila-auth://auth/callback?code=abc&tx=t1"))))
        assertNull(extrairCallbackOAuthSocialDoIntent(null))
    }

    @Test
    fun `fluxo Intent warm start entrega callback ao ViewModel via StateFlow e cold start sem transacao e ignorado com seguranca`() = runBlocking {
        val engine = MockEngine { request ->
            val texto = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
            val json = Json.parseToJsonElement(texto).jsonObject
            if (json["fluxo"]?.jsonPrimitive?.content == "iniciar_pkce") {
                val redirectTo = json["redirect_to"]?.jsonPrimitive?.content ?: SegurancaOAuthSocial.URL_CALLBACK
                val url = "https://dev.supabase.co/auth/v1/authorize?provider=google&redirect_to=${java.net.URLEncoder.encode(redirectTo, "UTF-8")}&code_challenge_method=s256"
                respond(
                    content = """{"transacao_id":"33333333-3333-4333-8333-333333333333","url_autorizacao":"$url"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(
                    content = """{"sessao":{"access_token":"${fakeJwt("ana@frila.test")}","refresh_token":"ref-1","token_type":"bearer","expires_in":3600},"provedor":"google","precisa_definir_senha":false}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            }
        }
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val vm = EntradaComSenhaViewModel(
            servicoAutenticacao = ServicoAutenticacao(ClienteSupabase("https://dev.supabase.co", "anon", engine = engine)),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default),
            mostrarLoginSocial = true,
        )
        val canalCallback = MutableStateFlow<String?>(null)

        // 1. Cold start com Intent de callback órfão (sem transação iniciada em memória): ignorado sem autenticar
        val coldIntent = Intent(Intent.ACTION_VIEW, Uri.parse("frila-auth://auth/callback?code=orfao-123&tx=antigo"))
        canalCallback.value = extrairCallbackOAuthSocialDoIntent(coldIntent)
        assertNotNull(canalCallback.value)
        assertNull(vm.aoReceberCallbackOAuth(canalCallback.value!!))
        canalCallback.value = null
        assertFalse(vm.estado.value.autenticado)

        // 2. Warm start: inicia login, recebe Intent de retorno via onNewIntent -> StateFlow -> conclui sessão
        var urlAberta: String? = null
        vm.iniciarEntradaSocial(ProvedorSocial.GOOGLE) { urlAberta = it }?.join()
        assertNotNull(urlAberta)
        val tx = extrairParam(extrairParam(urlAberta!!, "redirect_to")!!, "tx")!!

        val warmIntent = Intent(Intent.ACTION_VIEW, Uri.parse("frila-auth://auth/callback?code=cod-warm-999&tx=$tx"))
        canalCallback.value = extrairCallbackOAuthSocialDoIntent(warmIntent)
        vm.aoReceberCallbackOAuth(canalCallback.value!!)?.join()
        canalCallback.value = null

        assertTrue(vm.estado.value.autenticado)
        assertEquals("ana@frila.test", armazenamento.obterSessao()?.email)
    }
}
