package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Text
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class PortaoDeAtualizacaoTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun `quando versao for menor que versaoMinima portao exibe tela de atualizacao e oculta conteudo`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.0.0",
                versaoMinima = "1.2.0",
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO).assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR).assertIsDisplayed()
        rule.onNodeWithText("Conteudo Protegido do App").assertDoesNotExist()
    }

    @Test
    fun `quando versao for igual ou superior a versaoMinima portao renderiza conteudo`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.2.0",
                versaoMinima = "1.2.0",
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText("Conteudo Protegido do App").assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `quando versaoMinima for nula portao renderiza conteudo normalmente`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.1.0",
                versaoMinima = null,
                conteudo = { Text("Conteudo Liberado") },
            )
        }

        rule.onNodeWithText("Conteudo Liberado").assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `quando usuario toca em atualizar botao aciona callback aoAtualizar`() {
        var atualizacaoDisparada = false

        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "0.9.0",
                versaoMinima = "1.0.0",
                aoAtualizar = { atualizacaoDisparada = true },
                conteudo = { Text("Conteudo") },
            )
        }

        rule.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR).performClick()
        rule.waitForIdle()

        assertTrue(atualizacaoDisparada)
    }

    @Test
    fun `portao reage dinamicamente e bloqueia interface ao receber minima nova superior a instalada`() {
        val minima = mutableStateOf("1.0.0")

        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.1.0",
                versaoMinima = minima.value,
                conteudo = { Text("Conteudo Utilizavel") },
            )
        }

        rule.onNodeWithText("Conteudo Utilizavel").assertIsDisplayed()

        rule.runOnIdle {
            minima.value = "2.0.0"
        }

        rule.onNodeWithText("Conteudo Utilizavel").assertDoesNotExist()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertIsDisplayed()
    }

    @Test
    fun `quando verificando for verdadeiro portao nao renderiza conteudo nem tela de atualizacao`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.0.0",
                versaoMinima = "2.0.0",
                verificando = true,
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText("Conteudo Protegido do App").assertDoesNotExist()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `quando verificando transicionar para falso portao libera conteudo se versao compativel`() {
        val verificando = mutableStateOf(true)

        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.2.0",
                versaoMinima = "1.0.0",
                verificando = verificando.value,
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText("Conteudo Protegido do App").assertDoesNotExist()

        rule.runOnIdle {
            verificando.value = false
        }

        rule.onNodeWithText("Conteudo Protegido do App").assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `consultarConfiguracaoDoApp busca configuracao da plataforma android e decodifica versao_minima`() = runBlocking {
        var caminhoChamado: String? = null
        var parametroPlataforma: String? = null
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                caminhoChamado = request.url.encodedPath
                parametroPlataforma = request.url.parameters["plataforma"]
                respond(
                    content = """{"plataforma":"android","versao_minima":"99.0.0","versao_recomendada":"99.0.0","url_da_loja":"https://play.google.com/store/apps/details?id=br.com.frila.app","mensagem":"Atualize agora"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        try {
            val resultado = consultarConfiguracaoDoApp(cliente)
            assertNotNull(resultado)
            assertEquals("/rest/v1/rpc/configuracao_do_app", caminhoChamado)
            assertEquals("android", parametroPlataforma)
            assertEquals("android", resultado.plataforma)
            assertEquals("99.0.0", resultado.versaoMinima)
            assertEquals("Atualize agora", resultado.mensagem)
        } finally {
            cliente.http.close()
        }
    }

    @Test
    fun `consultarConfiguracaoDoApp propaga erro quando backend responde com falha`() = runBlocking {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = """{"code":"PGRST500","message":"Erro interno","details":null,"hint":null}""",
                    status = HttpStatusCode.InternalServerError,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        try {
            var falhou = false
            try {
                consultarConfiguracaoDoApp(cliente)
            } catch (e: Exception) {
                falhou = true
            }
            assertTrue("Falha de rede ou 500 deve propagar excecao", falhou)
        } finally {
            cliente.http.close()
        }
    }
}
