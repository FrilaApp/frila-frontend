package br.com.frila.feature.turnos

import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.MotivoCancelamento
import java.time.Instant
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DialogoCancelamentoTurnoTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `dialogo com falta mostra aviso e controles com alvo minimo`() {
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(motivo = MotivoCancelamento.SAUDE, contaComoFalta = true),
                    aoSelecionarMotivo = {},
                    aoAtualizarDetalhes = {},
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText(
            "Faltam menos de 24 horas. Este cancelamento conta como falta e pode afetar sua reputação.",
        ).assertIsDisplayed()
        compose.onNodeWithText("Problema de saúde")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado"))
        compose.onNodeWithText("Confirmar cancelamento")
            .assertHasClickAction()
            .assertIsEnabled()
            .assertHeightIsAtLeast(48.dp)
        compose.onNodeWithText("Voltar")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
    }

    @Test
    fun `outro motivo exibe campo de detalhes e aviso sem falta`() {
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(
                        motivo = MotivoCancelamento.OUTRO,
                        contaComoFalta = false,
                        detalhes = "Motivo detalhado",
                    ),
                    aoSelecionarMotivo = {},
                    aoAtualizarDetalhes = {},
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Este cancelamento não conta como falta nem afeta sua reputação.")
            .assertIsDisplayed()
        compose.onNodeWithText("Descreva o motivo").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Outro motivo")
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
    }

    private fun estado(
        motivo: MotivoCancelamento,
        contaComoFalta: Boolean,
        detalhes: String = "",
    ) = EstadoCancelamentoTurno(
        turno = ItemTurno(
            turnoId = "t1",
            posicaoId = "p1",
            inicio = Instant.parse("2026-11-01T21:00:00Z"),
            funcaoNome = "Garçom",
            estabelecimentoNome = "Bar do Zé",
            dataHorarioFormatado = "01/11 18:00",
            valorFormatado = "R$ 160,00",
            estado = "confirmada",
        ),
        contaComoFalta = contaComoFalta,
        motivoSelecionado = motivo,
        detalhes = detalhes,
    )
}
