package br.com.frila.feature.conta

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ExclusaoDeContaDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelasContaTest {

    @get:Rule
    val rule = createComposeRule()

    /** Estado vive no teste, como o `StateFlow` do ViewModel vive na tela. */
    private fun montarExclusao(
        inicial: EstadoExclusaoDeConta = EstadoExclusaoDeConta(),
        aoExcluir: () -> Unit = {},
        aoVoltar: () -> Unit = {},
    ) {
        rule.setContent {
            var estado by mutableStateOf(inicial)
            FrilaTheme {
                ConteudoExclusaoDeConta(
                    estado = estado,
                    aoAlterarConfirmacao = { estado = estado.copy(confirmouConsequencias = it) },
                    aoExcluir = aoExcluir,
                    aoVoltar = aoVoltar,
                )
            }
        }
    }

    @Test
    fun exclusaoTemTituloComoCabecalhoEExplicaOPrazoDe15DiasDaLgpd() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.TITULO)
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosExclusaoDeConta.CONSEQUENCIA_PRAZO, substring = true).assertIsDisplayed()
        rule.onNodeWithText("15 dias", substring = true).assertIsDisplayed()
        rule.onNodeWithText("30 dias", substring = true).assertDoesNotExist()
    }

    @Test
    fun botaoDeExcluirSoHabilitaDepoisDaCaixaDeConfirmacao() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR)
            .performScrollTo()
            .assertIsNotEnabled()

        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK).performClick()

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR)
            .assertIsEnabled()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun caixaDeConfirmacaoExpoeSemanticaDeCheckbox() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, androidx.compose.ui.semantics.Role.Checkbox))
    }

    @Test
    fun excluirPedeConfirmacaoFinalEOCancelarNaoDisparaOPedido() {
        var pedidos = 0
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true), aoExcluir = { pedidos++ })

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertIsDisplayed()
        assertEquals("clicar em excluir só abre o diálogo", 0, pedidos)

        rule.onNodeWithText(TextosExclusaoDeConta.CANCELAR).performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertDoesNotExist()
        assertEquals(0, pedidos)
    }

    @Test
    fun confirmarNoDialogoDisparaOPedidoUmaVez() {
        var pedidos = 0
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true), aoExcluir = { pedidos++ })

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_CONFIRMAR).performClick()

        assertEquals(1, pedidos)
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertDoesNotExist()
    }

    @Test
    fun excluindoDesabilitaBotaoEVoltarEMostraProgresso() {
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true, excluindo = true))

        rule.onNodeWithText(TextosExclusaoDeConta.EXCLUINDO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithContentDescription(TextosExclusaoDeConta.ROTULO_VOLTAR).assertIsNotEnabled()
    }

    @Test
    fun erroAparecePertoDoBotaoEPermiteTentarDeNovo() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                confirmouConsequencias = true,
                mensagemErro = TextosExclusaoDeConta.ERRO_ADMIN_UNICO,
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.ERRO_ADMIN_UNICO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).assertIsEnabled()
    }

    @Test
    fun exclusaoConcluidaMostraOResumoESomeComOBotao() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                confirmouConsequencias = true,
                resultado = ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 2),
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.CONCLUIDA_TITULO).assertIsDisplayed()
        rule.onNodeWithText("Turnos cancelados: 2", substring = true).assertIsDisplayed()
        rule.onNodeWithText("2026-11-25", substring = true).assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).assertDoesNotExist()
    }

    @Test
    fun voltarNaExclusaoChamaOCallback() {
        var voltou = false
        montarExclusao(aoVoltar = { voltou = true })

        rule.onNodeWithContentDescription(TextosExclusaoDeConta.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertTrue(voltou)
    }

    @Test
    fun contaSuspensaTemCabecalhoAvisoESaidasComAlvoMinimo() {
        var emailPedido: String? = null
        var saiu = false
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = { emailPedido = it },
                    aoSair = { saiu = true },
                )
            }
        }

        rule.onNodeWithText(TextosContaSuspensa.TITULO)
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosContaSuspensa.AVISO_PRINCIPAL).assertIsDisplayed()
        rule.onNodeWithText("suporte@frilabr.com").assertIsDisplayed()

        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SUPORTE)
            .performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        assertEquals("suporte@frilabr.com", emailPedido)

        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SAIR)
            .performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        assertTrue(saiu)
    }

    @Test
    fun contaSuspensaSoMostraMotivoEDataQuandoVierem() {
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = {},
                    aoSair = {},
                )
            }
        }
        rule.onNodeWithText(TextosContaSuspensa.SECAO_MOTIVO).assertDoesNotExist()
    }

    @Test
    fun contaSuspensaMostraMotivoEDataInformados() {
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = {},
                    aoSair = {},
                    motivo = "Denúncia de assédio confirmada",
                    desde = "09/11/2026",
                )
            }
        }

        rule.onNodeWithText(TextosContaSuspensa.SECAO_MOTIVO).assertIsDisplayed()
        rule.onNodeWithText("Denúncia de assédio confirmada").assertIsDisplayed()
        rule.onNodeWithText("09/11/2026").performScrollTo().assertIsDisplayed()
    }

    // ---- 9NpQTfGG: os turnos futuros que a exclusão cancela, listados antes de confirmar ----

    private fun turnoFuturo(id: String, funcao: String, contraparte: String, local: String, inicio: String, fim: String) =
        TurnoFuturoDaExclusao(id, funcao, contraparte, java.time.Instant.parse(inicio), java.time.Instant.parse(fim), local)

    @Test
    fun listaOsTurnosFuturosComFuncaoContraparteHorarioELocal() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                turnosFuturos = TurnosFuturosDaExclusao.Lista(
                    listOf(
                        turnoFuturo("t1", "garçom", "Bar do Zé", "CLS 405 Bloco C", "2026-11-25T21:00:00Z", "2026-11-26T02:00:00Z"),
                        turnoFuturo("t2", "bartender", "Restaurante Sol", "SCLN 406", "2026-12-02T21:00:00Z", "2026-12-03T05:00:00Z"),
                    ),
                ),
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.TITULO_TURNOS_FUTUROS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("garçom").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Bar do Zé").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("CLS 405 Bloco C").performScrollTo().assertIsDisplayed()
        // 21:00Z é 18:00 em São Paulo e 02:00Z do dia seguinte é 23:00 do mesmo dia: o fim leva só a hora.
        rule.onNodeWithText("25/11/2026 18:00 – 23:00").performScrollTo().assertIsDisplayed()
        // O segundo termina às 02:00 do dia seguinte em São Paulo: o fim leva a data.
        rule.onNodeWithText("02/12/2026 18:00 – 03/12/2026 02:00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("bartender").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Restaurante Sol").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.SEM_TURNOS_FUTUROS).assertDoesNotExist()
        rule.onNodeWithText(TextosExclusaoDeConta.LISTA_TURNOS_INDISPONIVEL).assertDoesNotExist()
    }

    @Test
    fun consultaLimitadaDaCasaAvisaQueAListaPodeEstarIncompleta() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                turnosFuturos = TurnosFuturosDaExclusao.Lista(
                    listOf(turnoFuturo("t1", "garçom", "Maria", "CLS 405", "2026-11-25T21:00:00Z", "2026-11-26T02:00:00Z")),
                    limitada = true,
                ),
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.LISTA_LIMITADA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Maria").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun consultaCompletaDoProfissionalNaoMostraOAvisoDeLimitada() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                turnosFuturos = TurnosFuturosDaExclusao.Lista(
                    listOf(turnoFuturo("t1", "garçom", "Bar do Zé", "CLS 405", "2026-11-25T21:00:00Z", "2026-11-26T02:00:00Z")),
                ),
            ),
        )

        rule.onNodeWithText("Bar do Zé").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.LISTA_LIMITADA).assertDoesNotExist()
    }

    @Test
    fun semTurnosFuturosDizOQueFoiConsultado() {
        montarExclusao(inicial = EstadoExclusaoDeConta(turnosFuturos = TurnosFuturosDaExclusao.Lista(emptyList())))

        rule.onNodeWithText(TextosExclusaoDeConta.TITULO_TURNOS_FUTUROS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.SEM_TURNOS_FUTUROS).assertIsDisplayed()
    }

    @Test
    fun enquantoLeMostraVerificando() {
        montarExclusao(inicial = EstadoExclusaoDeConta(turnosFuturos = TurnosFuturosDaExclusao.Carregando))

        rule.onNodeWithText(TextosExclusaoDeConta.CARREGANDO_TURNOS).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun listaIndisponivelAvisaEAindaDeixaExcluir() {
        var pedidos = 0
        montarExclusao(
            inicial = EstadoExclusaoDeConta(turnosFuturos = TurnosFuturosDaExclusao.Indisponivel),
            aoExcluir = { pedidos++ },
        )

        rule.onNodeWithText(TextosExclusaoDeConta.LISTA_TURNOS_INDISPONIVEL).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().assertIsEnabled().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_CONFIRMAR).performClick()

        assertEquals(1, pedidos)
    }

    @Test
    fun semConsultaATelaNaoMostraASecaoDeTurnos() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.TITULO_TURNOS_FUTUROS).assertDoesNotExist()
        rule.onNodeWithText(TextosExclusaoDeConta.SEM_TURNOS_FUTUROS).assertDoesNotExist()
        rule.onNodeWithText(TextosExclusaoDeConta.CONSEQUENCIA_TURNOS, substring = true).assertIsDisplayed()
    }

    @Test
    fun intervaloDoTurnoUsaOFusoDeSaoPauloEOmiteADataDoFimNoMesmoDia() {
        fun instante(texto: String) = java.time.Instant.parse(texto)
        assertEquals("25/11/2026 18:00 – 23:00", intervaloDoTurno(instante("2026-11-25T21:00:00Z"), instante("2026-11-26T02:00:00Z")))
        assertEquals("25/11/2026 22:30 – 03/12/2026 01:00", intervaloDoTurno(instante("2026-11-26T01:30:00Z"), instante("2026-12-03T04:00:00Z")))
        // Meia-noite UTC ainda é o dia anterior em São Paulo.
        assertEquals("24/11/2026 21:00 – 23:59", intervaloDoTurno(instante("2026-11-25T00:00:00Z"), instante("2026-11-25T02:59:00Z")))
    }

    @Test
    fun aTelaDispararALeituraDosTurnosAoAbrirSemQuemChamaFazerNada() {
        var leituras = 0
        val viewModel = ExclusaoDeContaViewModel(
            excluir = { error("ler a lista não exclui") },
            consultarTurnos = {
                leituras++
                ConsultaDeTurnosDaExclusao(
                    listOf(
                        TurnoFuturoDaExclusao(
                            id = "t1", funcao = "garçom", contraparte = "Bar do Zé",
                            inicio = java.time.Instant.parse("2026-12-02T21:00:00Z"),
                            fim = java.time.Instant.parse("2026-12-03T02:00:00Z"), local = "CLS 405",
                        ),
                    ),
                )
            },
            relogio = { java.time.Instant.parse("2026-11-20T15:00:00Z") },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )

        rule.setContent { FrilaTheme { TelaExclusaoDeConta(viewModel = viewModel, aoVoltar = {}) } }
        rule.waitForIdle()

        assertEquals(1, leituras)
        rule.onNodeWithText("Bar do Zé").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("garçom").performScrollTo().assertIsDisplayed()
    }
}

