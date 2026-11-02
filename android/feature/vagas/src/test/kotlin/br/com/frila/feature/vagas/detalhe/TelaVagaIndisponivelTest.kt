package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.EstadoCandidatura
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaVagaIndisponivelTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tituloPossuiSemanticaDeCabecalhoEAlvoMinimoNoBotaoVoltar() {
        var voltou = false

        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                    aoVoltarParaFeed = { voltou = true },
                )
            }
        }

        // Título da barra
        rule.onNodeWithText("Vaga").assertIsDisplayed()

        // Cabeçalho do conteúdo
        rule.onNodeWithText("Vaga preenchida")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        // Botão voltar na barra com alvo >= 48dp
        val botaoVoltar = rule.onNodeWithContentDescription("Voltar")
        botaoVoltar
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)

        botaoVoltar.performClick()
        assertTrue("Callback aoVoltarParaFeed deve ser disparado", voltou)
    }

    @Test
    fun exibeTextosAdequadosParaVagaPreenchidaUrgencia() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                    modo = ModoPreenchimentoVaga.URGENCIA,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("Vaga preenchida").assertIsDisplayed()
        rule.onNodeWithText(
            "Esta posição acabou de ser preenchida por outro profissional. No modo urgência, quem confirma primeiro fica com a vaga.",
        ).assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaVagaPreenchidaSelecao() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                    modo = ModoPreenchimentoVaga.SELECAO,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("Vaga preenchida").assertIsDisplayed()
        rule.onNodeWithText("O estabelecimento já escolheu quem vai trabalhar nesta vaga.")
            .assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaCandidaturaRecusada() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                    candidatura = EstadoCandidatura.RECUSADA,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("O estabelecimento escolheu outra pessoa").assertIsDisplayed()
        rule.onNodeWithText("A vaga foi preenchida, e a sua candidatura não foi escolhida.")
            .assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaVagaCanceladaComCandidatura() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.ENCERRADA,
                    candidatura = EstadoCandidatura.PENDENTE,
                    vagaCancelada = true,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("O estabelecimento cancelou esta vaga").assertIsDisplayed()
        rule.onNodeWithText("A sua candidatura foi encerrada junto com a vaga.")
            .assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaCandidaturaExpirada() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.ENCERRADA,
                    candidaturaExpirada = true,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("A seleção desta vaga foi encerrada").assertIsDisplayed()
        rule.onNodeWithText("A vaga fechou sem que a sua candidatura fosse escolhida.")
            .assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaVagaEncerrada() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.ENCERRADA,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("Vaga encerrada").assertIsDisplayed()
        rule.onNodeWithText("Esta vaga foi encerrada, cancelada ou o horário de início já passou.")
            .assertIsDisplayed()
    }

    @Test
    fun exibeTextosAdequadosParaVagaNaoEncontrada() {
        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.NAO_ENCONTRADA,
                    aoVoltarParaFeed = {},
                )
            }
        }

        rule.onNodeWithText("Vaga encerrada").assertIsDisplayed()
        rule.onNodeWithText("Esta vaga não está mais disponível. Volte para a lista e escolha outra.")
            .assertIsDisplayed()
    }

    @Test
    fun botaoVoltarParaFeedPossuiAlvoMinimoEAcionaCallback() {
        var clicouVoltarFeed = false

        rule.setContent {
            FrilaTheme {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                    aoVoltarParaFeed = { clicouVoltarFeed = true },
                    rotuloBotaoVoltar = "Ver minhas candidaturas",
                )
            }
        }

        val botao = rule.onNodeWithText("Ver minhas candidaturas")
        botao.assertIsDisplayed()
        botao.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        botao.performClick()
        assertTrue("Callback deve ser executado no clique do botão", clicouVoltarFeed)
    }
}
