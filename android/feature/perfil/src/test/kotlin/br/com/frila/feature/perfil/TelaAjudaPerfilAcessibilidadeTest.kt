package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão v1cia6Y9 (item 256): a Ajuda anuncia o que cada linha faz. Os textos `SUPORTE_DICA` e `DICA_*` existiam e nunca eram usados: o TalkBack lia só
 * "botão". Agora cada linha leva o seu como `onClickLabel`, o mesmo padrão do `CartaoVaga` ("toque duas vezes para ..."); o iOS usa a dica do suporte
 * (`PerfisDaConta.swift`) e marca termos e privacidade como link.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class TelaAjudaPerfilAcessibilidadeTest {

    @get:Rule
    val rule = createComposeRule()

    private var chamadas = mutableListOf<String>()

    private fun montar() {
        rule.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = {},
                    aoAbrirEmailSuporte = { chamadas += "email" },
                    aoNavegarParaTermos = { chamadas += "termos" },
                    aoNavegarParaPrivacidade = { chamadas += "privacidade" },
                    aoNavegarParaLicencas = { chamadas += "licencas" },
                )
            }
        }
    }

    private fun rotuloDaAcao(titulo: String): String? =
        rule.onNodeWithText(titulo).fetchSemanticsNode().config.getOrNull(SemanticsActions.OnClick)?.label

    @Test
    fun `fale com o suporte anuncia que abre o e-mail`() {
        montar()

        assertEquals(TextosAjudaPerfil.SUPORTE_DICA, rotuloDaAcao(TextosAjudaPerfil.SUPORTE_TITULO))
    }

    @Test
    fun `termos de uso anuncia que abre os termos`() {
        montar()

        assertEquals(TextosAjudaPerfil.DICA_TERMOS, rotuloDaAcao(TextosAjudaPerfil.TERMOS_DE_USO))
    }

    @Test
    fun `politica de privacidade anuncia que abre a politica`() {
        montar()

        assertEquals(TextosAjudaPerfil.DICA_PRIVACIDADE, rotuloDaAcao(TextosAjudaPerfil.POLITICA_PRIVACIDADE))
    }

    @Test
    fun `licencas anuncia que abre as licencas`() {
        montar()

        assertEquals(TextosAjudaPerfil.DICA_LICENCAS, rotuloDaAcao(TextosAjudaPerfil.LICENCAS_TERCEIROS))
    }

    @Test
    fun `cada linha anuncia a sua dica, e nenhuma repete a do vizinho`() {
        montar()

        val rotulos = listOf(
            TextosAjudaPerfil.SUPORTE_TITULO,
            TextosAjudaPerfil.TERMOS_DE_USO,
            TextosAjudaPerfil.POLITICA_PRIVACIDADE,
            TextosAjudaPerfil.LICENCAS_TERCEIROS,
        ).map { rotuloDaAcao(it) }

        assertEquals(4, rotulos.toSet().size)
    }

    @Test
    fun `as linhas seguem sendo botoes e levam ao destino certo`() {
        montar()

        listOf(
            TextosAjudaPerfil.SUPORTE_TITULO to "email",
            TextosAjudaPerfil.TERMOS_DE_USO to "termos",
            TextosAjudaPerfil.POLITICA_PRIVACIDADE to "privacidade",
            TextosAjudaPerfil.LICENCAS_TERCEIROS to "licencas",
        ).forEach { (titulo, destino) ->
            val papel = rule.onNodeWithText(titulo).fetchSemanticsNode().config.getOrNull(SemanticsProperties.Role)
            assertNotNull("$titulo tem papel", papel)
            rule.onNodeWithText(titulo).performClick()
            assertEquals("$titulo vai a $destino", destino, chamadas.last())
        }
    }
}
