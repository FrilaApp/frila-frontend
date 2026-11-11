package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.TextosTurnoDoContratante
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão zqub2hps: a rota do turno pela casa existe no grafo, lê o turno do painel, fica atrás da guarda
 * biométrica, abre a partir de Minhas vagas e leva o contexto até o ViewModel; falhas de leitura e turno
 * inexistente têm tela própria.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoTurnoDoContratanteTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val contextos = mutableListOf<ContextoDoTurnoContratante>()
    private val confirmados = mutableListOf<String>()
    private var biometria = false
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } answers { biometria }
    }

    private fun painel(
        estabelecimentoId: String = "est-1",
        turnoId: String? = "t1",
        vagaId: String = "v1",
        posicaoId: String = "p1",
    ) = PainelDto(
        estabelecimentoId = estabelecimentoId,
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto(vagaId, "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(
                    PosicaoNoPainelDto(
                        id = posicaoId, estado = "confirmada", turnoId = turnoId, verificacao = "pendente", emAtraso = false,
                        checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual",
                        profissional = PerfilPublicoDto("pr1", "profissional", "Ana", reputacao = ReputacaoDto(1, 1, null, 1, 1)),
                    ),
                ),
            ),
        ),
    )

    private val pedidos = mutableListOf<String>()
    private val janelas = mutableListOf<Pair<java.time.Instant, java.time.Instant>>()

    private fun servicoCom(resposta: () -> Result<PainelDto>): ServicoVagas = mockk {
        coEvery { painelEstabelecimento(any(), any(), any()) } answers {
            pedidos += firstArg<String>()
            janelas += secondArg<java.time.Instant>() to thirdArg<java.time.Instant>()
            resposta()
        }
    }

    private fun montar(servicoVagas: ServicoVagas?, inicio: String? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { (contexto: ContextoDoTurnoContratante) ->
                            contextos += contexto
                            AcompanhamentoContratanteViewModel(
                                contexto = contexto,
                                confirmar = { id ->
                                    confirmados += id
                                    Result.success(ResultadoRegistroDto(id, "manual", "verificado", "2026-11-12T21:05:00Z"))
                                },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimentoId: String, nome: String?, recem: String?) ->
                            MinhasVagasViewModel(
                                estabelecimentoId = estabelecimentoId,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recem,
                                buscarPainel = { _, _, _ -> Result.success(painel(estabelecimentoId)) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    servicoMembros = null,
                    servicoVagas = servicoVagas,
                )
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    private fun esperar(texto: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `a rota le o turno do painel da casa e abre a tela com o contexto`() {
        montar(servicoCom { Result.success(painel()) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))

        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.runOnIdle {
            assertEquals(Rotas.TURNO_DO_CONTRATANTE, rotaAtual())
            assertEquals(listOf("est-1"), pedidos)
            // A mesma janela de Minhas vagas: 365 dias para cada lado.
            val (de, ate) = janelas.single()
            assertEquals(730L, java.time.Duration.between(de, ate).toDays())
            assertTrue(de.isBefore(java.time.Instant.now()) && ate.isAfter(java.time.Instant.now()))
            val contexto = contextos.single()
            assertEquals("t1", contexto.turnoId)
            assertEquals("Ana", contexto.profissional?.nome)
            assertEquals("manual", contexto.checkinTipo)
        }
        rule.onNodeWithText("Garçom").assertExists()
    }

    @Test
    fun `confirmar presenca chama o servico com o turno e mostra a presenca verificada`() {
        montar(servicoCom { Result.success(painel()) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))
        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).performClick()

        rule.runOnIdle { assertEquals(listOf("t1"), confirmados) }
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertExists()
    }

    @Test
    fun `ids com caracteres especiais chegam inteiros ao painel e ao contexto`() {
        montar(
            servicoCom { Result.success(painel("est/1", "t#1", "vaga com espaco", "pos&1")) },
            Rotas.turnoDoContratante("est/1", "vaga com espaco", "pos&1"),
        )

        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.runOnIdle {
            assertEquals(listOf("est/1"), pedidos)
            assertEquals("t#1", contextos.single().turnoId)
        }
    }

    private fun naoEncontradoCom(resposta: PainelDto) {
        montar(servicoCom { Result.success(resposta) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))

        esperar(TextosTurnoDoContratanteDaRota.NAO_ENCONTRADO)

        rule.runOnIdle { assertTrue(contextos.isEmpty()) }
        assertEquals(0, rule.onAllNodesWithText("Tentar novamente").fetchSemanticsNodes().size)
    }

    @Test
    fun `posicao que sumiu do painel mostra nao encontrado sem criar o ViewModel`() = naoEncontradoCom(painel(posicaoId = "outra"))

    @Test
    fun `vaga que sumiu do painel mostra nao encontrado sem criar o ViewModel`() = naoEncontradoCom(painel(vagaId = "outra"))

    @Test
    fun `posicao sem turno mostra nao encontrado sem criar o ViewModel`() = naoEncontradoCom(painel(turnoId = null))

    @Test
    fun `painel de outra casa mostra nao encontrado sem criar o ViewModel`() = naoEncontradoCom(painel(estabelecimentoId = "outra-casa"))

    @Test
    fun `falha de leitura oferece tentar novamente e abre o turno na segunda tentativa`() {
        var chamadas = 0
        montar(
            servicoCom { if (++chamadas == 1) Result.failure(IllegalStateException("corpo não é JSON")) else Result.success(painel()) },
            Rotas.turnoDoContratante("est-1", "v1", "p1"),
        )
        esperar(TextosTurnoDoContratanteDaRota.FALHA)
        rule.runOnIdle { assertTrue(contextos.isEmpty()) }

        rule.onNodeWithText("Tentar novamente").performClick()
        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.runOnIdle { assertEquals(2, chamadas) }
    }

    @Test
    fun `lancamento escapando do servico tambem mostra a falha com nova tentativa`() {
        val servico = mockk<ServicoVagas> {
            coEvery { painelEstabelecimento(any(), any(), any()) } throws IllegalStateException("explodiu")
        }
        montar(servico, Rotas.turnoDoContratante("est-1", "v1", "p1"))

        esperar(TextosTurnoDoContratanteDaRota.FALHA)

        rule.onNodeWithText("Tentar novamente").assertExists()
        rule.runOnIdle { assertTrue(contextos.isEmpty()) }
    }

    @Test
    fun `sem permissao mostra o motivo e nao oferece tentar novamente`() {
        val erro = ErroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", null, "x")
        montar(servicoCom { Result.failure(erro) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))

        esperar(TextosTurnoDoContratanteDaRota.SEM_PERMISSAO)

        assertEquals(0, rule.onAllNodesWithText("Tentar novamente").fetchSemanticsNodes().size)
    }

    @Test
    fun `sem o servico no grafo a rota mostra a falha em vez de travar no carregando`() {
        montar(null, Rotas.turnoDoContratante("est-1", "v1", "p1"))

        esperar(TextosTurnoDoContratanteDaRota.FALHA)
        assertEquals(0, rule.onAllNodesWithText("Tentar novamente").fetchSemanticsNodes().size)
    }

    @Test
    fun `voltar devolve a tela anterior`() {
        montar(servicoCom { Result.success(painel()) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))
        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.onNodeWithContentDescription(TextosTurnoDoContratante.ROTULO_VOLTAR).performClick()

        rule.runOnIdle { assertEquals(Rotas.ENTRADA, rotaAtual()) }
    }

    @Test
    fun `de Minhas vagas, acompanhar turno abre a rota com casa, vaga e posicao`() {
        montar(servicoCom { Result.success(painel()) }, Rotas.minhasVagas("est-1", "Bar da Lia"))
        esperar("Acompanhar turno de Ana")

        rule.onNodeWithText("Acompanhar turno de Ana").performScrollTo().performClick()
        esperar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)

        rule.runOnIdle {
            assertEquals(Rotas.TURNO_DO_CONTRATANTE, rotaAtual())
            val argumentos = nav.currentBackStackEntry?.arguments
            assertEquals("est-1", argumentos?.getString("estabelecimentoId"))
            assertEquals("v1", argumentos?.getString("vagaId"))
            assertEquals("p1", argumentos?.getString("posicaoId"))
            assertEquals("t1", contextos.single().turnoId)
        }
    }

    @Test
    fun `com biometria ativada a rota redireciona para o desbloqueio sem ler o painel nem criar o ViewModel`() {
        biometria = true
        montar(servicoCom { Result.success(painel()) }, Rotas.turnoDoContratante("est-1", "v1", "p1"))
        rule.waitForIdle()

        rule.runOnIdle {
            assertEquals(Rotas.DESBLOQUEIO, rotaAtual())
            assertTrue(pedidos.isEmpty())
            assertTrue(contextos.isEmpty())
        }
    }

    @Test
    fun `construtor de rota monta e codifica o caminho`() {
        assertEquals("turno_do_contratante/est-1/v1/p1", Rotas.turnoDoContratante("est-1", "v1", "p1"))
        assertEquals("turno_do_contratante/a%2Fb/c%20d/e%26f", Rotas.turnoDoContratante("a/b", "c d", "e&f"))
        assertEquals("turno_do_contratante/{estabelecimentoId}/{vagaId}/{posicaoId}", Rotas.TURNO_DO_CONTRATANTE)
    }
}
