package br.com.frila.app.ui

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.espresso.Espresso.closeSoftKeyboard
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.ResultadoCancelamento
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.TelaTurnoDoContratante
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** O campo dentro do AlertDialog usa o Android real; o Robolectric cobre só a ação que o abre. */
@RunWith(AndroidJUnit4::class)
class CancelamentoDaPosicaoInstrumentedTest {
    @get:Rule val compose = createComposeRule()

    @Test fun motivoObrigatorioEDigitadoCancelaAPosicaoEMostraResultado() {
        var recebido: Pair<String, String>? = null
        val vm = AcompanhamentoContratanteViewModel(
            contexto = ContextoDoTurnoContratante("turno", "Função sintética", "Casa sintética", null,
                Instant.EPOCH.plusSeconds(3600), null, null, null, null, null, false, "posicao", "confirmada"),
            confirmar = { error("não confirma presença") },
            relogio = { Instant.EPOCH },
            cancelar = { id, motivo ->
                recebido = id to motivo
                ResultadoCancelamento(id, false, true)
            },
        )
        compose.setContent { FrilaTheme { TelaTurnoDoContratante(vm, {}) } }
        compose.onNodeWithText("Cancelar posição").performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        compose.onNodeWithText("Confirmar cancelamento")
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        compose.onNodeWithText("Informe um motivo com pelo menos 3 caracteres.").assertIsDisplayed()
        compose.runOnIdle { assertNull(recebido) }
        compose.onNodeWithText("Motivo").performTextInput("Imprevisto")
        closeSoftKeyboard()
        compose.onNodeWithText("Confirmar cancelamento").performClick()
        compose.runOnIdle { assertEquals("posicao" to "Imprevisto", recebido) }
        compose.onNodeWithText("Posição cancelada. A vaga voltou a procurar profissional.")
            .performScrollTo().assertIsDisplayed()
    }
}
