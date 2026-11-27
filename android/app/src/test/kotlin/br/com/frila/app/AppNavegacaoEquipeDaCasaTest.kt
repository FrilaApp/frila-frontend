package br.com.frila.app

import android.app.Application
import android.content.Intent
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.designsystem.componentes.TextosConfirmarSaida
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.AdministracaoTransferidaDto
import br.com.frila.core.rede.ConviteMembroDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MembroAdicionadoDto
import br.com.frila.core.rede.MembroDoEstabelecimentoDto
import br.com.frila.core.rede.MembroRemovidoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.casa.EquipeDaCasaViewModel
import br.com.frila.feature.equipe.casa.TenhoUmConviteViewModel
import br.com.frila.feature.equipe.casa.TextosEquipeDaCasa
import br.com.frila.feature.equipe.casa.TrocarDeCasaViewModel
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
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
import org.robolectric.Shadows.shadowOf
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Pedido 18-02: equipe da casa, "Tenho um convite" e trocar de casa no grafo. As linhas do Perfil só aparecem para quem
 * pode usá-las (a equipe é do administrador), o link do convite sai pela folha do sistema e aceitar um convite abre a casa.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoEquipeDaCasaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val token = "ef".repeat(32)
    private val remocoes = mutableListOf<String>()
    private val aceitos = mutableListOf<String>()
    private val vagasAbertasDe = mutableListOf<String>()
    // Sem sessão guardada: o grafo abre na Entrada, como nos outros testes; o aviso de sessão encerrada vale por isso.
    private val autenticado = false
    private val encerramentos = MutableStateFlow(0)
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } answers { autenticado }
        every { isBiometriaAtivada() } returns false
    }
    private var papelAoAceitar = "operador"

    private fun casa(id: String, papel: String = "administrador") = EstabelecimentoDaContaDto(id = id, nome = "Casa $id", papel = papel)

    private fun membrosDe(vararg casas: EstabelecimentoDaContaDto): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns casas.toList()
    }

    private fun montar(servicoMembros: ServicoMembros?, inicio: String) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO)) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { (estabelecimentoId: String, papel: PapelMembro?) ->
                            EquipeDaCasaViewModel(
                                estabelecimentoId = estabelecimentoId,
                                papel = papel,
                                listar = {
                                    listOf(
                                        MembroDoEstabelecimentoDto("m-ana", "Ana Souza", "administrador", "2026-10-01T12:00:00Z", true),
                                        MembroDoEstabelecimentoDto("m-beto", "Beto Lima", "operador", "2026-11-02T09:30:00Z", false),
                                    )
                                },
                                convidar = { id, email, p -> ConviteMembroDto("c1", token, "2026-11-25T15:00:00Z", id, email, p) },
                                remover = { id, membro -> remocoes += membro; MembroRemovidoDto("membro_removido", true, id, membro) },
                                transferir = { id, novo -> AdministracaoTransferidaDto("administracao_transferida", id, novo, null, "administrador") },
                                montarLink = EnderecosOficiais.padrao::linkDoConvite,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel {
                            TenhoUmConviteViewModel(
                                aceitar = { aceitos += it; MembroAdicionadoDto("membro_adicionado", "m1", "casa-nova", "u1", papelAoAceitar) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel {
                            TrocarDeCasaViewModel(
                                listar = { listOf(casa("casa-1"), casa("casa-2", "operador")) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimentoId: String, nome: String?, recemPublicadaId: String?) ->
                            vagasAbertasDe += estabelecimentoId
                            MinhasVagasViewModel(
                                estabelecimentoId = estabelecimentoId,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recemPublicadaId,
                                buscarPainel = { id, _, _ -> Result.success(PainelDto(id, emptyList(), emptyList())) },
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
                    biometriaHabilitada = true,
                    servicoMembros = servicoMembros,
                    encerramentosDaSessao = encerramentos,
                )
            }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    private fun esperarTag(tag: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun esperarTexto(texto: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty() }
    }

    // ---- Linhas do Perfil ----

    @Test
    fun administradorDeUmaCasaVeEquipeEConviteMasNaoTrocarDeCasa() {
        montar(membrosDe(casa("casa-1")), Rotas.PERFIL)

        esperarTag(ENTRADA_EQUIPE_DA_CASA)
        rule.onNodeWithTag(ENTRADA_TENHO_UM_CONVITE).assertExists()
        rule.onAllNodesWithTag(ENTRADA_TROCAR_DE_CASA).assertCountEquals(0)
    }

    @Test
    fun operadorNaoVeAEquipeDaCasaMasVeOConvite() {
        montar(membrosDe(casa("casa-1", "operador")), Rotas.PERFIL)

        esperarTag(ENTRADA_TENHO_UM_CONVITE)
        rule.onAllNodesWithTag(ENTRADA_EQUIPE_DA_CASA).assertCountEquals(0)
    }

    @Test
    fun quemTemDuasCasasVeTrocarDeCasa() {
        montar(membrosDe(casa("casa-1"), casa("casa-2", "operador")), Rotas.PERFIL)

        esperarTag(ENTRADA_TROCAR_DE_CASA)
    }

    @Test
    fun contratanteSemCasaVeSoOConvite() {
        montar(membrosDe(), Rotas.PERFIL)

        esperarTag(ENTRADA_TENHO_UM_CONVITE)
        rule.onAllNodesWithTag(ENTRADA_EQUIPE_DA_CASA).assertCountEquals(0)
        rule.onAllNodesWithTag(ENTRADA_TROCAR_DE_CASA).assertCountEquals(0)
    }

    @Test
    fun profissionalNaoVeNenhumaDasTres() {
        val profissional = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } throws ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
        }
        montar(profissional, Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag(ENTRADA_EQUIPE_DA_CASA).assertCountEquals(0)
        rule.onAllNodesWithTag(ENTRADA_TENHO_UM_CONVITE).assertCountEquals(0)
        rule.onAllNodesWithTag(ENTRADA_TROCAR_DE_CASA).assertCountEquals(0)
    }

    // ---- Equipe da casa ----

    @Test
    fun linhaDaEquipeAbreARotaDaCasaEMostraAListaParaOAdministrador() {
        montar(membrosDe(casa("casa-1")), Rotas.PERFIL)
        esperarTag(ENTRADA_EQUIPE_DA_CASA)

        rule.onNodeWithTag(ENTRADA_EQUIPE_DA_CASA).performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.EQUIPE_DA_CASA, nav.currentDestination?.route)
            assertEquals("casa-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
        esperarTexto("Beto Lima")
        rule.onNodeWithText("Casa casa-1").assertExists()
    }

    @Test
    fun operadorQueChegaARotaDaEquipeVeSoOAvisoSemBotao() {
        montar(membrosDe(casa("casa-1", "operador")), Rotas.equipeDaCasa("casa-1"))

        esperarTexto(TextosEquipeDaCasa.SO_ADMINISTRADOR)
        rule.onAllNodesWithText(TextosEquipeDaCasa.GERAR_CONVITE).assertCountEquals(0)
        rule.onAllNodesWithText("Beto Lima").assertCountEquals(0)
    }

    @Test
    fun casaQueAContaNaoTemMostraOMotivoESemTentarNovamente() {
        montar(membrosDe(casa("casa-1")), Rotas.equipeDaCasa("casa-9"))

        esperarTexto(TextosEquipeDaCasa.ROTA_NAO_E_MEMBRO)
        rule.onAllNodesWithText("Tentar novamente").assertCountEquals(0)
    }

    @Test
    fun falhaDeCargaOferecaTentarNovamente() {
        var chamadas = 0
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } answers { if (++chamadas == 1) throw IllegalStateException("corpo não é JSON") else listOf(casa("casa-1")) }
        }
        montar(membros, Rotas.equipeDaCasa("casa-1"))

        esperarTexto(TextosEquipeDaCasa.ROTA_FALHA)
        rule.onAllNodesWithText("Tentar novamente")[0].performClick()

        esperarTexto("Beto Lima")
        assertEquals(2, chamadas)
    }

    @Test
    fun conviteGeradoSaiPelaFolhaDeCompartilharDoSistemaComOLinkDaWeb() {
        montar(membrosDe(casa("casa-1")), Rotas.equipeDaCasa("casa-1"))
        esperarTexto(TextosEquipeDaCasa.GERAR_CONVITE)

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("novo@bar.com")
        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.COMPARTILHAR).performScrollTo().performClick()

        val aberta = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
        assertEquals(Intent.ACTION_CHOOSER, aberta.action)
        @Suppress("DEPRECATION")
        val envio = aberta.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, envio.action)
        assertEquals("text/plain", envio.type)
        val link = "https://frilabr.com/app/convite#$token"
        val esperado =
            "Casa casa-1 convidou você para a equipe da casa no Frila, como operador. " +
                "Para aceitar, abra o link abaixo e entre no Frila com o e-mail novo@bar.com. " +
                "O convite vale uma vez, até 25/11 às 12:00. " +
                "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. " +
                "Política de Privacidade: https://frilabr.com/privacidade\n" +
                link
        assertEquals(esperado, envio.getStringExtra(Intent.EXTRA_TEXT))
    }

    // ---- Tenho um convite ----

    @Test
    fun linhaDoConviteAbreATelaEAceitarLevaAOVagasDaNovaCasa() {
        montar(membrosDe(), Rotas.PERFIL)
        esperarTag(ENTRADA_TENHO_UM_CONVITE)
        rule.onNodeWithTag(ENTRADA_TENHO_UM_CONVITE).performScrollTo().performClick()

        esperarTexto(TextosEquipeDaCasa.CONVITE_EXPLICACAO)
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput("https://frilabr.com/app/convite#$token")
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()
        esperarTexto(TextosEquipeDaCasa.CONVITE_ABRIR_CASA)
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ABRIR_CASA).performClick()

        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.MINHAS_VAGAS }
        rule.runOnIdle {
            assertEquals(listOf(token), aceitos)
            assertEquals("casa-nova", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
            assertEquals(listOf("casa-nova"), vagasAbertasDe)
            // A tela de convite e o perfil que a abriu saem da pilha: voltar não reabre o convite já aceito.
            assertTrue(nav.currentBackStack.value.none { it.destination.route == Rotas.TENHO_UM_CONVITE })
        }
    }

    // ---- Trocar de casa ----

    @Test
    fun escolherOutraCasaAbreAsVagasDelaETrocaAEquipeDoPerfil() {
        montar(membrosDe(casa("casa-1"), casa("casa-2", "operador")), Rotas.PERFIL)
        esperarTag(ENTRADA_TROCAR_DE_CASA)
        rule.onNodeWithTag(ENTRADA_TROCAR_DE_CASA).performScrollTo().performClick()

        esperarTexto("Casa casa-2")
        rule.onNodeWithText("Casa casa-2").performClick()

        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.MINHAS_VAGAS }
        rule.runOnIdle { assertEquals("casa-2", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId")) }
    }

    @Test
    fun comBiometriaAtivadaAsNovasRotasRedirecionamParaODesbloqueio() {
        every { sessao.isBiometriaAtivada() } returns true
        montar(membrosDe(casa("casa-1")), Rotas.equipeDaCasa("casa-1"))
        rule.waitForIdle()

        rule.runOnIdle { assertEquals(Rotas.DESBLOQUEIO, nav.currentDestination?.route) }
    }

    // ---- A casa escolhida não sobrevive à saída da conta (parecer do Lince Opus no #998) ----

    private fun trocarParaCasa2NoPerfil() {
        esperarTag(ENTRADA_TROCAR_DE_CASA)
        rule.onNodeWithTag(ENTRADA_TROCAR_DE_CASA).performScrollTo().performClick()
        esperarTexto("Casa casa-2")
        rule.onNodeWithText("Casa casa-2").performClick()
        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.MINHAS_VAGAS }
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }
        esperarTag(ENTRADA_PUBLICAR_ESCALA)
    }

    /** A linha "Publicar escala do evento" do Perfil aponta para a casa em uso; abre a rota e devolve o id que ela recebeu. */
    private fun casaDaEscalaNoPerfil(): String? {
        esperarTag(ENTRADA_PUBLICAR_ESCALA)
        rule.onNodeWithTag(ENTRADA_PUBLICAR_ESCALA).performScrollTo().performClick()
        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.PUBLICAR_ESCALA }
        var id: String? = null
        rule.runOnIdle { id = nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId") }
        return id
    }

    @Test
    fun sairDaContaEEntrarDeNovoVoltaParaACasaPadraoDoServidor() {
        montar(membrosDe(casa("casa-1"), casa("casa-2", "operador")), Rotas.PERFIL)
        trocarParaCasa2NoPerfil()
        assertEquals("casa-2", casaDaEscalaNoPerfil())
        rule.runOnIdle { nav.popBackStack() }

        rule.onNodeWithText("Sair da conta").performScrollTo().performClick()
        rule.onNodeWithTag(TextosConfirmarSaida.TAG_SAIR).performClick()
        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.ENTRADA }
        // Entra de novo (a abertura decide a casa pelo servidor) e cai no Perfil.
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }

        assertEquals("casa-1", casaDaEscalaNoPerfil())
    }

    @Test
    fun sessaoQueVenceVoltaParaACasaPadraoDoServidor() {
        montar(membrosDe(casa("casa-1"), casa("casa-2", "operador")), Rotas.PERFIL)
        trocarParaCasa2NoPerfil()
        assertEquals("casa-2", casaDaEscalaNoPerfil())
        rule.runOnIdle { nav.popBackStack() }

        rule.runOnIdle { encerramentos.value += 1 }
        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.ENTRADA }
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }

        assertEquals("casa-1", casaDaEscalaNoPerfil())
    }
}
