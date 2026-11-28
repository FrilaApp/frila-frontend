package br.com.frila.app

import android.app.Application
import android.net.Uri
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.EditarServicosViewModel
import br.com.frila.feature.chamadas.profissional.PreferenciasChamadaViewModel
import br.com.frila.feature.chamadas.profissional.TextosChamadaProfissional
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import io.mockk.coEvery
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Chamada direta, lado do profissional (0.2.88): o atalho do Perfil só existe com a chave `chamada_direta`, e as rotas
 * levam a tela certa com o que a origem sabe (id da chamada, deep link).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoChamadaProfissionalTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val chamadasPedidas = mutableListOf<String>()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val perfil: PerfilProfissionalDetalhadoDto = ClienteSupabase.jsonFrila.decodeFromString(
        """{"id":"22222222-2222-2222-2222-222222222222","usuario_id":"88888888-8888-8888-8888-888888888888","funcoes":[],"disponibilidades":[],"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0},"cursos":[],"idiomas":[],"servicos":[],"regioes":[],"atende_todo_df":false,"preferencia_chamadas":{"aceita_de_quem_ja_trabalhou":true,"antecedencia_minima_h":6,"aceita_de":"todos","pendencias_para_busca":[]}}""",
    )

    private fun detalhe(id: String): ChamadaDetalheDto = ClienteSupabase.jsonFrila.decodeFromString(
        """{"id":"$id","vaga_id":"v","profissional_id":"p","estabelecimento_id":"c","estado":"aberta","expira_em":"2099-01-01T12:00:00Z","criada_em":"2026-11-16T20:00:00Z","funcao":{"id":"f","nome":"Garçom","categoria":"salao"},"inicio_em":"2099-01-02T22:00:00Z","fim_em":"2099-01-03T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"c","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},"regiao_administrativa":"Plano Piloto","inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false}""",
    )

    private fun montar(
        chamadaDireta: Boolean,
        inicio: String? = null,
        busca: Boolean = true,
        servicoMembros: ServicoMembros? = null,
    ) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfilVm = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { perfilVm }
                        viewModel {
                            PreferenciasChamadaViewModel(
                                carregarPerfil = { perfil },
                                definirPreferencias = { error("não deveria salvar") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel {
                            EditarServicosViewModel(
                                carregarPerfil = { perfil },
                                listarEspecialidades = { emptyList() },
                                definir = { error("não deveria salvar") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        // GpINsbhj: a chamada recebida oferece Denunciar e Bloquear, e a rota pede o bloqueio avulso ao grafo.
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String) ->
                            BloqueioDeAlvoViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (chamadaId: String) ->
                            ChamadaRecebidaViewModel(
                                chamadaId = chamadaId,
                                detalhar = { id -> chamadasPedidas += id; detalhe(id) },
                                responder = { _, _, _ -> error("não deveria responder") },
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
                    chamadaDiretaHabilitada = chamadaDireta,
                    buscaProfissionaisHabilitada = busca,
                    servicoMembros = servicoMembros,
                )
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    @Test
    fun comAChaveLigadaOPerfilDoProfissionalMostraOAtalhoEAbreAsPreferencias() {
        montar(chamadaDireta = true, inicio = Rotas.PERFIL)

        rule.onNodeWithTag("perfil-chamadas-diretas").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(RotasChamadaProfissional.PREFERENCIAS, rotaAtual()) }
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertExists()
    }

    @Test
    fun contratanteComCasaENaChaveLigadaNaoVeOAtalhoDasPreferenciasDeChamada() {
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } returns
                listOf(EstabelecimentoDaContaDto(id = "casa-1", nome = "Casa 1", papel = "administrador"))
        }
        montar(chamadaDireta = true, inicio = Rotas.PERFIL, servicoMembros = membros)
        rule.waitForIdle()
        rule.onAllNodesWithTag("perfil-chamadas-diretas").assertCountEquals(0)
    }

    @Test
    fun contratanteSemCasaNaChaveLigadaTambemNaoVeOAtalho() {
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } returns emptyList()
        }
        montar(chamadaDireta = true, inicio = Rotas.PERFIL, servicoMembros = membros)
        rule.waitForIdle()
        rule.onAllNodesWithTag("perfil-chamadas-diretas").assertCountEquals(0)
    }

    @Test
    fun profissionalQueRecebePerfilIncompativelDaListaDeCasasVeOAtalho() {
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } throws
                ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
        }
        montar(chamadaDireta = true, inicio = Rotas.PERFIL, servicoMembros = membros)
        rule.waitForIdle()
        rule.onNodeWithTag("perfil-chamadas-diretas").performScrollTo().assertExists()
    }

    @Test
    fun comAChaveDesligadaNadaApareceNoPerfil() {
        montar(chamadaDireta = false, inicio = Rotas.PERFIL)
        rule.waitForIdle()
        rule.onAllNodesWithTag("perfil-chamadas-diretas").assertCountEquals(0)
    }

    @Test
    fun preferenciasSemAChaveDaBuscaNaoMostramAceitoChamadasMasMostramOResto() {
        montar(chamadaDireta = true, inicio = RotasChamadaProfissional.PREFERENCIAS, busca = false)

        rule.onNodeWithText(TextosChamadaProfissional.PAUSAR_CHAMADAS).assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertDoesNotExist()
        rule.onAllNodesWithTag("chave-aceita-chamadas").assertCountEquals(0)
        rule.onNodeWithTag("editar-servicos").performScrollTo().assertExists()
    }

    @Test
    fun semAChaveDaBuscaOAtalhoDeServicosAindaLevaAosServicos() {
        montar(chamadaDireta = true, inicio = RotasChamadaProfissional.PREFERENCIAS, busca = false)

        rule.onNodeWithTag("editar-servicos").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(RotasChamadaProfissional.SERVICOS, rotaAtual()) }
    }

    @Test
    fun preferenciasComAChaveDaBuscaMostramAceitoChamadas() {
        montar(chamadaDireta = true, inicio = RotasChamadaProfissional.PREFERENCIAS, busca = true)

        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertExists()
    }

    @Test
    fun dasPreferenciasOAtalhoLevaAosServicos() {
        montar(chamadaDireta = true, inicio = RotasChamadaProfissional.PREFERENCIAS)

        rule.onNodeWithTag("editar-servicos").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(RotasChamadaProfissional.SERVICOS, rotaAtual()) }
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_EXPLICACAO).assertExists()
    }

    @Test
    fun rotaDaChamadaRecebidaLevaOIdAoViewModelEMostraAChamada() {
        montar(chamadaDireta = true, inicio = RotasChamadaProfissional.recebida("chamada-7"))

        rule.waitUntil(5_000) { chamadasPedidas.isNotEmpty() }
        assertEquals(listOf("chamada-7"), chamadasPedidas)
        rule.onNodeWithText("Bistrô Aurora").assertExists()
        rule.onNodeWithTag("aceitar-chamada").assertExists()
    }

    @Test
    fun linkFrilaChamadasAbreAChamadaRecebida() {
        montar(chamadaDireta = true, inicio = Rotas.PERFIL)

        rule.runOnIdle { nav.navigate(Uri.parse("frila://chamadas/chamada-9")) }

        rule.waitUntil(5_000) { chamadasPedidas.isNotEmpty() }
        rule.runOnIdle {
            assertEquals(RotasChamadaProfissional.RECEBIDA, rotaAtual())
            assertEquals(listOf("chamada-9"), chamadasPedidas)
        }
    }
}
