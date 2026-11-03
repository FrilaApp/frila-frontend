package br.com.frila.feature.turnos

import android.provider.Settings
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class FeedbackAcaoCriticaTest {
    @get:Rule val compose = createComposeRule()
    private val chamadas = mutableListOf<HapticFeedbackType>()
    private val feedback = object : HapticFeedback {
        override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) {
            chamadas += hapticFeedbackType
        }
    }
    private val agora = Instant.parse("2026-11-01T12:00:00Z")
    private val turno = ItemTurno(
        turnoId = "turno-teste", posicaoId = "posicao-teste", inicio = agora,
        fim = agora.plusSeconds(3600), funcaoNome = "Atendimento",
        estabelecimentoNome = "Local sintético", dataHorarioFormatado = "01/11 09:00",
        valorFormatado = "R$ 120,00", estado = "confirmada",
    )

    @Test fun `checkin chama fake uma vez e mostra feedback visual`() {
        val estadoCheckin = MutableStateFlow(EstadoCheckin())
        val checkin = mockk<CheckinViewModel>(relaxed = true)
        every { checkin.estado } returns estadoCheckin
        every { checkin.fazerCheckin() } answers {
            estadoCheckin.value = EstadoCheckin(status = StatusCheckin.REGISTRANDO)
            Job().apply { complete() }
        }
        val meusTurnos = mockk<MeusTurnosViewModel>(relaxed = true)
        every { meusTurnos.estado } returns MutableStateFlow(
            EstadoMeusTurnos(status = StatusMeusTurnos.SUCESSO, agendados = listOf(turno)),
        )
        compose.setContent {
            Settings.System.putInt(LocalContext.current.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
            CompositionLocalProvider(LocalHapticFeedback provides feedback) {
                FrilaTheme { TelaMeusTurnos(meusTurnos, { checkin }, relogio = { agora }) }
            }
        }
        compose.onNodeWithText("Fazer check-in").performClick()
        compose.onNodeWithText("Registrando check-in…").assertIsDisplayed()
        compose.runOnIdle { assertEquals(listOf(HapticFeedbackType.LongPress), chamadas) }
        verify(exactly = 1) { checkin.fazerCheckin() }
    }

    @Test fun `confirmar cancelamento chama fake e preserva progresso visual`() {
        val estado = mutableStateOf(EstadoCancelamentoTurno(turno, contaComoFalta = false))
        var confirmacoes = 0
        compose.setContent {
            Settings.System.putInt(LocalContext.current.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
            CompositionLocalProvider(LocalHapticFeedback provides feedback) {
                FrilaTheme {
                    DialogoCancelamentoTurno(
                        estado = estado.value,
                        aoConfirmar = {
                            confirmacoes++
                            estado.value = estado.value.copy(enviando = true)
                        },
                        aoVoltar = {},
                    )
                }
            }
        }
        compose.onNodeWithText("Confirmar cancelamento").performClick()
        compose.onNodeWithText("Cancelando…").assertIsDisplayed().assertIsNotEnabled()
        compose.runOnIdle {
            assertEquals(1, confirmacoes)
            assertEquals(listOf(HapticFeedbackType.LongPress), chamadas)
        }
    }

    @Test fun `desativar vibracao com tela aberta impede chamada sem bloquear acao`() {
        var confirmacoes = 0
        lateinit var desativar: () -> Unit
        compose.setContent {
            val resolver = LocalContext.current.contentResolver
            Settings.System.putInt(resolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
            desativar = { Settings.System.putInt(resolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 0) }
            CompositionLocalProvider(LocalHapticFeedback provides feedback) {
                FrilaTheme {
                    DialogoCancelamentoTurno(
                        estado = EstadoCancelamentoTurno(turno, contaComoFalta = false),
                        aoConfirmar = { confirmacoes++ },
                        aoVoltar = {},
                    )
                }
            }
        }
        compose.runOnIdle { desativar() }
        compose.onNodeWithText("Confirmar cancelamento").performClick()
        compose.runOnIdle {
            assertEquals(1, confirmacoes)
            assertEquals(emptyList<HapticFeedbackType>(), chamadas)
        }
    }

    @Test fun `fake sem haptico nao impede cancelamento`() {
        var confirmacoes = 0
        val semHaptico = object : HapticFeedback {
            override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) = Unit
        }
        compose.setContent {
            Settings.System.putInt(LocalContext.current.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
            CompositionLocalProvider(LocalHapticFeedback provides semHaptico) {
                FrilaTheme {
                    DialogoCancelamentoTurno(
                        estado = EstadoCancelamentoTurno(turno, contaComoFalta = false),
                        aoConfirmar = { confirmacoes++ },
                        aoVoltar = {},
                    )
                }
            }
        }
        compose.onNodeWithText("Confirmar cancelamento").performClick()
        compose.runOnIdle { assertEquals(1, confirmacoes) }
    }

    @Test fun `cancelamento enviando nao aciona haptico nem callback`() {
        var confirmacoes = 0
        compose.setContent {
            Settings.System.putInt(LocalContext.current.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1)
            CompositionLocalProvider(LocalHapticFeedback provides feedback) {
                FrilaTheme {
                    DialogoCancelamentoTurno(
                        estado = EstadoCancelamentoTurno(turno, contaComoFalta = false, enviando = true),
                        aoConfirmar = { confirmacoes++ },
                        aoVoltar = {},
                    )
                }
            }
        }
        compose.onNodeWithText("Cancelando…").assertIsNotEnabled().performClick()
        compose.runOnIdle {
            assertEquals(0, confirmacoes)
            assertEquals(emptyList<HapticFeedbackType>(), chamadas)
        }
    }
}
