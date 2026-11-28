package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão QpgRwPFM: o cartão do turno agendado diz "Quem recebe: X" com o responsável lido do `detalhe_vaga` (o mesmo texto da
 * `TelaTurnoConfirmado`) e, sem ele, o nome da casa, como o iOS. O histórico não mostra a linha. Textos exatos.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class TelaMeusTurnosQuemRecebeTest {

    @get:Rule
    val rule = createComposeRule()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private val semLocalizacao = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    private fun turno(id: String, estado: String, vagaId: String) = """
        {"id":"$id","posicao_id":"posicao-$id",
         "vaga":{"id":"$vagaId","funcao":"garçom","local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto",
                 "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","valor_centavos":16000},
         "contraparte":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
                        "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "contato_visivel_ate":"2026-11-09T03:00:00Z","a_caminho_em":null,"checkin_em":null,"checkin_tipo":null,
         "checkin_distancia_m":null,"checkin_confirmado_em":null,"checkout_em":null,"checkout_distancia_m":null,
         "verificacao":"pendente","valor_acordado_centavos":16000,"pode_avaliar":false,"estado":"$estado",
         "avaliacao":null,"cancelamento":null}
    """.trimIndent()

    private fun detalhe(vagaId: String, responsavel: String) = """
        {"id":"$vagaId","estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
          "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "funcao":{"id":"f1","nome":"garçom","categoria":"Salão"},"inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z",
         "local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto","ponto":{"latitude":-15.79,"longitude":-47.88},
         "valor_centavos":16000,"posicoes":1,"posicoes_abertas":0,
         "inclusos":{"inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false},
         "responsavel_local":"$responsavel","modo":"urgencia","estado":"publicada","oculta":false,"publicado_em":"2026-10-30T12:00:00Z"}
    """.trimIndent()

    /** [detalheDaVaga]: o corpo do `detalhe_vaga` por vaga (status e texto); `portao` segura as leituras do detalhe. */
    private fun abrir(turnos: String, detalheDaVaga: (String) -> Pair<HttpStatusCode, String>, portao: CompletableDeferred<Unit>? = null) {
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            if (caminho.endsWith("/meus_turnos")) {
                respond(turnos, HttpStatusCode.OK, json)
            } else {
                val vagaId = Json.parseToJsonElement((request.body as TextContent).text).jsonObject["vaga_id"]!!.jsonPrimitive.content
                portao?.await()
                val (status, corpo) = detalheDaVaga(vagaId)
                respond(corpo, status, json)
            }
        }
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)
        val vagas = ServicoVagas(cliente)
        val viewModel = MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            quemRecebeDasVagas = QuemRecebeDasVagas { id -> vagas.detalheVaga(id).responsavelLocal },
        )
        val carga = viewModel.carregar()
        // Com o portão fechado a carga só termina quando o detalhe chega: aí basta a lista já estar na tela.
        if (portao == null) runBlocking { carga.join() } else rule.waitUntil(5_000) { viewModel.estado.value.status == StatusMeusTurnos.SUCESSO }
        rule.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { t ->
                        CheckinViewModel(turnoId = t.turnoId, coordenadaDaVaga = null, servicoTurnos = ServicoTurnos(cliente), provedorDeLocalizacao = semLocalizacao)
                    },
                )
            }
        }
        rule.waitForIdle()
    }

    private fun linhasQuemRecebe() = rule.onAllNodesWithText("Quem recebe:", substring = true).fetchSemanticsNodes().size

    @Test
    fun `o cartao do turno agendado diz Quem recebe com o responsavel lido do detalhe da vaga`() {
        abrir("[${turno("t1", "confirmada", "v1")}]", { id -> HttpStatusCode.OK to detalhe(id, "Carlos Silva") })

        rule.onNodeWithText("Quem recebe: Carlos Silva").assertIsDisplayed()
        assertEquals(1, linhasQuemRecebe())
    }

    @Test
    fun `sem o responsavel (404 da vaga direta) o cartao diz o nome da casa e nenhum erro aparece`() {
        abrir(
            "[${turno("t1", "confirmada", "v1")}]",
            { HttpStatusCode.NotFound to """{"code":"nao_encontrado","message":"x"}""" },
        )

        rule.onNodeWithText("Quem recebe: Bar do Zé").assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithText("Não foi possível", substring = true).fetchSemanticsNodes().size)
    }

    @Test
    fun `antes de o detalhe chegar o cartao mostra a casa, e depois troca pelo responsavel`() {
        val portao = CompletableDeferred<Unit>()
        abrir("[${turno("t1", "confirmada", "v1")}]", { id -> HttpStatusCode.OK to detalhe(id, "Carlos Silva") }, portao)
        rule.onNodeWithText("Quem recebe: Bar do Zé").assertIsDisplayed()

        portao.complete(Unit)
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Quem recebe: Carlos Silva").fetchSemanticsNodes().isNotEmpty() }

        rule.onNodeWithText("Quem recebe: Carlos Silva").assertIsDisplayed()
    }

    @Test
    fun `o historico nao mostra Quem recebe`() {
        abrir(
            "[${turno("h1", "cumprida", "vh1")},${turno("h2", "cancelada", "vh2")}]",
            { id -> HttpStatusCode.OK to detalhe(id, "NAO-DEVIA-APARECER") },
        )

        rule.onNodeWithText("Histórico").performClick()
        rule.waitForIdle()

        assertEquals(0, linhasQuemRecebe())
    }
}
