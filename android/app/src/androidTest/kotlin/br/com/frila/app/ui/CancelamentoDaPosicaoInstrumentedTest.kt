package br.com.frila.app.ui

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
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

/**
 * A folha de motivos da casa (Vmfnk4gQ) com o Android real: o campo do detalhe e o teclado. O Robolectric cobre a ação que abre a folha e a
 * lógica dos motivos; aqui o texto digitado de verdade chega ao `cancelar_posicao`.
 */
@RunWith(AndroidJUnit4::class)
class CancelamentoDaPosicaoInstrumentedTest {
    @get:Rule val compose = createComposeRule()

    private class Cancelamentos {
        var recebido: Pair<String, String>? = null
    }

    private fun montar(cancelamentos: Cancelamentos) {
        val vm = AcompanhamentoContratanteViewModel(
            contexto = ContextoDoTurnoContratante("turno", "Função sintética", "Casa sintética", null,
                Instant.EPOCH.plusSeconds(3600), null, null, null, null, null, false, "posicao", "confirmada"),
            confirmar = { error("não confirma presença") },
            relogio = { Instant.EPOCH },
            cancelar = { id, motivo ->
                cancelamentos.recebido = id to motivo
                ResultadoCancelamento(id, false, true)
            },
        )
        compose.setContent { FrilaTheme { TelaTurnoDoContratante(vm, {}) } }
        compose.onNodeWithText("Cancelar posição").performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
    }

    @Test fun outroMotivoExigeODetalheDigitadoCancelaAPosicaoEMostraResultado() {
        val cancelamentos = Cancelamentos()
        montar(cancelamentos)

        // Sem motivo escolhido, e depois com "Outro motivo" ainda sem o detalhe, o confirmar fica travado e nada é enviado.
        compose.onNodeWithText("Confirmar cancelamento").performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).assertIsNotEnabled()
        compose.onNodeWithText("Outro motivo").performScrollTo().performClick()
        compose.onNodeWithText("Descreva o motivo (pelo menos 3 caracteres)").assertIsDisplayed()
        compose.onNodeWithText("Confirmar cancelamento").performScrollTo().assertIsNotEnabled()
        compose.runOnIdle { assertNull(cancelamentos.recebido) }

        compose.onNodeWithText("Descreva o motivo (pelo menos 3 caracteres)").performTextInput("Imprevisto")
        closeSoftKeyboard()
        compose.onNodeWithText("Confirmar cancelamento").performScrollTo().assertIsEnabled().performClick()

        compose.runOnIdle { assertEquals("posicao" to "Imprevisto", cancelamentos.recebido) }
        compose.onNodeWithText("Posição cancelada. A vaga voltou a procurar profissional.")
            .performScrollTo().assertIsDisplayed()
    }

    @Test fun motivoDaListaCancelaAPosicaoComOTextoDoMotivoEMostraResultado() {
        val cancelamentos = Cancelamentos()
        montar(cancelamentos)

        compose.onNodeWithText("Movimento menor que o esperado").performScrollTo().performClick()
        compose.onNodeWithText("Confirmar cancelamento").performScrollTo().assertIsEnabled().performClick()

        compose.runOnIdle { assertEquals("posicao" to "Movimento menor que o esperado", cancelamentos.recebido) }
        compose.onNodeWithText("Posição cancelada. A vaga voltou a procurar profissional.")
            .performScrollTo().assertIsDisplayed()
    }
}
