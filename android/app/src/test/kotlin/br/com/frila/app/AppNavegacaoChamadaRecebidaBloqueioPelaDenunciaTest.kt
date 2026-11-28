package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.TextosChamadaProfissional
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.TextosSuporte
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
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
 * xsZd5wZO: o profissional bloqueia a casa pela Denúncia aberta a partir da chamada recebida e volta. A chamada precisa saber que a casa
 * foi bloqueada (o conjunto da sessão) e o recarregar recebe 404 (RF26): sem Aceitar, Recusar nem Bloquear, e com o aviso.
 * O servidor é simulado pela flag [casaBloqueadaNoServidor], ligada pelo mesmo pedido de bloqueio que a Denúncia faz.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoChamadaRecebidaBloqueioPelaDenunciaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessaoDeBloqueios = BloqueiosDaSessao()
    private var casaBloqueadaNoServidor = false
    /** Quando preenchido, o pedido de bloqueio fica em voo até o teste liberar. */
    private var portao: CompletableDeferred<Unit>? = null
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun detalhe(id: String): ChamadaDetalheDto = ClienteSupabase.jsonFrila.decodeFromString(
        """{"id":"$id","vaga_id":"v","profissional_id":"p","estabelecimento_id":"c","estado":"aberta","expira_em":"2099-01-01T12:00:00Z","criada_em":"2026-11-16T20:00:00Z","funcao":{"id":"f","nome":"Garçom","categoria":"salao"},"inicio_em":"2099-01-02T22:00:00Z","fim_em":"2099-01-03T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"casa-7","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},"regiao_administrativa":"Plano Piloto","inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false}""",
    )

    private val bloquearComRegistro: suspend (String, String) -> BloqueioDto = { tipo, id ->
        sessaoDeBloqueios.registrandoAposSucesso(tipo, id) {
            portao?.await()
            casaBloqueadaNoServidor = true
            BloqueioDto(tipo, id, "2026-11-10T12:00:00Z")
        }
    }

    private fun montar() {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        single { sessaoDeBloqueios }
                        viewModel { entrada }
                        viewModel { (chamadaId: String) ->
                            ChamadaRecebidaViewModel(
                                chamadaId = chamadaId,
                                detalhar = { id ->
                                    if (casaBloqueadaNoServidor) throw ErroDaApi(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado", null, "x")
                                    detalhe(id)
                                },
                                responder = { _, _, _ -> error("nao deveria responder") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?, fotoId: String?) ->
                            DenunciaViewModel(
                                alvoTipo = alvoTipo, alvoId = alvoId,
                                denunciar = { ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17") },
                                bloquear = bloquearComRegistro,
                                turnoId = turnoId, chamadaId = chamadaId, fotoId = fotoId,
                                bloqueios = sessaoDeBloqueios,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String) ->
                            BloqueioDeAlvoViewModel(
                                alvoTipo = alvoTipo, alvoId = alvoId, bloquear = bloquearComRegistro,
                                bloqueios = sessaoDeBloqueios, escopo = CoroutineScope(Dispatchers.Unconfined),
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
                    chamadaDiretaHabilitada = true,
                    buscaProfissionaisHabilitada = true,
                )
            }
        }
        rule.runOnIdle { nav.navigate(RotasChamadaProfissional.recebida("chamada-7")) }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("aceitar-chamada").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun bloquearPelaDenunciaEVoltar() {
        rule.onNodeWithTag("chamada-denunciar").performScrollTo().performClick()
        rule.runOnIdle { assertEquals(Rotas.DENUNCIA, nav.currentDestination?.route) }
        rule.onNodeWithText(TextosSuporte.BLOQUEAR).performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()
        rule.waitUntil(5_000) { sessaoDeBloqueios.contem(TipoDeAlvo.ESTABELECIMENTO, "casa-7") }
        rule.runOnUiThread { nav.popBackStack() }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("chamada-denunciar").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `bloquear a casa pela Denuncia e voltar tira Aceitar, Recusar e Bloquear, e mostra o aviso`() {
        montar()

        bloquearPelaDenunciaEVoltar()

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("aceitar-chamada").fetchSemanticsNodes().isEmpty() }
        rule.onAllNodesWithTag("aceitar-chamada").assertCountEquals(0)
        rule.onAllNodesWithTag("recusar-chamada").assertCountEquals(0)
        rule.onAllNodesWithTag("chamada-bloquear").assertCountEquals(0)
        rule.onNodeWithTag("chamada-bloqueado").performScrollTo().assertIsDisplayed()
        assertTrue(sessaoDeBloqueios.contem(TipoDeAlvo.ESTABELECIMENTO, "casa-7"))
    }

    @Test
    fun `o 404 do recarregar explica que a chamada ja nao se responde`() {
        montar()

        bloquearPelaDenunciaEVoltar()

        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosChamadaProfissional.INDISPONIVEL).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(TextosChamadaProfissional.INDISPONIVEL).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithTag("aceitar-chamada").assertCountEquals(0)
    }

    @Test
    fun `durante o pedido de bloqueio Aceitar e Recusar ficam desligados, e depois dele somem`() {
        portao = CompletableDeferred()
        montar()
        rule.onNodeWithTag("aceitar-chamada").assertIsEnabled()

        rule.onNodeWithTag("chamada-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        rule.onNodeWithTag("aceitar-chamada").assertIsNotEnabled()
        rule.onNodeWithTag("recusar-chamada").assertIsNotEnabled()

        portao!!.complete(Unit)
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("aceitar-chamada").fetchSemanticsNodes().isEmpty() }
        rule.onNodeWithTag("chamada-bloqueado").performScrollTo().assertIsDisplayed()
    }
}
