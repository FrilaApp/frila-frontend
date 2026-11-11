package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Text
import androidx.compose.runtime.remember
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * RN15: [RotaProtegida] é a garantia de que o conteúdo protegido não é composto, nem por um quadro, com a
 * sessão travada. O listener de [instalarGuardaBiometrico] redireciona antes de a rota compor quando a
 * navegação acontece depois dele, e por isso os testes de navegação por si sós não distinguem uma rota com
 * `RotaProtegida` de uma sem (o mutante A08, sobrevivente em cinco PRs seguidos). Aqui o composable é
 * provado direto, e a presença dele em cada rota do grafo é conferida no texto de `AppNavegacao`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RotaProtegidaTest {

    @get:Rule
    val rule = createComposeRule()

    /** Quantas vezes o conteúdo entrou na composição: `remember` roda uma vez por entrada. */
    private var entradas = 0

    private fun montar(guarda: GuardaBiometrico) {
        rule.setContent {
            RotaProtegida(guarda) {
                remember { entradas++ }
                Text("Conteúdo protegido")
            }
        }
    }

    @Test
    fun `com a sessao travada o conteudo nunca e composto`() {
        montar(GuardaBiometrico(sessaoDesbloqueadaInicial = false))
        rule.waitForIdle()

        assertEquals(0, entradas)
        rule.onNodeWithText("Conteúdo protegido").assertDoesNotExist()
    }

    @Test
    fun `com a sessao destravada o conteudo e composto exatamente uma vez`() {
        montar(GuardaBiometrico(sessaoDesbloqueadaInicial = true))
        rule.waitForIdle()

        assertEquals(1, entradas)
        rule.onNodeWithText("Conteúdo protegido").assertExists()
    }

    @Test
    fun `destravar depois compoe o conteudo uma vez so, e so a partir do desbloqueio`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)
        montar(guarda)
        rule.waitForIdle()
        assertEquals(0, entradas)

        rule.runOnIdle { guarda.aoDesbloquearComSucesso() }
        rule.waitForIdle()

        assertEquals(1, entradas)
        rule.onNodeWithText("Conteúdo protegido").assertExists()
    }

    @Test
    fun `liberar apos limpar a sessao tambem destrava o conteudo`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)
        montar(guarda)
        rule.waitForIdle()

        rule.runOnIdle { guarda.liberarAposLimparSessao() }
        rule.waitForIdle()

        assertEquals(1, entradas)
    }

    // ---- Presença em cada rota do grafo ----

    /**
     * Rotas que ficam fora de `RotaProtegida` de propósito: as do fluxo de login e desbloqueio, que não
     * fazem sentido gatear a si mesmas ([GuardaBiometrico.ROTAS_SEM_GATE]), a conta suspensa (o usuário
     * precisa ver o aviso e o botão de sair) e a atualização obrigatória (o app não segue sem ela).
     */
    private val USO_DA_GUARDA = Regex("""RotaProtegida\(guardaBiometrico\)\s*\{""")

    private val rotasAbertas = GuardaBiometrico.ROTAS_SEM_GATE + setOf(Rotas.CONTA_SUSPENSA, Rotas.ATUALIZACAO_OBRIGATORIA)

    private fun textoDoGrafo(): String {
        val relativo = "src/main/kotlin/br/com/frila/app/AppNavegacao.kt"
        val arquivo = listOf(File(relativo), File("app/$relativo")).first { it.exists() }
        // Sem comentários de linha nem de bloco: o nome no texto de um comentário não vale como uso.
        return arquivo.readText()
            .replace(Regex("""/\*.*?\*/""", RegexOption.DOT_MATCHES_ALL), "")
            .replace(Regex("""//.*"""), "")
    }

    /** Cada `composable(Rotas.X` com o texto até o próximo `composable(`. */
    private fun blocosPorRota(): Map<String, String> {
        val texto = textoDoGrafo()
        val achados = Regex("""composable\(\s*(?:route\s*=\s*)?Rotas\.([A-Z_]+)""").findAll(texto).toList()
        return achados.mapIndexed { i, achado ->
            val fim = achados.getOrNull(i + 1)?.range?.first ?: texto.length
            achado.groupValues[1] to texto.substring(achado.range.first, fim)
        }.toMap()
    }

    private fun valorDaRota(nome: String): String =
        Rotas::class.java.getDeclaredField(nome).apply { isAccessible = true }.get(null) as String

    @Test
    fun `o teste enxerga as rotas do grafo, inclusive as dos contratantes`() {
        val rotas = blocosPorRota().keys

        assertTrue("achou só ${rotas.size} rotas", rotas.size >= 26)
        listOf(
            "FEED", "PERFIL", "EQUIPE", "CADASTRO_ESTABELECIMENTO", "PUBLICAR_VAGA", "MINHAS_VAGAS",
            "CANDIDATOS_DA_VAGA", "TURNO_DO_CONTRATANTE", "DENUNCIA", "EXCLUSAO_DE_CONTA",
        ).forEach { assertTrue("sem a rota $it no grafo", it in rotas) }
    }

    @Test
    fun `toda rota autenticada do grafo fica dentro de RotaProtegida`() {
        val desprotegidas = blocosPorRota()
            .filterKeys { valorDaRota(it) !in rotasAbertas }
            .filterValues { !USO_DA_GUARDA.containsMatchIn(it) }
            .keys

        assertTrue("rotas sem RotaProtegida: $desprotegidas", desprotegidas.isEmpty())
    }

    @Test
    fun `as rotas abertas sao so as do fluxo de entrada e as duas excecoes declaradas`() {
        val abertas = blocosPorRota().filterValues { !USO_DA_GUARDA.containsMatchIn(it) }.keys.map(::valorDaRota).toSet()

        assertEquals(rotasAbertas, abertas)
        assertFalse(Rotas.MINHAS_VAGAS in abertas)
    }
}
