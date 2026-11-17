package br.com.frila.app

import android.app.Application
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.CodigoDeCheckinDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.turnos.LocalCriarValidacaoDoCodigo
import br.com.frila.feature.turnos.ValidacaoDoCodigoViewModel
import br.com.frila.feature.turnos.contratante.CodigoDaCasaViewModel
import io.mockk.every
import io.mockk.mockk
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** L1-7b: a fiação do código de chegada, atrás da chave `checkin_por_codigo` (a do servidor, `configuracao_do_app`). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class FiacaoDoCodigoDeChegadaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val ponto = Coordenada(-15.7942, -47.8825)
    private val recebidos = mutableListOf<Pair<String, Coordenada?>>()
    private val recebidosDaCasa = mutableListOf<String>()

    private val registro = ResultadoRegistroDto(
        turnoId = "t1", tipo = "codigo", verificacao = "verificado", registradoEm = "2026-11-17T10:00:00Z", distanciaM = 10,
    )

    private val modulo = module {
        viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?, aoPresencaVerificada: (() -> Unit)?) ->
            recebidos += turnoId to coordenadaDaVaga
            ValidacaoDoCodigoViewModel(
                turnoId = turnoId,
                validar = { _, _, _ -> Result.success(registro) },
                medirDistancia = { 10 },
                aoPresencaVerificada = aoPresencaVerificada,
                escopo = CoroutineScope(Dispatchers.Unconfined),
            )
        }
        viewModel { (turnoId: String, aoConfirmar: (() -> Unit)?) ->
            recebidosDaCasa += turnoId
            CodigoDaCasaViewModel(turnoId = turnoId, gerar = { Result.success(mockk<CodigoDeCheckinDto>(relaxed = true)) }, aoConfirmar = aoConfirmar)
        }
    }

    private fun turno() = mockk<ItemTurno>(relaxed = true) {
        every { turnoId } returns "t1"
        every { pontoDaVaga } returns ponto
    }

    private fun comKoin(conteudo: @Composable () -> Unit) {
        rule.setContent { KoinApplication(application = { modules(modulo) }) { conteudo() } }
    }

    @Test
    fun comAChaveDesligadaATelaNaoRecebeOCampoDoCodigo() {
        var criador: Any? = "ainda nao lido"
        comKoin { ComConfirmacaoPorCodigo(habilitada = false, aoPresencaVerificada = {}) { criador = LocalCriarValidacaoDoCodigo.current } }
        rule.waitForIdle()
        assertNull(criador)
    }

    @Test
    fun comAChaveLigadaATelaCriaOViewModelDoTurnoComOPontoDaVagaEReleOTurnoAoVerificar() {
        var reler = 0
        var viewModel: ValidacaoDoCodigoViewModel? = null
        comKoin {
            ComConfirmacaoPorCodigo(habilitada = true, aoPresencaVerificada = { reler++ }) {
                val criar = LocalCriarValidacaoDoCodigo.current
                if (criar != null && viewModel == null) viewModel = criar(turno())
            }
        }
        rule.waitForIdle()
        assertNotNull(viewModel)
        assertEquals(listOf("t1" to ponto), recebidos)
        viewModel!!.validar("123456")
        rule.waitForIdle()
        assertEquals(1, reler)
    }

    @Test
    fun ocodigoDaCasaSoExisteComAChaveLigada() {
        var desligado: CodigoDaCasaViewModel? = null
        var ligado: CodigoDaCasaViewModel? = null
        comKoin {
            desligado = codigoDaCasaDoTurno(habilitado = false, turnoId = "t1", aoConfirmar = {})
            ligado = codigoDaCasaDoTurno(habilitado = true, turnoId = "t1", aoConfirmar = {})
        }
        rule.waitForIdle()
        assertNull(desligado)
        assertNotNull(ligado)
        assertEquals(listOf("t1"), recebidosDaCasa)
    }

    @Test
    fun todasAsChamadasDaTelaMeusTurnosNoAppNavegacaoPassamPelaFiacao() {
        val fonte = File("src/main/kotlin/br/com/frila/app/AppNavegacao.kt").readText()
        val telas = Regex("""\bTelaMeusTurnos\(""").findAll(fonte).count()
        val fiacoes = Regex("""\bComConfirmacaoPorCodigo\(""").findAll(fonte).count()
        assertTrue("esperava as 3 chamadas de TelaMeusTurnos, achei $telas", telas >= 3)
        assertEquals("cada TelaMeusTurnos tem de estar dentro de ComConfirmacaoPorCodigo", telas, fiacoes)
        assertTrue(
            "a chave checkin_por_codigo tem de ir da MainActivity ao AppNavegacao",
            "checkinPorCodigoHabilitado" in fonte && "checkinPorCodigoHabilitado" in File("src/main/kotlin/br/com/frila/app/MainActivity.kt").readText(),
        )
    }
}
