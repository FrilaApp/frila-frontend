package br.com.frila.feature.turnos.contratante

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.printToString
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.StatusAvaliacao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaAvaliacaoDoContratanteTest {

    @get:Rule
    val compose = createComposeRule()

    private val turnoId = "turno-contratante-999"

    private fun criarViewModel(
        respostaJson: String = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-21T04:00:00Z"}""",
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
    ): AvaliacaoViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = statusHttp,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return AvaliacaoViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun aoCarregarExibePerguntaDoContratanteEOpcoesBinarias() {
        val vm = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithTag("pergunta-avaliacao-contratante").assertIsDisplayed()
        compose.onNodeWithText("Chamaria este profissional de novo?").assertIsDisplayed()
        compose.onNodeWithText(
            "Sua resposta é anônima e compõe a reputação do profissional no Frila. Cada turno concluído conta para o índice de recomendação.",
        ).assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertIsDisplayed()
        compose.onNodeWithText("Não chamaria").assertIsDisplayed()
    }

    @Test
    fun aoResponderSimRegistraAvaliacaoEExibeConfirmacao() {
        val vm = criarViewModel()
        var voltou = false

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = { voltou = true },
                )
            }
        }

        compose.onNodeWithText("Sim, chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.SUCESSO }
        compose.waitForIdle()

        compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
        compose.onNodeWithText("Você recomendou este profissional.").assertIsDisplayed()

        compose.onNodeWithTag("voltar-avaliacao-contratante").assertIsDisplayed().performClick()
        assertTrue(voltou)
    }

    @Test
    fun aoResponderNaoRegistraAvaliacaoEExibeConfirmacaoNegativa() {
        val vm = criarViewModel(
            respostaJson = """{"turno_id":"$turnoId","resposta":false,"criada_em":"2026-11-21T04:00:00Z"}""",
        )

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Não chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.SUCESSO }
        compose.waitForIdle()

        compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
        compose.onNodeWithText("Você não recomendou este profissional.").assertIsDisplayed()
    }

    @Test
    fun erroDeRedePermiteTentarNovamente() {
        val vm = criarViewModel(
            respostaJson = """{"code":"sem_rede","message":"Sem rede"}""",
            statusHttp = HttpStatusCode.InternalServerError,
        )

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Sim, chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.ERRO }
        compose.waitForIdle()

        assertEquals(StatusAvaliacao.ERRO, vm.estado.value.status)
        compose.onNodeWithText("Sem conexão. Verifique sua internet e tente de novo.").assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertIsDisplayed()
    }

    // MO7DkVA2: o 409 avaliacao_ja_registrada deixa a tela em "já avaliado": sem botões de avaliar, com a resposta gravada relida do turno.
    private val casaId = "casa-0001"

    /**
     * O servidor só devolve os turnos da casa quando a leitura leva `?estabelecimento_id=$casaId` (sem ele, conta de contratante recebe
     * lista vazia, contrato). [avaliadoAoAbrir]: a leitura de abertura já traz a avaliação; senão ela só aparece na releitura do 409.
     */
    private fun viewModelComConflito(gravada: Boolean?, avaliadoAoAbrir: Boolean = false): AvaliacaoViewModel {
        val leituras = java.util.concurrent.atomic.AtomicInteger(0)
        val turno = """
            [{"id": "$turnoId", "posicao_id": "p1",
              "vaga": {"id": "v1", "funcao": "garçom", "local": "CLS 405", "regiao_administrativa": "Plano Piloto",
                       "inicio_em": "2026-11-01T21:00:00Z", "fim_em": "2026-11-02T03:00:00Z", "valor_centavos": 16000},
              "contraparte": {"id": "c1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                              "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
              "verificacao": "verificado", "valor_acordado_centavos": 16000, "pode_avaliar": false, "estado": "cumprida",
              "avaliacao": ${gravada?.let { """{"turno_id": "$turnoId", "resposta": $it, "criada_em": "2026-11-02T04:00:00Z"}""" } ?: "null"},
              "cancelamento": null}]
        """.trimIndent()
        val cabecalho = headersOf(HttpHeaders.ContentType, "application/json")
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                if (request.url.encodedPath.endsWith("/avaliar")) {
                    respond("""{"code":"avaliacao_ja_registrada","message":"sintetico"}""", HttpStatusCode.Conflict, cabecalho)
                } else {
                    val n = leituras.incrementAndGet()
                    val daCasa = request.url.parameters["estabelecimento_id"] == casaId
                    respond(if (daCasa && (n > 1 || avaliadoAoAbrir)) turno else "[]", HttpStatusCode.OK, cabecalho)
                }
            },
        )
        return AvaliacaoViewModel(servicoTurnos = ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun conflitoJaRegistradoMostraTurnoJaAvaliadoComARespostaGravadaESemBotoes() {
        val vm = viewModelComConflito(gravada = false)

        compose.setContent {
            FrilaTheme { TelaAvaliacaoDoContratante(turnoId = turnoId, viewModel = vm, aoVoltar = {}, estabelecimentoId = casaId) }
        }

        compose.onNodeWithText("Não chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.JA_AVALIADO }
        compose.waitForIdle()

        compose.onNodeWithText("Turno já avaliado").assertIsDisplayed()
        compose.onNodeWithText("A avaliação registrada: você não recomendou este profissional.").assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertDoesNotExist()
        compose.onNodeWithText("Não chamaria").assertDoesNotExist()
        compose.onNodeWithTag("voltar-avaliacao-contratante").assertIsDisplayed()
    }

    @Test
    fun aoAbrirTurnoJaAvaliadoPelaCasaMostraDiretoComARespostaESemPergunta() {
        val vm = viewModelComConflito(gravada = true, avaliadoAoAbrir = true)
        var lifecycleVisto: androidx.lifecycle.Lifecycle? = null
        val inicio = System.nanoTime()

        compose.setContent {
            val dono = androidx.lifecycle.compose.LocalLifecycleOwner.current
            androidx.compose.runtime.SideEffect { lifecycleVisto = dono.lifecycle }
            FrilaTheme { TelaAvaliacaoDoContratante(turnoId = turnoId, viewModel = vm, aoVoltar = {}, estabelecimentoId = casaId) }
        }
        try {
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.JA_AVALIADO }
        // O estado do view model muda em outro thread (a leitura de abertura) e a tela o coleta no principal. Medido na suíte inteira: com o
        // estado já em JA_AVALIADO a árvore seguia na pergunta inicial por mais de 5 s. Causa provável (hipótese, validada só pela
        // estabilidade das rodadas): o looper principal do Robolectric não é processado enquanto o teste só consulta a árvore. Cada checagem
        // faz `waitForIdle()` antes e a condição é a que a asserção afirma: o título visível.
        compose.waitUntil(5000) {
            compose.waitForIdle()
            runCatching { compose.onNodeWithText("Turno já avaliado").assertIsDisplayed() }.isSuccess
        }
        } catch (estouro: androidx.compose.ui.test.ComposeTimeoutException) {
            diagnosticar("estouro", vm, lifecycleVisto, inicio)
            throw estouro
        }
        registrarDiagnostico("- DIAG 6sHHfHUd ok: título visível em ${(System.nanoTime() - inicio) / 1_000_000} ms\n")
        compose.waitForIdle()

        compose.onNodeWithText("Turno já avaliado").assertIsDisplayed()
        compose.onNodeWithText("A avaliação registrada: você recomendou este profissional.").assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertDoesNotExist()
        compose.onNodeWithText("Não chamaria").assertDoesNotExist()
    }

    // DIAGNÓSTICO TEMPORÁRIO (6sHHfHUd), só para a CI: sai antes da correção, não é para mesclar. Grava no resumo do job
    // (GITHUB_STEP_SUMMARY), porque o console do Gradle não mostra a mensagem nem a saída do teste.
    private fun registrarDiagnostico(texto: String) {
        System.err.print(texto)
        System.getenv("GITHUB_STEP_SUMMARY")?.let { runCatching { java.io.File(it).appendText(texto) } }
    }

    private fun diagnosticar(rotulo: String, vm: AvaliacaoViewModel, lifecycle: androidx.lifecycle.Lifecycle?, inicio: Long) {
        val principal = android.os.Looper.getMainLooper()
        val sombra = org.robolectric.Shadows.shadowOf(principal)
        val arvore = runCatching {
            compose.onRoot(useUnmergedTree = true).printToString(maxDepth = Int.MAX_VALUE)
        }.getOrElse { "árvore indisponível: $it" }
        val main = principal.thread
        registrarDiagnostico(
            buildString {
                appendLine("### DIAG 6sHHfHUd: $rotulo")
                appendLine("- tempo desde setContent: ${(System.nanoTime() - inicio) / 1_000_000} ms")
                appendLine("- vm.estado: ${vm.estado.value}")
                appendLine("- lifecycle visto pela composição: ${lifecycle?.currentState}")
                appendLine(
                    "- thread do teste: ${Thread.currentThread().name}; looper principal ocioso: ${sombra.isIdle}; " +
                        "próxima tarefa agendada: ${sombra.nextScheduledTaskTime}; relógio do Compose: ${compose.mainClock.currentTime} ms " +
                        "(autoAdvance=${compose.mainClock.autoAdvance})",
                )
                appendLine("```")
                appendLine(arvore)
                appendLine("```")
                appendLine("thread ${main.name} (${main.state}):")
                appendLine("```")
                main.stackTrace.take(60).forEach { appendLine("  at $it") }
                appendLine("```")
            },
        )
    }

    @Test
    fun semAcasaNaRotaAAberturaNaoAchaOTurnoEAPerguntaSegue() {
        // Sem `estabelecimentoId` a releitura vai sem a casa: o servidor devolve lista vazia ao contratante e a pergunta segue.
        val vm = viewModelComConflito(gravada = true, avaliadoAoAbrir = true)

        compose.setContent { FrilaTheme { TelaAvaliacaoDoContratante(turnoId = turnoId, viewModel = vm, aoVoltar = {}) } }
        compose.waitForIdle()
        Thread.sleep(300)
        compose.waitForIdle()

        assertEquals(StatusAvaliacao.OCIOSO, vm.estado.value.status)
        compose.onNodeWithText("Sim, chamaria").assertIsDisplayed()
    }
}

