package br.com.frila.app.seguranca

import android.app.Application
import android.content.Context
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.app.moduloSeguranca
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.File
import java.util.Base64
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * #793 (dado pessoal: foto). O avatar fica em `filesDir` e o Perfil mostra o arquivo `avatar_perfil_*` mais recente, sem checar de
 * quem é. "Sair" apaga o arquivo pelo `CoordenadorDeLogout`, mas a sessão também cai por outros caminhos (o Auth recusa a
 * renovação) e a conta pode ser trocada sem passar por "Sair". Nesses caminhos o avatar de A não pode sobrar para B.
 *
 * O armazenamento é o do grafo de produção (`moduloSeguranca`: `SessaoComCacheVagas` sobre o Keystore, aqui com o provedor falso) e
 * o cliente é o `ClienteSupabase` real sobre um motor HTTP falso.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AvatarDaContaAnteriorTest {

    private lateinit var contexto: Context
    private lateinit var armazenamento: ArmazenamentoDeSessao

    private fun jwt(conta: String): String {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$conta"}""".toByteArray())
        return "cabecalho.$corpo.assinatura-sintetica"
    }

    private fun sessao(conta: String, renovacao: String = "refresh-$conta") =
        Sessao(accessToken = jwt(conta), refreshToken = renovacao, tokenType = "bearer", expiresIn = 3_600L, vinculoId = null)

    @Before
    fun preparar() {
        FakeAndroidKeyStoreProvider.registrar()
        contexto = RuntimeEnvironment.getApplication()
        contexto.deleteSharedPreferences("sessao_segura")
        startKoin {
            androidContext(contexto)
            modules(moduloSeguranca)
        }
        armazenamento = GlobalContext.get().get()
    }

    @After
    fun limpar() {
        stopKoin()
        contexto.filesDir.listFiles { a -> a.name.startsWith(CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR) }?.forEach { it.delete() }
        contexto.deleteSharedPreferences("sessao_segura")
        FakeAndroidKeyStoreProvider.resetar()
    }

    private fun guardarAvatarDe(conta: String): File =
        File(contexto.filesDir, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}${System.currentTimeMillis()}.jpg")
            .also { it.writeText("foto-de-$conta") }

    /** Um pedido da conta A: o `401` dispara a renovação, que o Auth responde com [statusDoAuth]. */
    private fun pedidoDeAComRenovacao(statusDoAuth: HttpStatusCode, corpoDoAuth: String) = runBlocking {
        val engine = MockEngine { pedido ->
            when {
                pedido.url.encodedPath == "/auth/v1/token" ->
                    respond(corpoDoAuth, statusDoAuth, headersOf(HttpHeaders.ContentType, "application/json"))
                pedido.headers[HttpHeaders.Authorization] == "Bearer ${jwt("a")}" ->
                    respond("{}", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.ContentType, "application/json"))
                else -> respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave-anonima-de-teste", armazenamentoDeSessao = armazenamento, engine = engine)
        runCatching { cliente.http.get(cliente.urlRpc("minha_conta")) }
    }

    @Test
    fun `sessao que cai porque o Auth recusa a renovacao nao deixa o avatar para a conta seguinte`() {
        armazenamento.salvarSessao(sessao("a"))
        guardarAvatarDe("a")
        assertNotNull(CompressorDeFotoPerfil.avatarExistente(contexto))

        pedidoDeAComRenovacao(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")
        assertNull(armazenamento.obterSessao())
        armazenamento.salvarSessao(sessao("b"))

        assertNull(CompressorDeFotoPerfil.avatarExistente(contexto))
    }

    @Test
    fun `troca direta de conta sem Sair nao deixa o avatar para a conta seguinte`() {
        armazenamento.salvarSessao(sessao("a"))
        guardarAvatarDe("a")

        armazenamento.salvarSessao(sessao("b"))

        assertNull(CompressorDeFotoPerfil.avatarExistente(contexto))
    }

    @Test
    fun `renovacao bem sucedida da mesma conta preserva o avatar`() {
        armazenamento.salvarSessao(sessao("a"))
        val avatar = guardarAvatarDe("a")

        pedidoDeAComRenovacao(
            HttpStatusCode.OK,
            """{"access_token":"${jwt("a")}x","refresh_token":"refresh-a-2","token_type":"bearer","expires_in":3600}""",
        )

        assertEquals("refresh-a-2", armazenamento.obterSessao()?.refreshToken)
        assertEquals(avatar, CompressorDeFotoPerfil.avatarExistente(contexto))
    }
}
