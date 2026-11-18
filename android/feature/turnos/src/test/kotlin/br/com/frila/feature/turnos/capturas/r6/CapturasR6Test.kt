package br.com.frila.feature.turnos.capturas.r6

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.feature.turnos.contratante.AcoesTurnoDoContratante
import br.com.frila.feature.turnos.contratante.AvisoDaConfirmacao
import br.com.frila.feature.turnos.contratante.AvisoDaReabertura
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.ConteudoDoCartaoDoCodigo
import br.com.frila.feature.turnos.contratante.ConteudoTurnoDoContratante
import br.com.frila.feature.turnos.contratante.EstadoCartaoDoCodigo
import br.com.frila.feature.turnos.contratante.EstadoDoCodigoDaCasa
import br.com.frila.feature.turnos.contratante.EstadoTurnoDoContratante
import java.time.Instant
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R6 no módulo de turnos: o turno visto pela casa (cada etapa da chegada) e o cartão do código de
 * chegada. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR6Test {

    @get:Rule
    val compose = createComposeRule()

    private val ana = PerfilPublicoDto("p1", "profissional", "Ana Souza", listOf("garçom", "barman"), ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8))

    private fun estado(
        verificacao: String? = null,
        checkinTipo: String? = null,
        checkinEm: Instant? = null,
        aCaminhoEm: Instant? = null,
        emAtraso: Boolean = false,
        enviando: Boolean = false,
        aviso: AvisoDaConfirmacao? = null,
        avisoDaReabertura: AvisoDaReabertura? = null,
            ) = EstadoTurnoDoContratante(
        contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "Bar do Zé, SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
            fim = Instant.parse("2026-11-13T01:00:00Z"), profissional = ana, aCaminhoEm = aCaminhoEm, checkinEm = checkinEm,
            checkinTipo = checkinTipo, verificacao = verificacao, emAtraso = emAtraso, posicaoId = "pos1", estadoDaPosicao = "confirmada",
        ),
        enviando = enviando,
        aviso = aviso,
        reaberturaDisponivel = true,
        avisoDaReabertura = avisoDaReabertura,
    )

    @Composable
    private fun Turno(estado: EstadoTurnoDoContratante, codigo: EstadoCartaoDoCodigo? = null) {
        ConteudoTurnoDoContratante(
            estado = estado,
            acoes = AcoesTurnoDoContratante(aoDenunciarProfissional = { _, _ -> }),
            cartaoDoCodigo = codigo?.let { c -> { ConteudoDoCartaoDoCodigo(estado = c, aoTentarDeNovo = {}) } },
        )
    }

    private val checkin = Instant.parse("2026-11-12T21:02:00Z")

    @Test
    fun `turno aguardando o profissional chegar - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Turno(estado()) } }
        compose.capturar("r6-01-turno-aguardando-claro")
    }

    @Test
    fun `turno com o profissional a caminho - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Turno(estado(aCaminhoEm = Instant.parse("2026-11-12T20:40:00Z"))) } }
        compose.capturar("r6-02-turno-a-caminho-claro")
    }

    @Test
    fun `turno em atraso com a reabertura - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Turno(estado(emAtraso = true, avisoDaReabertura = AvisoDaReabertura.ANTES_DA_TOLERANCIA)) } }
        compose.capturar("r6-03-turno-em-atraso-claro")
    }

    @Test
    fun `turno com check-in pendente e o codigo - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Turno(
                    estado(verificacao = "pendente", checkinTipo = "codigo", checkinEm = checkin),
                    EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), segundosRestantes = 272),
                )
            }
        }
        compose.capturar("r6-04-turno-checkin-pendente-codigo-claro")
    }

    @Test
    fun `turno com check-in pendente e erro de confirmacao - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Turno(
                    estado(verificacao = "pendente", checkinTipo = "manual", checkinEm = checkin, aviso = AvisoDaConfirmacao.SEM_REDE),
                    EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin),
                )
            }
        }
        compose.capturar("r6-05-turno-checkin-pendente-erro-claro")
    }

    @Test
    fun `turno com presenca verificada - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Turno(estado(verificacao = "verificado", checkinTipo = "codigo", checkinEm = checkin, aviso = AvisoDaConfirmacao.CONFIRMADA_AGORA))
            }
        }
        compose.capturar("r6-06-turno-presenca-verificada-claro")
    }

    @Test
    fun `cartao do codigo em cada estado - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(FrilaTema.cores.fundo)
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    ConteudoDoCartaoDoCodigo(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Carregando), aoTentarDeNovo = {})
                    ConteudoDoCartaoDoCodigo(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), renovando = true), aoTentarDeNovo = {})
                    ConteudoDoCartaoDoCodigo(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Falhou), aoTentarDeNovo = {})
                    ConteudoDoCartaoDoCodigo(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Encerrado), aoTentarDeNovo = {})
                }
            }
        }
        compose.capturar("r6-08-cartao-do-codigo-estados-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `turno com check-in pendente e o codigo - fonte do sistema em 200 por cento`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Turno(
                    estado(verificacao = "pendente", checkinTipo = "codigo", checkinEm = checkin),
                    EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), segundosRestantes = 272),
                )
            }
        }
        compose.capturar("r6-09-turno-checkin-pendente-fonte-200")
    }
}
