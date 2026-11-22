package br.com.frila.feature.vagas.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.feature.vagas.detalhe.TelaConflitoHorario
import br.com.frila.feature.vagas.detalhe.TelaTurnoConfirmado
import br.com.frila.feature.vagas.detalhe.TelaVagaIndisponivel
import br.com.frila.feature.vagas.detalhe.MotivoIndisponibilidadeVaga
import br.com.frila.feature.vagas.detalhe.ModoPreenchimentoVaga
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasParidadeLoteAVagasTest {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        val densidadeAtual = LocalDensity.current
        CompositionLocalProvider(
            LocalDensity provides Density(densidadeAtual.density, fontScale = escala),
            content = conteudo,
        )
    }

    private val vagaDeExemplo = VagaAbertaDto(
        id = "vaga-lote-a-1",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
        estabelecimento = PerfilPublicoDto(
            id = "est-1",
            tipo = "estabelecimento",
            nome = "Restaurante Panelinha",
            reputacao = ReputacaoDto(30, 28, null, 28, 28),
        ),
        inicioEm = "2026-11-21T18:00:00Z",
        fimEm = "2026-11-22T00:00:00Z",
        local = "CLN 402 Bloco B",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 2.5,
        valorCentavos = 18000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    @Test
    fun capturaItem6TurnoConfirmadoPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    TelaTurnoConfirmado(
                        vaga = vagaDeExemplo,
                        quemRecebe = "Carlos Silva",
                        aoVerMeusTurnos = {},
                        aoVoltarAoFeed = {},
                    )
                }
            },
        )
        compose.capturar("01-item6-turno-confirmado-padrao")
    }

    @Test
    fun capturaItem6TurnoConfirmadoFonteGrande() {
        compose.setContent(
            comFonte(1.5f) {
                FrilaTheme(temaEscuro = false) {
                    TelaTurnoConfirmado(
                        vaga = vagaDeExemplo,
                        quemRecebe = "Carlos Silva",
                        aoVerMeusTurnos = {},
                        aoVoltarAoFeed = {},
                    )
                }
            },
        )
        compose.capturar("02-item6-turno-confirmado-fonte-grande")
    }

    @Test
    fun capturaItem9ConflitoHorarioPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    TelaConflitoHorario(
                        vaga = vagaDeExemplo,
                        aoVoltarAoFeed = {},
                    )
                }
            },
        )
        compose.capturar("03-item9-conflito-horario-padrao")
    }

    @Test
    fun capturaItem9ConflitoHorarioFonteGrande() {
        compose.setContent(
            comFonte(1.5f) {
                FrilaTheme(temaEscuro = false) {
                    TelaConflitoHorario(
                        vaga = vagaDeExemplo,
                        aoVoltarAoFeed = {},
                    )
                }
            },
        )
        compose.capturar("04-item9-conflito-horario-fonte-grande")
    }

    @Test
    fun capturaItem7VagaPreenchidaPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                        modo = ModoPreenchimentoVaga.URGENCIA,
                        aoVoltarParaFeed = {},
                    )
                }
            },
        )
        compose.capturar("05-item7-vaga-preenchida-padrao")
    }

    @Test
    fun capturaItem8VagaEncerradaPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.ENCERRADA,
                        aoVoltarParaFeed = {},
                    )
                }
            },
        )
        compose.capturar("06-item8-vaga-encerrada-padrao")
    }
}
