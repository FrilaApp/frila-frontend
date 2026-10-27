package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DialogoComprovanteCheckinTest {

    @get:Rule
    val compose = createComposeRule()

    private val comprovanteGeolocalizado = ComprovanteCheckin(
        turnoId = "turno-xyz-789",
        registradoEm = Instant.parse("2026-10-27T18:30:00Z"),
        tipoVerificacao = TipoVerificacaoCheckin.GEOLOCALIZADO,
        codigoAutenticacao = "CHK-ABC12345",
        coordenadasAproximadas = "-15.794, -47.882",
    )

    @Test
    fun `dialogo exibe codigo verificador, status, coordenadas e botoes com alvo minimo`() {
        compose.setContent {
            FrilaTheme {
                DialogoComprovanteCheckin(
                    comprovante = comprovanteGeolocalizado,
                    aoFechar = {},
                )
            }
        }

        compose.onNodeWithText("Comprovante de presença").assertIsDisplayed()
        compose.onNodeWithText("CHK-ABC12345").assertIsDisplayed()
        compose.onNodeWithText("Geolocalizado na vaga").assertIsDisplayed()
        compose.onNodeWithText("-15.794, -47.882").performScrollTo().assertIsDisplayed()

        compose.onNodeWithText("Compartilhar comprovante")
            .assertIsDisplayed()
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)

        compose.onNodeWithText("Fechar")
            .assertIsDisplayed()
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
    }

    @Test
    fun `clique em compartilhar invoca callback com conteudo formatado`() {
        var textoCompartilhado: String? = null

        compose.setContent {
            FrilaTheme {
                DialogoComprovanteCheckin(
                    comprovante = comprovanteGeolocalizado,
                    aoFechar = {},
                    aoCompartilharPersonalizado = { textoCompartilhado = it },
                )
            }
        }

        compose.onNodeWithText("Compartilhar comprovante").performClick()

        assertTrue(textoCompartilhado != null)
        assertTrue(textoCompartilhado!!.contains("CHK-ABC12345"))
        assertTrue(textoCompartilhado!!.contains("Geolocalizado na vaga"))
        assertTrue(textoCompartilhado!!.contains("-15.794, -47.882"))
    }

    @Test
    fun `clique em fechar invoca callback aoFechar`() {
        var fechou = false

        compose.setContent {
            FrilaTheme {
                DialogoComprovanteCheckin(
                    comprovante = comprovanteGeolocalizado,
                    aoFechar = { fechou = true },
                )
            }
        }

        compose.onNodeWithText("Fechar").performClick()

        assertEquals(true, fechou)
    }
}
