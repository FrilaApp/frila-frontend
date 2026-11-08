package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.Instant
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes do modal de cancelamento de turno com a regra RN12 (Cartão 67).
 *
 * Valida que o diálogo apresenta os textos e alertas da regra de antecedência de 24 horas,
 * mantém os alvos mínimos acessíveis (48dp), permite confirmação direta e omite qualquer
 * campo de motivo, conforme especificação do contrato Android (decisão de 02/10/2026).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DialogoCancelamentoTurnoTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `dialogo com falta mostra aviso de 24 horas e controles com alvo minimo sem campo de motivo`() {
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(contaComoFalta = true),
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }

        // Alerta de falta e reputação da regra RN12
        compose.onNodeWithText(
            "Faltam menos de 24 horas. Este cancelamento conta como falta e pode afetar sua reputação.",
        ).assertIsDisplayed()

        // Controles de ação com alvo mínimo de 48dp
        compose.onNodeWithText("Confirmar cancelamento")
            .assertHasClickAction()
            .assertIsEnabled()
            .assertHeightIsAtLeast(48.dp)

        compose.onNodeWithText("Voltar")
            .assertHasClickAction()
            .assertIsEnabled()
            .assertHeightIsAtLeast(48.dp)

        // Campo de motivo NÃO entra (decisão de contrato Android 02/10/2026)
        compose.onNodeWithText("Qual é o motivo?").assertDoesNotExist()
        compose.onNodeWithText("Descreva o motivo").assertDoesNotExist()
        compose.onNodeWithText("Problema de saúde").assertDoesNotExist()
        compose.onNodeWithText("Outro motivo").assertDoesNotExist()
    }

    @Test
    fun `dialogo sem falta mostra aviso sem penalidade e confirmacao habilitada`() {
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(contaComoFalta = false),
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Este cancelamento não conta como falta nem afeta sua reputação.")
            .assertIsDisplayed()

        compose.onNodeWithText("Confirmar cancelamento")
            .assertHasClickAction()
            .assertIsEnabled()
            .assertHeightIsAtLeast(48.dp)

        // Confirmação de ausência de campos de motivo
        compose.onNodeWithText("Qual é o motivo?").assertDoesNotExist()
        compose.onNodeWithText("Descreva o motivo").assertDoesNotExist()
    }

    @Test
    fun `tocar em confirmar cancelamento invoca callback aoConfirmar`() {
        var confirmou = false
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(contaComoFalta = true),
                    aoConfirmar = { confirmou = true },
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Confirmar cancelamento").performClick()
        assertTrue("aoConfirmar deve ser acionado", confirmou)
    }

    @Test
    fun `tocar em voltar invoca callback aoVoltar`() {
        var voltou = false
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(contaComoFalta = true),
                    aoConfirmar = {},
                    aoVoltar = { voltou = true },
                )
            }
        }

        compose.onNodeWithText("Voltar").performClick()
        assertTrue("aoVoltar deve ser acionado", voltou)
    }

    @Test
    fun `quando enviando desabilita confirmacao e exibe texto Cancelando`() {
        compose.setContent {
            FrilaTheme {
                DialogoCancelamentoTurno(
                    estado = estado(contaComoFalta = true, enviando = true),
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Cancelando…")
            .assertIsDisplayed()
            .assertIsNotEnabled()

        compose.onNodeWithText("Voltar")
            .assertIsNotEnabled()
    }

    private fun estado(
        contaComoFalta: Boolean,
        enviando: Boolean = false,
        mensagemErro: String? = null,
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
        enviando = enviando,
        mensagemErro = mensagemErro,
    )
}
