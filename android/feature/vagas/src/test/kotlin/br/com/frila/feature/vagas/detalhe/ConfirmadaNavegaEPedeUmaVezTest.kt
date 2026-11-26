package br.com.frila.feature.vagas.detalhe

import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.core.app.ActivityOptionsCompat
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão w80p76Ur (follow-up do #1064/#1065). O ramo CONFIRMADA do efeito do detalhe da vaga faz duas coisas por candidatura
 * confirmada: navega para a tela de turno confirmado e, se a permissão de notificação falta, abre o diálogo que leva ao pedido
 * do sistema. Este teste conta, por candidatura, as navegações, as consultas de permissão (cada uma abre um diálogo), os diálogos
 * visíveis e os pedidos de permissão ao sistema, quando o efeito reentra: recomposição, a tela sair e voltar com o mesmo
 * `DetalheVagaViewModel` (o `popBackStack` do destino) e a recriação da Activity (rotação).
 *
 * Nos testes que dizem "sem a trava da sessão", `jaPediuNaSessao`/`marcarPediuNaSessao` ficam desligados de propósito: a trava de
 * "já pediu nesta sessão" esconderia uma segunda consulta, e o que se quer provar é que o consumo atômico do evento, sozinho,
 * segura o ramo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ConfirmadaNavegaEPedeUmaVezTest {

    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() {
        ControleSessaoNotificacao.resetarParaTestes()
    }

    private val confirmada = """
        {
          "estado": "confirmada",
          "candidatura_id": "c1",
          "posicao_id": "p1",
          "turno_id": "t1",
          "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
        }
    """.trimIndent()

    private fun criarVaga() = VagaAbertaDto(
        id = "11111111-1111-1111-1111-111111111111",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 7, total = 7, taxaComparecimento = 1.0, turnosConsiderados = 7, turnosRealizados = 7),
        ),
        inicioEm = "2026-11-01T21:00:00Z",
        fimEm = "2026-11-02T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 4.2,
        valorCentavos = 16_000,
        posicoesAbertas = 2,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    private fun criarViewModel(): DetalheVagaViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(content = confirmada, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return DetalheVagaViewModel(vaga = criarVaga(), servicoVagas = ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    /** Contadores do que o ramo CONFIRMADA faz por candidatura. */
    private class Contagem {
        var navegacoes = 0
        var consultasDePermissao = 0
        var pedidosAoSistema = 0
    }

    private fun registroQueConta(contagem: Contagem) = object : ActivityResultRegistryOwner {
        override val activityResultRegistry = object : ActivityResultRegistry() {
            override fun <I, O> onLaunch(
                requestCode: Int,
                contract: ActivityResultContract<I, O>,
                input: I,
                options: ActivityOptionsCompat?,
            ) {
                contagem.pedidosAoSistema++
                dispatchResult(requestCode, true)
            }
        }
    }

    @androidx.compose.runtime.Composable
    private fun Tela(viewModel: DetalheVagaViewModel, contagem: Contagem, comTravaDaSessao: Boolean) {
        CompositionLocalProvider(
            androidx.activity.compose.LocalActivityResultRegistryOwner provides registroQueConta(contagem),
        ) {
            FrilaTheme {
                if (comTravaDaSessao) {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        verificarPermissaoNotificacao = { contagem.consultasDePermissao++; false },
                        aoNavegarParaConfirmada = { _, _ -> contagem.navegacoes++ },
                    )
                } else {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        verificarPermissaoNotificacao = { contagem.consultasDePermissao++; false },
                        jaPediuNaSessao = { false },
                        marcarPediuNaSessao = {},
                        aoNavegarParaConfirmada = { _, _ -> contagem.navegacoes++ },
                    )
                }
            }
        }
    }

    private fun confereContagem(contagem: Contagem, navegacoes: Int, consultas: Int, pedidos: Int) =
        assertEquals(
            "navegações, consultas de permissão (cada uma abre um diálogo) e pedidos ao sistema",
            listOf(navegacoes, consultas, pedidos),
            listOf(contagem.navegacoes, contagem.consultasDePermissao, contagem.pedidosAoSistema),
        )

    private fun dialogosVisiveis() = compose.onAllNodesWithTag("dialogo-permissao-notificacao")

    @Test
    fun `uma candidatura confirmada navega uma vez e abre um dialogo, sem a trava da sessao`() {
        runBlocking {
            val viewModel = criarViewModel()
            val contagem = Contagem()
            compose.setContent { Tela(viewModel, contagem, comTravaDaSessao = false) }

            viewModel.candidatar().join()
            compose.waitForIdle()

            confereContagem(contagem, navegacoes = 1, consultas = 1, pedidos = 0)
            dialogosVisiveis().assertCountEquals(1)
        }
    }

    @Test
    fun `a tela sair e voltar com o mesmo view model nao repete navegacao nem pedido, sem a trava da sessao`() {
        runBlocking {
            val viewModel = criarViewModel()
            val contagem = Contagem()
            var naTela by mutableStateOf(true)
            compose.setContent { if (naTela) Tela(viewModel, contagem, comTravaDaSessao = false) }

            viewModel.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("botao-agora-nao-notificacoes").performClick()
            compose.waitForIdle()

            // popBackStack: o destino de turno confirmado fecha e o detalhe volta a compor, com o estado ainda CONFIRMADA.
            compose.runOnIdle { naTela = false }
            compose.waitForIdle()
            compose.runOnIdle { naTela = true }
            compose.waitForIdle()

            confereContagem(contagem, navegacoes = 1, consultas = 1, pedidos = 0)
            dialogosVisiveis().assertCountEquals(0)
        }
    }

    @Test
    fun `a rotacao nao repete navegacao nem pedido e mantem um unico dialogo, sem a trava da sessao`() {
        runBlocking {
            val viewModel = criarViewModel()
            val contagem = Contagem()
            val restauracao = StateRestorationTester(compose)
            restauracao.setContent { Tela(viewModel, contagem, comTravaDaSessao = false) }

            viewModel.candidatar().join()
            compose.waitForIdle()
            dialogosVisiveis().assertCountEquals(1)

            restauracao.emulateSavedInstanceStateRestore()
            compose.waitForIdle()

            confereContagem(contagem, navegacoes = 1, consultas = 1, pedidos = 0)
            dialogosVisiveis().assertCountEquals(1)
        }
    }

    @Test
    fun `tocar em ativar pede ao sistema uma vez e a volta da tela nao pede de novo, com a trava da sessao de producao`() {
        runBlocking {
            val viewModel = criarViewModel()
            val contagem = Contagem()
            var naTela by mutableStateOf(true)
            compose.setContent { if (naTela) Tela(viewModel, contagem, comTravaDaSessao = true) }

            viewModel.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("botao-ativar-notificacoes").performClick()
            compose.waitForIdle()

            compose.runOnIdle { naTela = false }
            compose.waitForIdle()
            compose.runOnIdle { naTela = true }
            compose.waitForIdle()

            confereContagem(contagem, navegacoes = 1, consultas = 1, pedidos = 1)
            dialogosVisiveis().assertCountEquals(0)
        }
    }
}
