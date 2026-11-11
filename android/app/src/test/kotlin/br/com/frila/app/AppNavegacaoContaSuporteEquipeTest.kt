package br.com.frila.app

import android.app.Application
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.DenunciarDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.conta.TextosContaSuspensa
import br.com.frila.feature.conta.TextosExclusaoDeConta
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.TextosEquipe
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.TextosSuporte
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
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
 * Cartão i25gMr5D: as rotas de Conta, Suporte e Equipe existem no grafo de navegação e levam o que
 * a tela de origem sabe (estabelecimento, alvo, turno, chamada) até o ViewModel certo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoContaSuporteEquipeTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val intents = mutableListOf<Intent>()
    private val denuncias = mutableListOf<DenunciarDto>()
    private val equipesPedidas = mutableListOf<String>()
    private var exclusoes = 0
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val protocolo = ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17")

    private fun membros(vararg ids: String): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns ids.map { EstabelecimentoDaContaDto(id = it, nome = "Casa $it", papel = "administrador") }
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
            val origem = LocalContext.current
            val contexto = object : ContextWrapper(origem) {
                override fun startActivity(intent: Intent) {
                    intents += intent
                }
            }
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel {
                            ExclusaoDeContaViewModel(
                                excluir = { exclusoes++; ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 0) },
                                aoConcluir = { sessao.limparSessao() },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?) ->
                            DenunciaViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                denunciar = { corpo -> denuncias += corpo; protocolo },
                                bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
                                turnoId = turnoId,
                                chamadaId = chamadaId,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimentoId: String) ->
                            EquipeDeConfiancaViewModel(
                                estabelecimentoId = estabelecimentoId,
                                listar = { id -> equipesPedidas += id; emptyList() },
                                removerMembro = { _, _ -> error("não deveria remover") },
                                sair = { },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                CompositionLocalProvider(LocalContext provides contexto) {
                    nav = rememberNavController()
                    AppNavegacao(
                        armazenamentoDeSessao = sessao,
                        monitorDeConectividade = MonitorDeConectividadeFalso(),
                        navController = nav,
                        servicoMembros = servicoMembros,
                    )
                }
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    @Test
    fun excluirContaNoPerfilAbreATelaDedicadaEmVezDoDialogo() {
        montar(inicio = Rotas.PERFIL)

        rule.onNodeWithText("Excluir conta").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(Rotas.EXCLUSAO_DE_CONTA, rotaAtual()) }
        rule.onNodeWithText(TextosExclusaoDeConta.AVISO).assertExists()
    }

    @Test
    fun exclusaoConfirmadaLimpaASessaoEVaiParaAEntradaSemVoltar() {
        montar(inicio = Rotas.EXCLUSAO_DE_CONTA)

        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK).performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_CONFIRMAR).performClick()

        rule.waitForIdle()
        rule.runOnIdle {
            assertEquals(1, exclusoes)
            verify(exactly = 1) { sessao.limparSessao() }
            assertEquals(Rotas.ENTRADA, rotaAtual())
            assertNull("a exclusão não deixa tela autenticada para voltar", nav.previousBackStackEntry)
        }
    }

    @Test
    fun perfilDeQuemAdministraUmaCasaMostraAEquipeEAbreComOIdDaCasa() {
        montar(servicoMembros = membros("casa-1", "casa-2"), inicio = Rotas.PERFIL)

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-equipe").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithTag("perfil-equipe").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.EQUIPE, rotaAtual())
            assertEquals("casa-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
        rule.waitUntil(5_000) { equipesPedidas.isNotEmpty() }
        assertEquals(listOf("casa-1"), equipesPedidas)
        rule.onNodeWithText(TextosEquipe.VAZIO_TITULO).assertExists()
    }

    @Test
    fun perfilDeProfissionalOuSemServicoNaoMostraAEquipe() {
        montar(servicoMembros = profissional(), inicio = Rotas.PERFIL)
        rule.waitForIdle()
        rule.onAllNodesWithTag("perfil-equipe").assertCountEquals(0)
    }

    @Test
    fun perfilSemServicoDeMembrosNaoMostraAEquipe() {
        montar(servicoMembros = null, inicio = Rotas.PERFIL)
        rule.waitForIdle()
        rule.onAllNodesWithTag("perfil-equipe").assertCountEquals(0)
    }

    @Test
    fun rotaDeDenunciaLevaAlvoTurnoEChamadaAoViewModelEEnviaOCorpoCerto() {
        montar(inicio = Rotas.denuncia(TipoDeAlvo.ESTABELECIMENTO, "est-9", turnoId = "turno-3", chamadaId = "chamada-4"))

        rule.onNodeWithText(TextosSuporte.ASSOCIADA_AO_TURNO).performScrollTo().assertExists()
        rule.onNodeWithText(TextosSuporte.ASSOCIADA_A_CHAMADA).performScrollTo().assertExists()
        rule.onNode(androidx.compose.ui.test.hasSetTextAction()).performTextInput("Relato com mais de dez caracteres.")
        rule.onNodeWithText(TextosSuporte.ENVIAR).performScrollTo().performClick()

        rule.runOnIdle {
            val corpo = denuncias.single()
            assertEquals("estabelecimento", corpo.alvoTipo)
            assertEquals("est-9", corpo.alvoId)
            assertEquals("turno-3", corpo.turnoId)
            assertEquals("chamada-4", corpo.chamadaId)
        }
        rule.onNodeWithText(TextosSuporte.ENVIADA).assertExists()
    }

    @Test
    fun denunciaSemAssociacaoNaoMostraAvisoENaoManda() {
        montar(inicio = Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, "prof-1"))

        rule.onNodeWithText(TextosSuporte.ASSOCIADA_AO_TURNO).assertDoesNotExist()
        rule.onNodeWithText(TextosSuporte.ASSOCIADA_A_CHAMADA).assertDoesNotExist()
        rule.onNode(androidx.compose.ui.test.hasSetTextAction()).performTextInput("Relato com mais de dez caracteres.")
        rule.onNodeWithText(TextosSuporte.ENVIAR).performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals("profissional", denuncias.single().alvoTipo)
            assertNull(denuncias.single().turnoId)
            assertNull(denuncias.single().chamadaId)
        }
    }

    @Test
    fun denunciaComTipoDeAlvoForaDoContratoVoltaSemMontarATela() {
        montar(inicio = "denuncia/invalido/abc")

        rule.waitForIdle()
        rule.runOnIdle { assertEquals(Rotas.ENTRADA, rotaAtual()) }
        rule.onNodeWithText(TextosSuporte.ENVIAR).assertDoesNotExist()
    }

    @Test
    fun ligarParaEmergenciaDaDenunciaAbreODiscadorComONumero() {
        montar(inicio = Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, "prof-1"))

        rule.onNodeWithText(TextosSuporte.LIGAR_190).performClick()

        rule.runOnIdle {
            val discagem = intents.single { it.action == Intent.ACTION_DIAL }
            assertEquals("tel:190", discagem.data.toString())
        }
    }

    @Test
    fun contaSuspensaMostraMotivoEDataDaRotaEOSuporteAbreOEmail() {
        montar(inicio = Rotas.contaSuspensa(motivo = "Assédio confirmado", desde = "09/11/2026"))

        rule.onNodeWithText(TextosContaSuspensa.TITULO).assertExists()
        rule.onNodeWithText("Assédio confirmado").assertExists()
        rule.onNodeWithText("09/11/2026").assertExists()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SUPORTE).performScrollTo().performClick()

        rule.runOnIdle {
            val email = intents.single { it.action == Intent.ACTION_SENDTO }
            assertEquals("mailto:suporte@frilabr.com", email.data.toString())
        }
    }

    @Test
    fun contaSuspensaSemParametrosAbreSemSecaoDeMotivo() {
        montar(inicio = Rotas.contaSuspensa())

        rule.onNodeWithText(TextosContaSuspensa.TITULO).assertExists()
        rule.onNodeWithText(TextosContaSuspensa.SECAO_MOTIVO).assertDoesNotExist()
    }

    @Test
    fun sairDaContaSuspensaLimpaASessaoEVaiParaAEntrada() {
        montar(inicio = Rotas.contaSuspensa())

        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SAIR).performScrollTo().performClick()

        rule.runOnIdle {
            verify(exactly = 1) { sessao.limparSessao() }
            assertEquals(Rotas.ENTRADA, rotaAtual())
        }
    }

    @Test
    fun construtoresDeRotaCodificamOsParametros() {
        assertEquals("conta_suspensa", Rotas.contaSuspensa())
        assertEquals("conta_suspensa?motivo=Ass%C3%A9dio%20e%20mais&desde=09%2F11%2F2026", Rotas.contaSuspensa("Assédio e mais", "09/11/2026"))
        assertEquals("denuncia/profissional/p1", Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, "p1"))
        assertEquals("denuncia/estabelecimento/e1?turnoId=t1&chamadaId=c1", Rotas.denuncia(TipoDeAlvo.ESTABELECIMENTO, "e1", "t1", "c1"))
        assertEquals("denuncia/profissional/p1?chamadaId=c1", Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, "p1", chamadaId = "c1"))
        assertEquals("equipe/casa-1", Rotas.equipe("casa-1"))
        assertTrue(Rotas.EXCLUSAO_DE_CONTA.isNotEmpty())
    }
}
