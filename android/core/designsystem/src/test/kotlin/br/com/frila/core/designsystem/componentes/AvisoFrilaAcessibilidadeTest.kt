package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão Am0qWwYK (item 265): o que o leitor de tela fala de um [AvisoFrila].
 *
 * Prefixos como o iOS (`AvisoFrila.prefixo`, `Componentes.swift:563-571`; padrão em `iOS/Docs/PadroesDeEstado.md:98`): "Erro: ",
 * "Alerta: " e nada no informativo. O tom SUCESSO, que o iOS não tem, fica como está. Título vazio não deixa ". " solto, e o aviso
 * é um só elemento, como o `.accessibilityElement(children: .combine)` do iOS: a mensagem não é lida duas vezes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AvisoFrilaAcessibilidadeTest {

    @get:Rule
    val rule = createComposeRule()

    private val mensagem = "Mostrando os dados salvos neste aparelho."

    private fun montar(tom: TomAviso, titulo: String? = null, aoDispensar: (() -> Unit)? = null) {
        rule.setContent { FrilaTheme { AvisoFrila(tom = tom, mensagem = mensagem, titulo = titulo, aoDispensar = aoDispensar) } }
    }

    /** Os nós da árvore que o leitor de tela percorre e que carregam a mensagem, como texto ou como descrição. */
    private fun nosQueFalamAMensagem() = rule.onAllNodes(
        SemanticsMatcher("fala a mensagem") { no ->
            no.config.getOrNull(SemanticsProperties.Text)?.any { it.text.contains(mensagem) } == true ||
                no.config.getOrNull(SemanticsProperties.ContentDescription)?.any { it.contains(mensagem) } == true
        },
    ).fetchSemanticsNodes()

    private fun descricaoFalada(): String =
        nosQueFalamAMensagem().mapNotNull { it.config.getOrNull(SemanticsProperties.ContentDescription)?.joinToString() }.single()

    @Test
    fun `alerta fala Alerta, como o iOS`() {
        montar(TomAviso.ALERTA)
        assertEquals("Alerta: $mensagem", descricaoFalada())
    }

    @Test
    fun `informativo fala so a mensagem, sem prefixo, como o iOS`() {
        montar(TomAviso.INFORMATIVO)
        assertEquals(mensagem, descricaoFalada())
    }

    @Test
    fun `erro continua falando Erro`() {
        montar(TomAviso.ERRO)
        assertEquals("Erro: $mensagem", descricaoFalada())
    }

    @Test
    fun `com titulo, o titulo vem antes da mensagem`() {
        montar(TomAviso.ALERTA, titulo = "Modo avião")
        assertEquals("Alerta: Modo avião. $mensagem", descricaoFalada())
    }

    @Test
    fun `titulo vazio nao deixa um ponto solto no texto falado`() {
        montar(TomAviso.ALERTA, titulo = "")
        assertEquals("Alerta: $mensagem", descricaoFalada())
    }

    @Test
    fun `titulo so com espacos tambem nao deixa um ponto solto`() {
        montar(TomAviso.ALERTA, titulo = "   ")
        assertEquals("Alerta: $mensagem", descricaoFalada())
    }

    @Test
    fun `a mensagem e lida uma vez so, num elemento so`() {
        montar(TomAviso.ALERTA, titulo = "Modo avião")
        assertEquals("o leitor de tela acharia a mensagem em mais de um elemento", 1, nosQueFalamAMensagem().size)
    }

    @Test
    fun `o botao de fechar continua sendo um elemento proprio, com a acao`() {
        var dispensado = false
        montar(TomAviso.ALERTA, aoDispensar = { dispensado = true })

        assertEquals(1, nosQueFalamAMensagem().size)
        val fechar = rule.onAllNodes(SemanticsMatcher("Fechar aviso") { no ->
            no.config.getOrNull(SemanticsProperties.ContentDescription)?.contains("Fechar aviso") == true
        }).fetchSemanticsNodes().single()
        assertTrue("o fechar tem a ação de clique", fechar.config.contains(SemanticsActions.OnClick))
        fechar.config[SemanticsActions.OnClick].action!!.invoke()
        assertTrue(dispensado)
    }
}
