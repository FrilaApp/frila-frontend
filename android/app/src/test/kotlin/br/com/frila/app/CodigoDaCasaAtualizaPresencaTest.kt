package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CodigoDeCheckinDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.AvisoDaConfirmacao
import br.com.frila.feature.turnos.contratante.CodigoDaCasaViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.PresencaDoTurno
import br.com.frila.feature.turnos.contratante.TextosTurnoDoContratante
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Regressão do #897: o painel relido atualiza o acompanhamento já criado pelo Koin. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class CodigoDaCasaAtualizaPresencaTest {
    @get:Rule(order = 0) val registraActivity = RegistraActivityDeTeste()
    @get:Rule(order = 1) val rule = createComposeRule()

    private var verificado = false
    private var leituras = 0
    private var criacoes = 0
    private var codigosCriados = 0
    private val confirmados = mutableListOf<String>()
    private lateinit var acompanhamento: AcompanhamentoContratanteViewModel
    private lateinit var codigo: CodigoDaCasaViewModel
    private val registro = ResultadoRegistroDto("t1", "manual", "verificado", "2026-11-17T10:00:00Z")

    private fun painel(verificado: Boolean = this.verificado) = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(
                    PosicaoNoPainelDto(
                        id = "p1", estado = "confirmada", turnoId = "t1", verificacao = if (verificado) "verificado" else "pendente", emAtraso = false,
                        checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual",
                        profissional = PerfilPublicoDto("pr1", "profissional", "Ana", reputacao = ReputacaoDto(1, 1, null, 1, 1)),
                    ),
                ),
            ),
        ),
    )

    private fun montar(
        habilitada: Boolean = true,
        lerPainel: suspend (Int) -> PainelDto = { painel() },
        confirmar: suspend (String) -> Result<ResultadoRegistroDto> = { error("não confirmar manualmente") },
    ) {
        val modulo = module {
            viewModel { (contexto: ContextoDoTurnoContratante) ->
                criacoes++
                AcompanhamentoContratanteViewModel(contexto, confirmar = { id ->
                    confirmados += id
                    confirmar(id)
                }).also { acompanhamento = it }
            }
            // L2-8: com a presença verificada o turno da casa mostra "Incluir na equipe"; este teste não olha para ele.
            viewModel { (estabelecimentoId: String, profissionalId: String) ->
                IncluirNaEquipeViewModel(estabelecimentoId, profissionalId, listar = { emptyList() }, incluirMembro = { _, _ -> error("não inclui") })
            }
            viewModel { (id: String, aoConfirmar: (() -> Unit)?) ->
                codigosCriados++
                CodigoDaCasaViewModel(id, gerar = {
                    if (verificado) Result.failure(ErroDaApi(CodigoErroAPI.CHECKIN_JA_CONFIRMADO, "checkin_ja_confirmado", null, "já confirmado"))
                    else Result.success(CodigoDeCheckinDto(id, "123456", "2026-11-17T23:00:00Z", 300))
                }, aoConfirmar = aoConfirmar).also { codigo = it }
            }
        }
        rule.setContent {
            KoinApplication(application = { modules(modulo) }) {
                RotaTurnoDoContratante(
                    estabelecimentoId = "est-1", vagaId = "v1", posicaoId = "p1",
                    buscarPainel = { _, _, _ -> leituras++; Result.success(lerPainel(leituras)) },
                    aoVoltar = {}, checkinPorCodigoHabilitado = habilitada,
                )
            }
        }
        rule.waitUntil(5_000) { leituras >= 1 && criacoes >= 1 }
        rule.waitForIdle()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertExists()
    }

    private fun validarPeloCodigo() {
        rule.runOnIdle {
            verificado = true
            runBlocking { codigo.verificarConfirmacao() }
        }
        rule.waitUntil(5_000) { leituras >= 2 }
        rule.waitForIdle()
    }

    private fun conferirPresencaVerificada() {
        assertTrue("painel relido", leituras >= 2)
        assertEquals("a tela precisa incorporar o painel relido", PresencaDoTurno.VERIFICADA, acompanhamento.estado.value.presenca)
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertExists()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertDoesNotExist()
        assertEquals("o acompanhamento existente recebe a atualização", 1, criacoes)
    }

    @Test
    fun confirmarPeloCodigoAtualizaAPresencaNaTelaDaCasa() {
        montar()
        validarPeloCodigo()
        conferirPresencaVerificada()
        assertTrue(confirmados.isEmpty())
    }

    @Test
    fun releituraDuranteAConfirmacaoManualPreservaAAcaoEmVoo() {
        val resposta = CompletableDeferred<ResultadoRegistroDto>()
        montar(confirmar = { Result.success(resposta.await()) })
        lateinit var envio: Job
        rule.runOnIdle { envio = acompanhamento.confirmarPresenca() }
        rule.waitForIdle()
        assertTrue(acompanhamento.estado.value.enviando)
        assertEquals(listOf("t1"), confirmados)

        validarPeloCodigo()
        conferirPresencaVerificada()
        assertTrue("a releitura não libera um segundo envio", acompanhamento.estado.value.enviando)
        assertTrue("a confirmação original continua em voo", envio.isActive)
        rule.runOnIdle { acompanhamento.confirmarPresenca() }
        assertEquals(listOf("t1"), confirmados)

        rule.runOnIdle { resposta.complete(registro) }
        rule.waitForIdle()
        assertTrue(envio.isCompleted)
        assertFalse(acompanhamento.estado.value.enviando)
        assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, acompanhamento.estado.value.aviso)
        conferirPresencaVerificada()
    }

    @Test
    fun chaveDesligadaMantemAConfirmacaoManualSemCriarCodigo() {
        montar(habilitada = false, confirmar = { Result.success(registro) })
        assertEquals(0, codigosCriados)
        assertEquals(PresencaDoTurno.CHECKIN_MANUAL_PENDENTE, acompanhamento.estado.value.presenca)
        rule.runOnIdle { acompanhamento.confirmarPresenca() }
        rule.waitForIdle()
        assertEquals(listOf("t1"), confirmados)
        assertEquals(PresencaDoTurno.VERIFICADA, acompanhamento.estado.value.presenca)
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertExists()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertDoesNotExist()
        assertEquals(1, leituras)
        assertEquals(1, criacoes)
    }

    @Test
    fun releituraAtrasadaNaoDesfazAConfirmacaoManual() {
        val resposta = CompletableDeferred<ResultadoRegistroDto>()
        val liberarPainelAntigo = CompletableDeferred<Unit>()
        val liberarNovasLeituras = CompletableDeferred<Unit>()
        montar(
            lerPainel = { leitura ->
                // A segunda leitura captura o painel antes de a confirmação manual gravar.
                val snapshot = painel(verificado = leitura != 2 && verificado)
                withTimeout(10_000) {
                    if (leitura == 2) liberarPainelAntigo.await()
                    if (leitura >= 3) liberarNovasLeituras.await()
                }
                snapshot
            },
            confirmar = { Result.success(resposta.await()) },
        )
        try {
            rule.runOnIdle { acompanhamento.confirmarPresenca() }
            rule.waitForIdle()
            assertTrue(acompanhamento.estado.value.enviando)
            rule.runOnIdle {
                verificado = true
                runBlocking { codigo.verificarConfirmacao() }
            }
            rule.waitUntil(5_000) { leituras == 2 }
            rule.runOnIdle { resposta.complete(registro) }
            rule.waitForIdle()
            assertEquals(PresencaDoTurno.VERIFICADA, acompanhamento.estado.value.presenca)
            assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, acompanhamento.estado.value.aviso)

            rule.runOnIdle { liberarPainelAntigo.complete(Unit) }
            rule.waitForIdle()
            assertEquals("o painel antigo não desfaz a confirmação", PresencaDoTurno.VERIFICADA, acompanhamento.estado.value.presenca)
            assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, acompanhamento.estado.value.aviso)
            assertFalse(acompanhamento.estado.value.podeConfirmar)
            rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertExists()
            rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertDoesNotExist()
            assertEquals(listOf("t1"), confirmados)
            assertEquals(1, criacoes)
        } finally {
            rule.runOnIdle { liberarNovasLeituras.complete(Unit) }
        }
    }

}
