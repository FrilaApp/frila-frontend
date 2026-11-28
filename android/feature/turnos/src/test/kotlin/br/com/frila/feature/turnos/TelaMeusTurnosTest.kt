package br.com.frila.feature.turnos

import android.content.Intent
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.assertHeightIsAtLeast
import br.com.frila.core.designsystem.componentes.TextosVerNoMapa
import br.com.frila.core.designsystem.tema.FrilaMetricas
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaMeusTurnosTest {

    @get:Rule
    val compose = createComposeRule()

    private val provedorDeLocalizacaoFalso = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    private fun criarViewModel(respostaJson: String, status: HttpStatusCode = HttpStatusCode.OK): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun criarCheckin(
        turnoId: String,
        provedorDeLocalizacao: ProvedorDeLocalizacao = provedorDeLocalizacaoFalso,
        engine: MockEngine = MockEngine { respond("") },
    ): CheckinViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = null,
            servicoTurnos = ServicoTurnos(cliente),
            provedorDeLocalizacao = provedorDeLocalizacao,
        )
    }

    private fun resultadoCheckinJson(tipo: String, verificacao: String) = """
        {
          "turno_id": "t1",
          "tipo": "$tipo",
          "verificacao": "$verificacao",
          "registrado_em": "2026-11-01T21:05:00Z",
          "distancia_m": null
        }
    """.trimIndent()

    private fun turnoJson(id: String, estado: String, funcao: String, estabelecimento: String) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "$funcao",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun `C0-9 - Denunciar no turno leva o id da casa e o do turno, como o iOS`() {
        runBlocking {
            val viewModel = criarViewModel("[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]")
            viewModel.carregar().join()
            val denuncias = mutableListOf<Pair<String, String>>()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                        aoDenunciarEstabelecimento = { casa, turno -> denuncias += casa to turno },
                    )
                }
            }

            compose.onNodeWithContentDescription("Denunciar Bar do Zé").performScrollTo()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
            assertEquals(listOf("e1" to "t1"), denuncias)
        }
    }

    private fun montarComBloqueados(bloqueados: Set<String>, comDenunciar: Boolean = true) {
        val viewModel = criarViewModel("[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]")
        runBlocking { viewModel.carregar().join() }
        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    aoDenunciarEstabelecimento = if (comDenunciar) ({ _, _ -> }) else null,
                    estabelecimentosBloqueados = bloqueados,
                )
            }
        }
    }

    @Test
    fun `I1PonzKJ - turno de estabelecimento bloqueado diz que o profissional o bloqueou`() {
        montarComBloqueados(setOf("e1"))

        compose.onNodeWithText(TextosMeusTurnos.VOCE_BLOQUEOU_ESTABELECIMENTO).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `I1PonzKJ - o aviso aparece mesmo sem a acao de denunciar`() {
        montarComBloqueados(setOf("e1"), comDenunciar = false)

        compose.onNodeWithText(TextosMeusTurnos.VOCE_BLOQUEOU_ESTABELECIMENTO).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `I1PonzKJ - sem bloqueio, ou com outra casa bloqueada, o turno nao diz isso`() {
        montarComBloqueados(setOf("outra-casa"))

        assertEquals(0, compose.onAllNodesWithText(TextosMeusTurnos.VOCE_BLOQUEOU_ESTABELECIMENTO).fetchSemanticsNodes().size)
    }

    @Test
    fun `tela inicial exibe titulo e abas Agendados e Historico`() {
        val viewModel = criarViewModel("[]")

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                )
            }
        }

        compose.onNodeWithText("Meus Turnos").assertIsDisplayed()
        compose.onNodeWithText("Agendados").assertIsDisplayed().assertHasClickAction()
        compose.onNodeWithText("Histórico").assertIsDisplayed().assertHasClickAction()
    }

    @Test
    fun `quando lista de turnos e vazia exibe mensagem informativa`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }

            compose.waitForIdle()
            // Texto do iOS (TextosDoProfissional.vazioTitulo e vazioMensagem), na aba Agendados.
            compose.onNodeWithText("Nenhum turno confirmado").assertIsDisplayed()
            compose.onNodeWithText("Quando você tiver turnos confirmados, eles aparecerão aqui.").assertIsDisplayed()
            compose.onNodeWithText("Você ainda não tem turnos nesta aba.").assertDoesNotExist()
        }
    }

    // ---- Estado vazio das duas abas (cartão FI3gB4Zw) ----

    private val tituloVazioAgendados = "Nenhum turno confirmado"
    private val mensagemVazioAgendados = "Quando você tiver turnos confirmados, eles aparecerão aqui."
    private val tituloVazioHistorico = "Nenhum turno no histórico"
    private val mensagemVazioHistorico = "Turnos concluídos e cancelados aparecerão aqui."

    /** Carrega [json] e mostra a tela; [aba] é a aba em que o teste olha (a tela abre em Agendados). */
    private fun abrirNaAba(json: String, aba: AbaDeTurnos) {
        runBlocking {
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(viewModel = viewModel, criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) })
                }
            }
            compose.waitForIdle()
            if (aba == AbaDeTurnos.HISTORICO) {
                compose.onNodeWithText("Histórico").performClick()
                compose.waitForIdle()
            }
        }
    }

    private fun verificarVazioAgendados() {
        compose.onNodeWithText(tituloVazioAgendados).assertIsDisplayed()
        compose.onNodeWithText(mensagemVazioAgendados).assertIsDisplayed()
        compose.onNodeWithText(tituloVazioHistorico).assertDoesNotExist()
        compose.onNodeWithText("Você ainda não tem turnos nesta aba.").assertDoesNotExist()
    }

    private fun verificarVazioHistorico() {
        compose.onNodeWithText(tituloVazioHistorico).assertIsDisplayed()
        compose.onNodeWithText(mensagemVazioHistorico).assertIsDisplayed()
        compose.onNodeWithText(tituloVazioAgendados).assertDoesNotExist()
        compose.onNodeWithText("Você ainda não tem turnos nesta aba.").assertDoesNotExist()
    }

    @Test
    fun `sem nenhum turno a aba Historico mostra o texto proprio do historico`() {
        abrirNaAba("[]", AbaDeTurnos.HISTORICO)
        verificarVazioHistorico()
    }

    @Test
    fun `so com turno do historico a aba Agendados esta vazia e mostra o texto do ios`() {
        abrirNaAba("[${turnoJson("t1", "cumprida", "Garçom", "Bar do Zé")}]", AbaDeTurnos.AGENDADOS)
        verificarVazioAgendados()
    }

    @Test
    fun `so com turno agendado a aba Historico esta vazia e mostra o texto do historico`() {
        abrirNaAba("[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]", AbaDeTurnos.HISTORICO)
        verificarVazioHistorico()
    }

    @Test
    fun `quando ocorre erro exibe mensagem de erro e botao tentar novamente`() {
        runBlocking {
            val erroJson = """{"code":"PGRST500","message":"Erro interno"}"""
            val viewModel = criarViewModel(erroJson, HttpStatusCode.InternalServerError)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Tentar novamente").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `quando possui turnos agendados exibe cartao com informacoes e status`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Garçom").assertIsDisplayed()
            compose.onNodeWithText("Bar do Zé").assertIsDisplayed()
            compose.onNodeWithText("Confirmado").assertIsDisplayed()
            compose.onNodeWithText("Cancelar turno").assertExists()
        }
    }

    @Test
    fun `ao alternar para aba Historico exibe turnos cumpridos ou cancelados`() {
        runBlocking {
            val json = """
                [
                  ${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")},
                  ${turnoJson("t2", "cumprida", "Cozinheiro", "Restaurante Bom Sabor")}
                ]
            """.trimIndent()
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            // Inicialmente na aba Agendados
            compose.onNodeWithText("Garçom").assertIsDisplayed()

            // Clica na aba Histórico
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Cozinheiro").assertIsDisplayed()
            compose.onNodeWithText("Restaurante Bom Sabor").assertIsDisplayed()
            compose.onNodeWithText("Cumprido").assertIsDisplayed()
        }
    }

    @Test
    fun `quando cancelamento e solicitado exibe dialogo com regra de antecedencia e confirmacao sem campo de motivo`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            val turno = viewModel.estado.value.agendados.first()
            viewModel.abrirCancelamento(turno)
            compose.waitForIdle()

            compose.onNodeWithText("Faltam menos de 24 horas. Este cancelamento conta como falta e pode afetar sua reputação.").assertIsDisplayed()
            compose.onNodeWithText("Confirmar cancelamento").assertIsDisplayed()
            compose.onNodeWithText("Voltar").assertIsDisplayed()
            compose.onNodeWithText("Qual é o motivo?").assertDoesNotExist()
        }
    }

    @Test
    fun `sem permissao, tocar em Fazer check-in pede a permissao do sistema e a recusa exibe o dialogo Permissao de localizacao`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = false
                override fun isGpsAtivado(): Boolean = true
            }

            var pedidos = 0
            val pedido: (aoResponder: (Boolean) -> Unit) -> Unit = { responder -> pedidos++; responder(false) }

            compose.setContent {
                CompositionLocalProvider(LocalPedidoDePermissaoDeLocalizacao provides pedido) {
                    FrilaTheme {
                        TelaMeusTurnos(
                            viewModel = viewModel,
                            criarCheckinViewModel = { turno -> remember(turno.turnoId) { criarCheckin(turno.turnoId, provedorDeLocalizacao = provedor) } },
                            relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                        )
                    }
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Fazer check-in").performScrollTo().performClick()
            compose.waitForIdle()

            // C0-7: o toque pede a permissão ao sistema uma vez; só a recusa leva ao diálogo das Configurações.
            assertEquals(1, pedidos)
            compose.onNodeWithText("Permissão de localização").assertIsDisplayed()
            compose.onNodeWithText("Abrir configurações").assertIsDisplayed().assertHasClickAction()
            compose.onNodeWithText("Continuar manual").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `com GPS desligado, tocar em Fazer check-in exibe dialogo GPS desativado`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = true
                override fun isGpsAtivado(): Boolean = false
            }

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> remember(turno.turnoId) { criarCheckin(turno.turnoId, provedorDeLocalizacao = provedor) } },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Fazer check-in").performScrollTo().performClick()
            compose.waitForIdle()

            compose.onNodeWithText("GPS desativado").assertIsDisplayed()
            compose.onNodeWithText("Ativar GPS").assertIsDisplayed().assertHasClickAction()
            compose.onNodeWithText("Continuar manual").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `tocar em Continuar manual no dialogo registra check-in manual pendente`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = false
                override fun isGpsAtivado(): Boolean = true
            }
            val engine = MockEngine {
                respond(
                    content = resultadoCheckinJson(tipo = "manual", verificacao = "pendente"),
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }

            val pedido: (aoResponder: (Boolean) -> Unit) -> Unit = { responder -> responder(false) }

            compose.setContent {
                CompositionLocalProvider(LocalPedidoDePermissaoDeLocalizacao provides pedido) {
                    FrilaTheme {
                        TelaMeusTurnos(
                            viewModel = viewModel,
                            criarCheckinViewModel = { turno -> remember(turno.turnoId) { criarCheckin(turno.turnoId, provedorDeLocalizacao = provedor, engine = engine) } },
                            relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                        )
                    }
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Fazer check-in").performScrollTo().performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Continuar manual").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Check-in manual, aguardando confirmação do contratante").assertIsDisplayed()
        }
    }

    private fun jsonComHistorico(quantidade: Int): String =
        "[" + (1..quantidade).joinToString(",") { turnoJson("h$it", "cumprida", "Garçom $it", "Bar do Zé") } + "]"

    @Test
    fun `aba Historico exibe itens concluidos com badge de status e valor em BRL`() {
        runBlocking {
            val json = "[${turnoJson("t1", "cumprida", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Garçom").assertIsDisplayed()
            compose.onNodeWithText("Cumprido").assertIsDisplayed()
            compose.onNodeWithText(Dinheiro(16_000L).formatado()).assertExists()
        }
    }

    @Test
    fun `aba Historico com mais de 10 itens inicia na primeira pagina e rolagem infinita libera o resto (RF16)`() {
        runBlocking {
            val viewModel = criarViewModel(jsonComHistorico(15))
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Garçom 1").assertIsDisplayed()
            // Medido antes de rolar: a primeira composição (poucos itens visíveis no viewport)
            // ainda não disparou o gatilho de fim de lista — só a primeira página está liberada.
            assertEquals(10, viewModel.estado.value.historicoPaginado.size)
            assertEquals(1, viewModel.estado.value.paginaHistorico)

            // Rolar até o fim da primeira página aciona a rolagem infinita (RF16): o gatilho de
            // "faltam 2 itens" detecta o fim da lista atual e carrega a página seguinte sozinho.
            compose.onNodeWithTag("lista-de-turnos").performScrollToIndex(9)
            compose.waitForIdle()

            assertEquals(15, viewModel.estado.value.historicoPaginado.size)
        }
    }

    @Test
    fun `carregarMaisHistorico libera a segunda pagina na UI`() {
        runBlocking {
            val viewModel = criarViewModel(jsonComHistorico(15))
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()
            assertEquals(10, viewModel.estado.value.historicoPaginado.size)

            viewModel.carregarMaisHistorico()!!.join()
            compose.waitForIdle()

            assertEquals(15, viewModel.estado.value.historicoPaginado.size)
            compose.onNodeWithTag("lista-de-turnos").performScrollToIndex(14)
            compose.waitForIdle()
            compose.onNodeWithText("Garçom 15").assertExists()
        }
    }

    @Test
    fun `tela de Meus Turnos expoe PullToRefreshBox com semantica acessivel`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithContentDescription("Meus turnos").assertExists()
        }
    }

    @Test
    fun `durante o carregamento exibe skeleton anunciado uma unica vez (RNF10)`() {
        // Sem chamar carregar(), o estado default do MeusTurnosViewModel fica em CARREGANDO —
        // MEDIDO em EstadoMeusTurnos.kt:57.
        val viewModel = criarViewModel("[]")

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Carregando turnos...").assertIsDisplayed()
    }

    @Test
    fun `skeleton do carregamento anuncia como liveRegion Polite (RNF10)`() {
        // MEDIDO (Shisui, PR #594, bloqueante 1): sabotagem removendo liveRegion sobreviveu.
        val viewModel = criarViewModel("[]")

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Carregando turnos...")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))
    }

    private fun turnoComCheckinJson(
        id: String,
        checkinTipo: String?,
        verificacao: String,
        checkinConfirmadoEm: String? = null,
        distanciaM: Int? = null,
        checkinEm: String? = "2026-11-01T20:55:00Z",
    ) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "Garçom",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": "2026-11-01T20:30:00Z",
          "checkin_em": ${checkinEm?.let { "\"$it\"" } ?: "null"},
          "checkin_tipo": ${checkinTipo?.let { "\"$it\"" } ?: "null"},
          "checkin_distancia_m": $distanciaM,
          "checkin_confirmado_em": ${checkinConfirmadoEm?.let { "\"$it\"" } ?: "null"},
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "$verificacao",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": false,
          "estado": "confirmada",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun `card de turno com checkin geolocalizado exibe Check-in verificado e botao Ver comprovante`() {
        val json = "[" + turnoComCheckinJson("t-geo", "geolocalizado", "verificado", distanciaM = 80) + "]"
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithText("Check-in verificado").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Ver comprovante").performScrollTo().assertIsDisplayed().assertHasClickAction()
    }

    @Test
    fun `card de turno com checkin manual confirmado exibe Check-in manual confirmado e botao Ver comprovante`() {
        val json = "[" + turnoComCheckinJson("t-man-conf", "manual", "verificado", checkinConfirmadoEm = "2026-11-01T21:10:00Z", distanciaM = 350) + "]"
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithText("Check-in manual confirmado").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Ver comprovante").performScrollTo().assertIsDisplayed().assertHasClickAction()
    }

    @Test
    fun `card de turno com checkin nao verificado exibe Check-in sem verificacao e botao Ver comprovante`() {
        val json = "[" + turnoComCheckinJson("t-nv", "manual", "nao_verificado") + "]"
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithText("Check-in sem verificação").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Ver comprovante").performScrollTo().assertIsDisplayed().assertHasClickAction()
    }

    @Test
    fun `check-in com hora ilegivel segue como check-in feito, sem Fazer check-in, com check-out e sem hora inventada`() {
        val json = "[" + turnoComCheckinJson("t-ilegivel", "geolocalizado", "verificado", distanciaM = 80, checkinEm = "ontem") + "]"
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    // Dentro da janela do turno (21:00 a 03:00): o check-out está disponível quando o check-in foi feito.
                    relogio = { Instant.parse("2026-11-01T22:00:00Z") },
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithText("Check-in verificado").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Ver comprovante").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText(TextosCheckoutECodigo.BOTAO_CHECKOUT).performScrollTo().assertIsDisplayed()
        compose.onAllNodesWithText(TextosCheckin.BOTAO_FAZER_CHECKIN).assertCountEquals(0)
    }

    // ---- zjiTWbAP: "Ver no mapa" no turno, só quando o contrato já libera o ponto (turno confirmado ou verificado) ----

    private fun comPonto(json: String) = json.replace(
        "\"regiao_administrativa\": \"Plano Piloto\",",
        "\"regiao_administrativa\": \"Plano Piloto\", \"ponto\": {\"latitude\": -15.8222, \"longitude\": -47.8998},",
    )

    @Test
    fun `turno com o ponto liberado abre o endereco no mapa, centrado no ponto`() {
        runBlocking {
            val json = comPonto(turnoJson("t1", "confirmada", "Garçom", "Bar do Zé"))
            assertTrue(json.contains("\"ponto\""))
            val viewModel = criarViewModel("[$json]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme { TelaMeusTurnos(viewModel = viewModel, criarCheckinViewModel = { criarCheckin(it.turnoId) }) }
            }

            compose.onNodeWithTag(TextosVerNoMapa.TAG).performScrollTo().performClick()
            compose.waitForIdle()

            val aberto = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
            assertEquals(Intent.ACTION_VIEW, aberto.action)
            assertEquals("geo:-15.822200,-47.899800?q=CLS%20405%20Bloco%20C", aberto.dataString)
        }
    }

    @Test
    fun `turno sem o ponto liberado nao oferece o mapa`() {
        runBlocking {
            val viewModel = criarViewModel("[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme { TelaMeusTurnos(viewModel = viewModel, criarCheckinViewModel = { criarCheckin(it.turnoId) }) }
            }

            compose.onNodeWithText("Garçom").assertExists()
            compose.onAllNodesWithTag(TextosVerNoMapa.TAG).assertCountEquals(0)
        }
    }
}
