package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
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
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.EstabelecimentoDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.NovaVagaDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.VagaPublicadaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.estabelecimento.TextosCadastroEstabelecimento
import br.com.frila.feature.estabelecimento.TipoEstabelecimento
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import io.mockk.coEvery
import io.mockk.coVerify
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
 * Cartão uB6pxGpW: as rotas de cadastro de estabelecimento e de publicação de vaga existem no grafo,
 * os atalhos do perfil só aparecem para quem pode usá-los, e a rota de publicação leva a casa lida
 * do servidor (não só o id) até o ViewModel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoEstabelecimentoVagasTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val casasRecebidas = mutableListOf<EstabelecimentoDaVaga>()
    private val publicacoes = mutableListOf<NovaVagaDto>()
    private var biometria = false
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } answers { biometria }
    }

    private val ponto = CoordenadaDto(-15.7942, -47.8822)

    private fun casaLida(id: String) = MeuEstabelecimentoDto(
        id = id,
        nome = "Bar da Lia",
        tipo = "food_service",
        endereco = "CLS 408, Bloco B, Loja 12",
        regiaoAdministrativa = "Plano Piloto",
        ponto = ponto,
        papel = "operador",
    )

    private fun contratanteCom(vararg ids: String): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns
            ids.map { EstabelecimentoDaContaDto(id = it, nome = "Casa $it", papel = "administrador") }
        coEvery { meuEstabelecimento(any()) } answers { casaLida(firstArg()) }
    }

    private fun profissional(): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } throws ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
    }

    private fun montar(
        servicoMembros: ServicoMembros? = null,
        inicio: String? = null,
        cadastro: CadastroEstabelecimentoViewModel = cadastroQueFalha(),
    ) {
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
                        viewModel { cadastro }
                        viewModel { (estabelecimento: EstabelecimentoDaVaga) ->
                            casasRecebidas += estabelecimento
                            PublicarVagaViewModel(
                                estabelecimento = estabelecimento,
                                buscarFuncoes = { listOf(FuncaoDto("f1", "Garçom", "Salão")) },
                                enviarVaga = { corpo -> publicacoes += corpo; VagaPublicadaDto("v1", listOf("p1")) },
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

    private fun cadastroQueFalha() = CadastroEstabelecimentoViewModel(
        cadastrar = { error("não deveria cadastrar") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun rotaAtual() = nav.currentDestination?.route

    private fun esperarAtalho(tag: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    }

    // ---- Atalhos do perfil ----

    @Test
    fun perfilDeMembroMostraPublicarVagaEAbreARotaComOIdDaCasa() {
        val membros = contratanteCom("casa-1", "casa-2")
        montar(servicoMembros = membros, inicio = Rotas.PERFIL)

        esperarAtalho("perfil-publicar-vaga")
        rule.onNodeWithTag("perfil-cadastrar-estabelecimento").assertDoesNotExist()
        rule.onNodeWithTag("perfil-publicar-vaga").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.PUBLICAR_VAGA, rotaAtual())
            assertEquals("casa-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVaga.TITULO).fetchSemanticsNodes().isNotEmpty() }
        coVerify(exactly = 1) { membros.meuEstabelecimento("casa-1") }
    }

    @Test
    fun rotaDePublicacaoLevaAoViewModelAcasaLidaDoServidorEPreencheOEndereco() {
        montar(servicoMembros = contratanteCom("casa-1"), inicio = Rotas.publicarVaga("casa-1"))

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVaga.TITULO).fetchSemanticsNodes().isNotEmpty() }

        rule.runOnIdle {
            assertEquals(
                listOf(EstabelecimentoDaVaga("casa-1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", ponto)),
                casasRecebidas,
            )
        }
        rule.onNodeWithText("CLS 408, Bloco B, Loja 12").assertExists()
    }

    @Test
    fun perfilDeContratanteSemCasaOferecaCadastrarEstabelecimentoEAbreOFormulario() {
        montar(servicoMembros = contratanteCom(), inicio = Rotas.PERFIL)

        esperarAtalho("perfil-cadastrar-estabelecimento")
        rule.onNodeWithTag("perfil-publicar-vaga").assertDoesNotExist()
        rule.onNodeWithTag("perfil-equipe").assertDoesNotExist()
        rule.onNodeWithTag("perfil-cadastrar-estabelecimento").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(Rotas.CADASTRO_ESTABELECIMENTO, rotaAtual()) }
        rule.onNodeWithText(TextosCadastroEstabelecimento.TITULO).assertExists()
    }

    @Test
    fun perfilDeProfissionalNaoMostraAtalhoDeContratante() {
        montar(servicoMembros = profissional(), inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-publicar-vaga").assertCountEquals(0)
        rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").assertCountEquals(0)
    }

    @Test
    fun perfilSemServicoDeMembrosNaoMostraAtalhoDeContratante() {
        montar(servicoMembros = null, inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-publicar-vaga").assertCountEquals(0)
        rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").assertCountEquals(0)
    }

    @Test
    fun perfilQuandoALeituraDasCasasFalhaPorRespostaIlegivelNaoMostraAtalho() {
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } throws IllegalStateException("corpo não é JSON")
        }
        montar(servicoMembros = membros, inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-publicar-vaga").assertCountEquals(0)
        rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").assertCountEquals(0)
    }

    // ---- Cadastro ----

    @Test
    fun cadastroConcluidoSegueParaPublicarVagaDaNovaCasaSemDeixarOFormularioNaPilha() {
        val cadastro = CadastroEstabelecimentoViewModel(
            cadastrar = { corpo ->
                EstabelecimentoDto("nova-1", corpo.nome, corpo.documento, corpo.tipo, corpo.endereco, corpo.regiaoAdministrativa, corpo.ponto, "administrador")
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        cadastro.editarNome("Bar da Lia")
        cadastro.editarDocumento("12345678000199")
        cadastro.escolherTipo(TipoEstabelecimento.EVENTO)
        cadastro.editarEndereco("CLS 408, Bloco B, Loja 12")
        cadastro.escolherRegiao("Plano Piloto")
        cadastro.editarLatitude("-15,7942")
        cadastro.editarLongitude("-47.8822")
        montar(servicoMembros = contratanteCom("nova-1"), inicio = Rotas.CADASTRO_ESTABELECIMENTO, cadastro = cadastro)

        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRAR).performScrollTo().performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVaga.TITULO).fetchSemanticsNodes().isNotEmpty() }
        rule.runOnIdle {
            assertEquals(Rotas.PUBLICAR_VAGA, rotaAtual())
            assertEquals("nova-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
            assertTrue(
                "o formulário concluído não pode ficar na pilha",
                nav.currentBackStack.value.none { it.destination.route == Rotas.CADASTRO_ESTABELECIMENTO },
            )
        }
    }

    @Test
    fun voltarDoCadastroDevolveATelaAnterior() {
        montar(servicoMembros = contratanteCom(), inicio = Rotas.CADASTRO_ESTABELECIMENTO)
        rule.waitForIdle()

        rule.onNodeWithContentDescription(TextosCadastroEstabelecimento.ROTULO_VOLTAR).performClick()

        rule.runOnIdle { assertEquals(Rotas.ENTRADA, rotaAtual()) }
    }

    // ---- Carga do estabelecimento na rota de publicação ----

    @Test
    fun publicarVagaDeQuemNaoEMembroMostraOMotivoESemTentarNovamente() {
        val membros = mockk<ServicoMembros> {
            coEvery { meuEstabelecimento(any()) } throws ErroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", null, "x")
        }
        montar(servicoMembros = membros, inicio = Rotas.publicarVaga("casa-9"))

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVagaDaRota.SEM_PERMISSAO).fetchSemanticsNodes().isNotEmpty() }

        rule.onAllNodesWithText("Tentar novamente").assertCountEquals(0)
        rule.onAllNodesWithText(TextosPublicarVaga.TITULO).assertCountEquals(0)
        assertTrue(casasRecebidas.isEmpty())
    }

    @Test
    fun falhaDeCargaOferecaTentarNovamenteEAbreOFormularioNaSegundaTentativa() {
        var chamadas = 0
        val membros = mockk<ServicoMembros> {
            coEvery { meuEstabelecimento(any()) } answers {
                if (++chamadas == 1) throw IllegalStateException("corpo não é JSON") else casaLida(firstArg())
            }
        }
        montar(servicoMembros = membros, inicio = Rotas.publicarVaga("casa-1"))

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVagaDaRota.FALHA).fetchSemanticsNodes().isNotEmpty() }
        assertTrue(casasRecebidas.isEmpty())
        rule.onNodeWithText("Tentar novamente").performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVaga.TITULO).fetchSemanticsNodes().isNotEmpty() }
        assertEquals(2, chamadas)
        assertEquals(1, casasRecebidas.size)
    }

    @Test
    fun publicarVagaSemServicoNoGrafoMostraAFalhaEmVezDeTravarNoSpinner() {
        montar(servicoMembros = null, inicio = Rotas.publicarVaga("casa-1"))

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosPublicarVagaDaRota.FALHA).fetchSemanticsNodes().isNotEmpty() }
        assertTrue(casasRecebidas.isEmpty())
    }

    // ---- Guarda biométrica (RN15) ----

    @Test
    fun comBiometriaAtivadaAsNovasRotasRedirecionamParaODesbloqueioSemLerAcasa() {
        biometria = true
        val membros = contratanteCom("casa-1")
        montar(servicoMembros = membros, inicio = Rotas.publicarVaga("casa-1"))
        rule.waitForIdle()

        rule.runOnIdle { assertEquals(Rotas.DESBLOQUEIO, rotaAtual()) }
        coVerify(exactly = 0) { membros.meuEstabelecimento(any()) }
        assertTrue(casasRecebidas.isEmpty())

        rule.runOnIdle { nav.navigate(Rotas.CADASTRO_ESTABELECIMENTO) }
        rule.waitForIdle()

        rule.runOnIdle { assertEquals(Rotas.DESBLOQUEIO, rotaAtual()) }
        rule.onAllNodesWithText(TextosCadastroEstabelecimento.TITULO).assertCountEquals(0)
    }

    // ---- Rotas ----

    @Test
    fun construtoresDeRotaMontamOCaminho() {
        assertEquals("publicar_vaga/casa-1", Rotas.publicarVaga("casa-1"))
        assertEquals("publicar_vaga/a%2Fb", Rotas.publicarVaga("a/b"))
        assertEquals("cadastro_estabelecimento", Rotas.CADASTRO_ESTABELECIMENTO)
        assertEquals("publicar_vaga/{estabelecimentoId}", Rotas.PUBLICAR_VAGA)
    }
}
