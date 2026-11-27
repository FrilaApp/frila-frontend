package br.com.frila.feature.vagas.detalhe

import android.content.Intent
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.componentes.TextosVerNoMapa
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaDetalheVagaTest {

    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() {
        ControleSessaoNotificacao.resetarParaTestes()
    }

    private fun criarVaga(
        modo: String = "urgencia",
        funcaoNome: String = "Garçom",
        estabelecimentoNome: String = "Bar do Zé",
        incluiRefeicao: Boolean = true,
        incluiTransporte: Boolean = false,
        exigeMaterial: Boolean = false,
        positivas: Int = 7,
        total: Int = 7,
    ) = VagaAbertaDto(
        id = "11111111-1111-1111-1111-111111111111",
        funcao = FuncaoDto(id = "f1", nome = funcaoNome, categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = estabelecimentoNome,
            reputacao = ReputacaoDto(positivas = positivas, total = total, taxaComparecimento = 1.0, turnosConsiderados = total, turnosRealizados = total),
        ),
        inicioEm = "2026-11-01T21:00:00Z",
        fimEm = "2026-11-02T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 4.2,
        valorCentavos = 16_000,
        posicoesAbertas = 2,
        inclusos = InclusosDto(
            incluiRefeicao = incluiRefeicao,
            incluiTransporte = incluiTransporte,
            exigeMaterialProprio = exigeMaterial,
        ),
        modo = modo,
    )

    private fun criarViewModel(
        vaga: VagaAbertaDto,
        respostaJson: String = "",
        status: HttpStatusCode = HttpStatusCode.OK,
    ): DetalheVagaViewModel {
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
        return DetalheVagaViewModel(
            vaga = vaga,
            servicoVagas = ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `exibe detalhes da vaga com modo urgencia e inclusos`() {
        val vaga = criarVaga(modo = "urgencia")
        val viewModel = criarViewModel(vaga)

        compose.setContent {
            FrilaTheme {
                TelaDetalheVaga(viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Garçom").assertIsDisplayed()
        compose.onNodeWithText("Bar do Zé").assertIsDisplayed()
        compose.onNodeWithText("Modo urgência: confirmação na hora").assertIsDisplayed()
        // Sem rótulo: o ícone basta na leitura (o local e a região na mesma linha, a distância logo abaixo).
        compose.onNode(hasText("SQN 108, Asa Norte", substring = true)).assertExists()
        compose.onNode(hasText("4,2 km", substring = true)).assertExists()
        compose.onNode(hasText("de distância", substring = true)).assertExists()
        compose.onNode(hasText("160,00", substring = true)).assertExists()

        // Benefícios e acessibilidade
        compose.onNodeWithText("Inclui").assertExists()
        compose.onNodeWithContentDescription("Refeição: incluído").assertExists()
        compose.onNodeWithContentDescription("Transporte: não incluído").assertExists()

        // Botão de candidatura
        compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled().assertHasClickAction()
    }

    @Test
    fun `exibe modo selecao quando vaga for do tipo selecao`() {
        val vaga = criarVaga(modo = "selecao")
        val viewModel = criarViewModel(vaga)

        compose.setContent {
            FrilaTheme {
                TelaDetalheVaga(viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Modo seleção: contratante escolhe depois").assertIsDisplayed()
        compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled()
    }

    @Test
    fun `ao candidatar-se em modo urgencia confirma e exibe cartao de contato`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": {
                    "nome": "Zé da Silva",
                    "telefone": "61988887777"
                  }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            // Mensagem de sucesso com LiveRegionMode.Polite para TalkBack
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.")
                .assertExists()
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))

            // Contato confirmado visível
            compose.onNodeWithText("Contato confirmado").assertExists()
            compose.onNodeWithText("Nome: Zé da Silva").assertExists()
            compose.onNodeWithText("Telefone: 61988887777").assertExists()

            // Botão atualiza texto e fica desabilitado
            compose.onNodeWithText("Candidatura confirmada").assertExists().assertIsNotEnabled()
        }
    }

    @Test
    fun `ao candidatar-se em modo selecao exibe candidatura enviada`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "pendente",
                  "candidatura_id": "c2",
                  "posicao_id": null,
                  "turno_id": null,
                  "contato": null
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "selecao")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithText("Candidatura enviada. Aguarde a escolha do contratante.")
                .assertExists()
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))
            compose.onNodeWithText("Candidatura enviada").assertExists().assertIsNotEnabled()
        }
    }

    @Test
    fun `quando api retorna erro de conflito exibe mensagem de erro apropriada`() {
        runBlocking {
            val erroJson = """
                {
                  "code": "posicao_ja_preenchida",
                  "message": "alguém chegou antes"
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = erroJson, status = HttpStatusCode.Conflict)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithText("Que pena, a vaga acabou de ser preenchida.")
                .assertExists()
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive))
            compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled()
        }
    }

    @Test
    fun `apos primeira confirmacao de vaga exibe dialogo contextual de permissao de notificacao quando nao concedida`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        verificarPermissaoNotificacao = { false },
                    )
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            // Diálogo contextual com explicação clara
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertIsDisplayed()
            compose.onNodeWithText("Ativar notificações de turnos").assertIsDisplayed()
            compose.onNodeWithText(
                "Receba avisos imediatos sobre confirmações de presença, lembretes de início de turno " +
                    "e chamados de vagas urgentes para você não perder nenhum compromisso.",
            ).assertIsDisplayed()
            compose.onNodeWithTag("botao-ativar-notificacoes").assertIsDisplayed()
            compose.onNodeWithTag("botao-agora-nao-notificacoes").assertIsDisplayed()
        }
    }

    private fun exercitarLauncherReal(concedida: Boolean) {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)
            var resultado: Boolean? = null
            var pedidos = 0
            val registro = object : androidx.activity.result.ActivityResultRegistry() {
                override fun <I, O> onLaunch(
                    requestCode: Int,
                    contract: androidx.activity.result.contract.ActivityResultContract<I, O>,
                    input: I,
                    options: androidx.core.app.ActivityOptionsCompat?,
                ) {
                    assertTrue(contract is androidx.activity.result.contract.ActivityResultContracts.RequestPermission)
                    assertEquals(android.Manifest.permission.POST_NOTIFICATIONS, input)
                    pedidos++
                    dispatchResult(requestCode, concedida)
                }
            }
            val dono = object : androidx.activity.result.ActivityResultRegistryOwner {
                override val activityResultRegistry = registro
            }
            compose.setContent {
                androidx.compose.runtime.CompositionLocalProvider(
                    androidx.activity.compose.LocalActivityResultRegistryOwner provides dono,
                ) {
                    FrilaTheme {
                        TelaDetalheVaga(
                            viewModel = viewModel,
                            verificarPermissaoNotificacao = { false },
                            aoResultadoPermissao = { resultado = it },
                        )
                    }
                }
            }
            viewModel.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("botao-ativar-notificacoes").performClick()
            compose.waitForIdle()
            assertEquals(1, pedidos)
            assertEquals(concedida, resultado)
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.").assertExists()
        }
    }

    @Test
    fun `ao confirmar no dialogo de permissao aciona o launcher real de permissao do Android com concessao`() {
        exercitarLauncherReal(concedida = true)
    }

    @Test
    fun `ao receber negacao no launcher real de permissao do Android preserva confirmacao sem travar fluxo`() {
        exercitarLauncherReal(concedida = false)
    }

    @Test
    fun `ao dispensar no dialogo contextual fecha dialogo sem acionar launcher de permissao`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)
            var pedidosLauncher = 0
            var resultadoRecebido: Boolean? = null

            val registro = object : androidx.activity.result.ActivityResultRegistry() {
                override fun <I, O> onLaunch(
                    requestCode: Int,
                    contract: androidx.activity.result.contract.ActivityResultContract<I, O>,
                    input: I,
                    options: androidx.core.app.ActivityOptionsCompat?,
                ) {
                    pedidosLauncher++
                }
            }
            val dono = object : androidx.activity.result.ActivityResultRegistryOwner {
                override val activityResultRegistry = registro
            }

            compose.setContent {
                androidx.compose.runtime.CompositionLocalProvider(
                    androidx.activity.compose.LocalActivityResultRegistryOwner provides dono,
                ) {
                    FrilaTheme {
                        TelaDetalheVaga(
                            viewModel = viewModel,
                            verificarPermissaoNotificacao = { false },
                            aoResultadoPermissao = { resultadoRecebido = it },
                        )
                    }
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithTag("botao-agora-nao-notificacoes").performClick()
            compose.waitForIdle()

            assertEquals(0, pedidosLauncher)
            assertEquals(false, resultadoRecebido)
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.").assertExists()
        }
    }

    @Test
    fun `nao repete dialogo contextual de permissao depois de dispensa em outra vaga na mesma sessao`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vm1 = criarViewModel(criarVaga(), respostaJson = respostaJson)
            val vm2 = criarViewModel(
                criarVaga().copy(id = "22222222-2222-2222-2222-222222222222"),
                respostaJson = respostaJson,
            )
            val tela = androidx.compose.runtime.mutableIntStateOf(0)
            compose.setContent {
                androidx.compose.runtime.key(tela.intValue) {
                    FrilaTheme {
                        TelaDetalheVaga(
                            viewModel = if (tela.intValue == 0) vm1 else vm2,
                            verificarPermissaoNotificacao = { false },
                        )
                    }
                }
            }
            vm1.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("botao-agora-nao-notificacoes").performClick()
            compose.waitForIdle()
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.runOnIdle { tela.intValue = 1 }
            vm2.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
        }
    }

    @Test
    @Config(sdk = [28])
    fun `api 28 nao pede permissao runtime de notificacao`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vm = criarViewModel(criarVaga(), respostaJson = respostaJson)
            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = vm)
                }
            }
            vm.candidatar().join()
            compose.waitForIdle()
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.").assertExists()
        }
    }

    @Test
    fun `quando permissao ja estiver concedida nao exibe dialogo de permissao ao confirmar`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        verificarPermissaoNotificacao = { true },
                    )
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.").assertExists()
        }
    }

    @Test
    fun `quando candidatura falha por posicao_ja_preenchida aciona callback aoNavegarParaVagaPreenchida`() {
        runBlocking {
            val respostaJson = """{"code":"posicao_ja_preenchida","message":"preenchida"}"""
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson, status = HttpStatusCode.Conflict)
            var vagaPreenchidaNavegada: VagaAbertaDto? = null

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        aoNavegarParaVagaPreenchida = { vagaPreenchidaNavegada = it },
                    )
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            org.junit.Assert.assertEquals(vaga.id, vagaPreenchidaNavegada?.id)
        }
    }

    @Test
    fun `quando candidatura falha por vaga_encerrada aciona callback aoNavegarParaVagaEncerrada`() {
        runBlocking {
            val respostaJson = """{"code":"vaga_encerrada","message":"encerrada"}"""
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson, status = HttpStatusCode.Conflict)
            var vagaEncerradaNavegada: VagaAbertaDto? = null

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        aoNavegarParaVagaEncerrada = { vagaEncerradaNavegada = it },
                    )
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            org.junit.Assert.assertEquals(vaga.id, vagaEncerradaNavegada?.id)
        }
    }

    @Test
    fun `quando candidatura falha por conta_suspensa aciona callback aoNavegarParaContaSuspensa`() {
        runBlocking {
            val respostaJson = """{"code":"conta_suspensa","message":"suspensa"}"""
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson, status = HttpStatusCode.Forbidden)
            var contaSuspensaNavegada = false

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        aoNavegarParaContaSuspensa = { contaSuspensaNavegada = true },
                    )
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            org.junit.Assert.assertTrue("Deveria acionar navegação para conta suspensa", contaSuspensaNavegada)
        }
    }

    @Test
    fun `confirmada aciona navegacao e dialogo apenas uma vez mesmo apos recomposicao`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": { "nome": "Zé da Silva", "telefone": "61988887777" }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)
            var navegacoesConfirmadas = 0
            val gatilhoRecomposicao = androidx.compose.runtime.mutableIntStateOf(0)

            compose.setContent {
                val passo = gatilhoRecomposicao.intValue
                FrilaTheme {
                    TelaDetalheVaga(
                        viewModel = viewModel,
                        verificarPermissaoNotificacao = { false },
                        aoNavegarParaConfirmada = { _, _ -> navegacoesConfirmadas++ },
                    )
                }
                if (passo < 0) Unit
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            assertEquals(1, navegacoesConfirmadas)
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertIsDisplayed()
            compose.onNodeWithTag("botao-agora-nao-notificacoes").performClick()
            compose.waitForIdle()

            // Força recomposição e reinicialização do efeito simulando reentrada da tela
            compose.runOnIdle { gatilhoRecomposicao.intValue = 1 }
            compose.waitForIdle()

            assertEquals(1, navegacoesConfirmadas)
            compose.onNodeWithTag("dialogo-permissao-notificacao").assertDoesNotExist()
            compose.onNodeWithText("Candidatura confirmada").assertExists().assertIsNotEnabled()
        }
    }

    // ---- zjiTWbAP: "Ver no mapa" no detalhe da vaga, com a casa e o endereço, como o iOS ----

    @Test
    fun `Ver no mapa abre a casa e o endereco da vaga no app de mapas`() {
        val viewModel = criarViewModel(criarVaga(estabelecimentoNome = "Bar do Zé"))
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = viewModel) } }

        compose.onNodeWithTag(TextosVerNoMapa.TAG).performScrollTo().performClick()
        compose.waitForIdle()

        val aberto = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
        assertEquals(Intent.ACTION_VIEW, aberto.action)
        assertEquals("geo:0,0?q=Bar%20do%20Z%C3%A9%2C%20SQN%20108", aberto.dataString)
    }

    // ── A reputação da casa (DLjTVc2e, item 149) ──────────────────────────────────────────────────────────────────────

    private fun textoDaReputacaoNaTela(positivas: Int, total: Int): String {
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = criarViewModel(criarVaga(positivas = positivas, total = total))) } }
        return compose.onNodeWithTag("detalhe-reputacao").fetchSemanticsNode().config[SemanticsProperties.Text].joinToString("") { it.text }
    }

    @Test
    fun `a reputacao da casa diz quantas avaliacoes indicam que trabalhariam la de novo`() {
        assertEquals("3 de 5 avaliações indicam que trabalhariam lá de novo", textoDaReputacaoNaTela(positivas = 3, total = 5))
    }

    @Test
    fun `uma casa sem avaliacoes diz Ainda sem avaliacoes`() {
        assertEquals("Ainda sem avaliações.", textoDaReputacaoNaTela(positivas = 0, total = 0))
    }

    @Test
    fun `uma casa com avaliacoes e nenhuma positiva ainda mostra a contagem`() {
        assertEquals("0 de 4 avaliações indicam que trabalhariam lá de novo", textoDaReputacaoNaTela(positivas = 0, total = 4))
    }

    // ── O rateio dos 10% (DLjTVc2e, item 150) ─────────────────────────────────────────────────────────────────────────

    private fun montarComDetalhe(participaRateio: Boolean?) {
        val vm = DetalheVagaViewModel(
            vaga = criarVaga(),
            servicoVagas = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond("") })),
            detalhe = vagaDoServidor(participaRateio = participaRateio),
            escopo = CoroutineScope(Dispatchers.Default),
        )
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = vm) } }
    }

    @Test
    fun `a casa que participa do rateio mostra Rateio dos 10 por cento Sim`() {
        montarComDetalhe(participaRateio = true)
        compose.onNodeWithText("Rateio dos 10%: Sim").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `a casa que nao participa mostra Nao`() {
        montarComDetalhe(participaRateio = false)
        compose.onNodeWithText("Rateio dos 10%: Não").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `quando a casa nao disse o rateio, a linha nao aparece`() {
        montarComDetalhe(participaRateio = null)
        compose.onNode(hasText("Responsável no local", substring = true)).performScrollTo().assertIsDisplayed()
        assertEquals(0, compose.onAllNodesWithText("Rateio dos 10%", substring = true).fetchSemanticsNodes().size)
    }

    @Test
    fun `aberta pela lista, sem o detalhe do servidor, a tela nao inventa o rateio`() {
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = criarViewModel(criarVaga())) } }
        assertEquals(0, compose.onAllNodesWithText("Rateio dos 10%", substring = true).fetchSemanticsNodes().size)
    }

    // ---- 3k9E6ojp: tocar no nome da casa abre o perfil público, uma vez só ----

    @Test
    fun `tocar no nome da casa abre o perfil dela uma vez, mesmo com dois toques`() {
        val abertos = mutableListOf<String>()
        val viewModel = criarViewModel(criarVaga())
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = viewModel, aoAbrirPerfilDaCasa = { abertos += it }) } }

        compose.onNodeWithTag(TAG_ABRIR_PERFIL_DA_CASA)
            .assertHasClickAction()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
            .assert(hasText("Bar do Zé"))
            .performClick()
        compose.onNodeWithTag(TAG_ABRIR_PERFIL_DA_CASA).performClick()
        compose.waitForIdle()

        assertEquals(listOf("e1"), abertos)
    }

    @Test
    fun `sem o caminho do perfil o nome da casa e so titulo, sem toque`() {
        val viewModel = criarViewModel(criarVaga())
        compose.setContent { FrilaTheme { TelaDetalheVaga(viewModel = viewModel) } }

        compose.onNodeWithTag(TAG_ABRIR_PERFIL_DA_CASA)
            .assertHasNoClickAction()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
            .assert(hasText("Bar do Zé"))
    }
}
