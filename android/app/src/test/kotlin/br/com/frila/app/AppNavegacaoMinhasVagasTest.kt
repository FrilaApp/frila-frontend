package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.TextosMinhasVagas
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
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

/**
 * Cartão 6JfSzOR7: a rota de Minhas vagas existe no grafo, fica atrás da guarda biométrica, leva o que
 * a tela de origem sabe (casa e nome) até o ViewModel, e seus callbacks abrem a publicação, os
 * candidatos e a tela anterior. O atalho do perfil só aparece para quem é membro de uma casa.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoMinhasVagasTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private class Recebido(val estabelecimentoId: String, val nome: String?, val recemPublicadaId: String?)

    private val criados = mutableListOf<Recebido>()
    private val paineisPedidos = mutableListOf<String>()
    private val candidatosCriados = mutableListOf<Triple<String, Int?, Instant?>>()
    private var biometria = false
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } answers { biometria }
    }

    private fun vagaNoPainel(id: String, funcao: String, modo: String = "selecao", pendentes: Int = 2, abertas: Int = 2) =
        VagaNoPainelDto(
            vaga = VagaResumoDto(id, funcao, "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
            modo = modo, estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = pendentes,
            posicoes = List(abertas) { br.com.frila.core.rede.PosicaoNoPainelDto(id = "$id-p$it", estado = "aberta", emAtraso = false) },
        )

    private fun painel(estabelecimentoId: String) =
        PainelDto(estabelecimentoId, listOf(vagaNoPainel("v1", "Garçom"), vagaNoPainel("v2", "Barman", modo = "urgencia", pendentes = 0)), emptyList())

    private fun contratanteCom(vararg ids: String): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns
            ids.map { EstabelecimentoDaContaDto(id = it, nome = "Bar $it", papel = "administrador") }
    }

    private fun profissional(): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } throws ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
    }

    private fun montar(servicoMembros: ServicoMembros? = null, inicio: String? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        // A tela de desbloqueio (alvo do redirecionamento da guarda) lê a sessão do grafo.
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { (estabelecimentoId: String, nome: String?, recemPublicadaId: String?) ->
                            criados += Recebido(estabelecimentoId, nome, recemPublicadaId)
                            MinhasVagasViewModel(
                                estabelecimentoId = estabelecimentoId,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recemPublicadaId,
                                buscarPainel = { id, _, _ -> paineisPedidos += id; Result.success(painel(id)) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (vagaId: String, posicoesAbertas: Int?, inicioDaVaga: Instant?) ->
                            candidatosCriados += Triple(vagaId, posicoesAbertas, inicioDaVaga)
                            CandidatosDaVagaViewModel(
                                vagaId = vagaId,
                                buscar = { emptyList<CandidatoDto>() },
                                escolher = { error("não deveria escolher") },
                                posicoesAbertas = posicoesAbertas,
                                inicioDaVaga = inicioDaVaga,
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
                    servicoMembros = servicoMembros,
                )
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    private fun esperarVagas() {
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
    }

    // ---- Atalho do perfil ----

    @Test
    fun perfilDeMembroMostraMinhasVagasEAbreARotaComACasaEOSeuNome() {
        montar(servicoMembros = contratanteCom("casa-1", "casa-2"), inicio = Rotas.PERFIL)

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-minhas-vagas").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithTag("perfil-minhas-vagas").performScrollTo().performClick()
        esperarVagas()

        rule.runOnIdle {
            assertEquals(Rotas.MINHAS_VAGAS, rotaAtual())
            assertEquals("casa-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
            val recebido = criados.single()
            assertEquals("casa-1", recebido.estabelecimentoId)
            assertEquals("Bar casa-1", recebido.nome)
            assertNull(recebido.recemPublicadaId)
            assertEquals(listOf("casa-1"), paineisPedidos)
        }
        rule.onNodeWithText("Bar casa-1").assertExists()
    }

    @Test
    fun minhasVagasFicaAcimaDePublicarVagaNoPerfil() {
        montar(servicoMembros = contratanteCom("casa-1"), inicio = Rotas.PERFIL)

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-publicar-vaga").fetchSemanticsNodes().isNotEmpty() }
        val topoPublicar = rule.onNodeWithTag("perfil-publicar-vaga").performScrollTo().getUnclippedBoundsInRoot().top
        val topoMinhasVagas = rule.onNodeWithTag("perfil-minhas-vagas").getUnclippedBoundsInRoot().top

        assertTrue(topoMinhasVagas < topoPublicar)
    }

    @Test
    fun perfilSemCasaProfissionalOuSemServicoNaoMostraMinhasVagas() {
        montar(servicoMembros = contratanteCom(), inicio = Rotas.PERFIL)
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").fetchSemanticsNodes().isNotEmpty() }
        rule.onAllNodesWithTag("perfil-minhas-vagas").assertCountEquals(0)
    }

    @Test
    fun perfilDeProfissionalNaoMostraMinhasVagas() {
        montar(servicoMembros = profissional(), inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-minhas-vagas").assertCountEquals(0)
    }

    @Test
    fun perfilSemServicoDeMembrosNaoMostraMinhasVagas() {
        montar(servicoMembros = null, inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-minhas-vagas").assertCountEquals(0)
    }

    // ---- Rota ----

    @Test
    fun aRotaAbreATelaLeOPainelDaCasaDoArgumentoEMostraAsVagas() {
        montar(inicio = Rotas.minhasVagas("casa-9", "Bar da Lia", "v2"))
        esperarVagas()

        rule.runOnIdle {
            assertEquals(Rotas.MINHAS_VAGAS, rotaAtual())
            assertEquals(listOf("casa-9"), paineisPedidos)
            val recebido = criados.single()
            assertEquals("casa-9", recebido.estabelecimentoId)
            assertEquals("Bar da Lia", recebido.nome)
            assertEquals("v2", recebido.recemPublicadaId)
        }
        rule.onNodeWithText(TextosMinhasVagas.TITULO).assertExists()
        rule.onNodeWithText("Bar da Lia").assertExists()
        rule.onNodeWithText("Barman").assertExists()
        rule.onNodeWithText(TextosMinhasVagas.RECEM_PUBLICADA).assertExists()
    }

    @Test
    fun semParametrosOpcionaisOViewModelRecebeNulos() {
        montar(inicio = Rotas.minhasVagas("casa-9"))
        esperarVagas()

        rule.runOnIdle {
            assertNull(criados.single().nome)
            assertNull(criados.single().recemPublicadaId)
        }
    }

    @Test
    fun parametroOpcionalEmBrancoViraNaoInformado() {
        montar(inicio = "minhas_vagas/casa-9?nomeEstabelecimento=%20%20&vagaRecemPublicadaId=")
        esperarVagas()

        rule.runOnIdle {
            assertNull(criados.single().nome)
            assertNull(criados.single().recemPublicadaId)
        }
    }

    @Test
    fun nomeEIdComCaracteresEspeciaisChegamInteiros() {
        montar(inicio = Rotas.minhasVagas("casa com espaço", "Bar & Grill / Cia?", "vaga#1"))
        esperarVagas()

        rule.runOnIdle {
            val recebido = criados.single()
            assertEquals("casa com espaço", recebido.estabelecimentoId)
            assertEquals("Bar & Grill / Cia?", recebido.nome)
            assertEquals("vaga#1", recebido.recemPublicadaId)
        }
    }

    // ---- Callbacks ----

    @Test
    fun verCandidatosAbreARotaDeCandidatosComIdPosicoesAbertasEInicio() {
        montar(inicio = Rotas.minhasVagas("casa-9"))
        esperarVagas()

        rule.onNodeWithContentDescription("Ver candidatos da vaga de Garçom").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.CANDIDATOS_DA_VAGA, rotaAtual())
            assertEquals("v1", nav.currentBackStackEntry?.arguments?.getString("vagaId"))
            assertEquals(Triple("v1", 2, Instant.parse("2026-11-12T21:00:00Z")), candidatosCriados.single())
        }
    }

    @Test
    fun publicarVagaAbreARotaDePublicacaoDaCasaDaRota() {
        montar(inicio = Rotas.minhasVagas("casa-9"))
        esperarVagas()

        rule.onNodeWithText(TextosMinhasVagas.PUBLICAR_VAGA).performClick()

        rule.runOnIdle {
            assertEquals(Rotas.PUBLICAR_VAGA, rotaAtual())
            assertEquals("casa-9", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
    }

    @Test
    fun voltarDevolveATelaAnterior() {
        montar(inicio = Rotas.minhasVagas("casa-9"))
        esperarVagas()

        rule.onNodeWithContentDescription(TextosMinhasVagas.ROTULO_VOLTAR).performClick()

        rule.runOnIdle { assertEquals(Rotas.ENTRADA, rotaAtual()) }
    }

    // ---- Guarda biométrica (RN15) ----

    @Test
    fun comBiometriaAtivadaARotaRedirecionaParaODesbloqueioSemCriarOViewModelNemLerOPainel() {
        biometria = true
        montar(inicio = Rotas.minhasVagas("casa-9", "Bar da Lia"))
        rule.waitForIdle()

        rule.runOnIdle {
            assertEquals(Rotas.DESBLOQUEIO, rotaAtual())
            assertTrue(criados.isEmpty())
            assertTrue(paineisPedidos.isEmpty())
        }
    }

    // ---- Rotas ----

    @Test
    fun construtorDeRotaMontaECodificaOCaminho() {
        assertEquals("minhas_vagas/casa-1", Rotas.minhasVagas("casa-1"))
        assertEquals("minhas_vagas/casa-1?nomeEstabelecimento=Bar%20da%20Lia", Rotas.minhasVagas("casa-1", "Bar da Lia"))
        assertEquals("minhas_vagas/casa-1?vagaRecemPublicadaId=v1", Rotas.minhasVagas("casa-1", vagaRecemPublicadaId = "v1"))
        assertEquals(
            "minhas_vagas/casa-1?nomeEstabelecimento=Bar%20%26%20Grill&vagaRecemPublicadaId=v1",
            Rotas.minhasVagas("casa-1", "Bar & Grill", "v1"),
        )
        assertEquals("minhas_vagas/a%2Fb", Rotas.minhasVagas("a/b"))
        assertEquals(
            "minhas_vagas/{estabelecimentoId}?nomeEstabelecimento={nomeEstabelecimento}&vagaRecemPublicadaId={vagaRecemPublicadaId}",
            Rotas.MINHAS_VAGAS,
        )
    }
}
