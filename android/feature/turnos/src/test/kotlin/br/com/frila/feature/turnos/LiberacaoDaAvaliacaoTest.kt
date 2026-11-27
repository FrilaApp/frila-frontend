package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Paridade com o iOS (#672/#676, cartão tqRGon9Y): enquanto a avaliação do turno não libera, o cartão diz "A avaliação libera às
 * HH:mm" (o `fim` previsto, fuso de São Paulo) e, com a tela aberta, o botão aparece no horário sem sair e voltar. Um agendamento
 * pontual (uma espera até o `fim` e uma releitura), sem polling.
 *
 * O relógio e a espera são controlados: `relogio` devolve o instante que o teste manda e `esperar` (o `delay` até o `fim`) só volta quando o
 * teste liberar, registrando a duração pedida, como o `dormir` dos testes do iOS.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LiberacaoDaAvaliacaoTest {

    @get:Rule
    val compose = createComposeRule()

    private val provedorDeLocalizacaoFalso = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    /** O `fim` previsto do turno de teste: 07:00 em São Paulo (UTC-3), como no teste do iOS. */
    private val fim = Instant.parse("2026-11-02T10:00:00Z")
    private val umaHoraAntes = Instant.parse("2026-11-02T09:00:00Z")

    private fun turnoJson(podeAvaliar: Boolean, verificacao: String = "verificado", checkoutEm: String? = "2026-11-02T08:50:00Z") = """
        [{
          "id": "t1",
          "posicao_id": "posicao-t1",
          "vaga": {
            "id": "vaga-t1",
            "funcao": "Garçom",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-02T01:00:00Z",
            "fim_em": "2026-11-02T10:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": "2026-11-02T00:30:00Z",
          "checkin_em": "2026-11-02T00:55:00Z",
          "checkin_tipo": "geolocalizado",
          "checkin_distancia_m": 80,
          "checkin_confirmado_em": null,
          "checkout_em": ${checkoutEm?.let { "\"$it\"" } ?: "null"},
          "checkout_distancia_m": null,
          "verificacao": "$verificacao",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": $podeAvaliar,
          "estado": "confirmada",
          "avaliacao": null,
          "cancelamento": null
        }]
    """.trimIndent()

    /** O servidor: a primeira leitura vem [primeira]; as seguintes, [seguintes] (status e corpo). Conta as leituras. */
    private class Servidor(val primeira: String, val seguintes: String, val statusSeguintes: HttpStatusCode = HttpStatusCode.OK) {
        val leituras = AtomicInteger(0)
    }

    private fun criarViewModel(servidor: Servidor): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                val n = servidor.leituras.incrementAndGet()
                respond(
                    content = if (n == 1) servidor.primeira else servidor.seguintes,
                    status = if (n == 1) HttpStatusCode.OK else servidor.statusSeguintes,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(servicoTurnos = ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    private fun criarCheckin(turnoId: String): CheckinViewModel = CheckinViewModel(
        turnoId = turnoId,
        coordenadaDaVaga = null,
        servicoTurnos = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = MockEngine { respond("") }),
        ),
        provedorDeLocalizacao = provedorDeLocalizacaoFalso,
    )

    /** A espera injetada: guarda as durações pedidas e só volta quando o teste liberar. */
    private class EsperaControlada {
        val pedidas = java.util.concurrent.CopyOnWriteArrayList<Long>()
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        suspend fun esperar(ms: Long) {
            pedidas += ms
            liberar.await()
        }
    }

    /** Monta a tela com o relógio em [agora] (mutável pelo teste) e a espera até o fim nas mãos do teste. */
    private fun montar(viewModel: MeusTurnosViewModel, espera: EsperaControlada, agora: () -> Instant) {
        runBlocking { viewModel.carregar().join() }
        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turno -> criarCheckin(turno.turnoId) },
                    relogio = agora,
                    esperar = espera::esperar,
                )
            }
        }
        compose.waitForIdle()
    }

    private fun comprovante(tipo: TipoVerificacaoCheckin) =
        ComprovanteCheckin(turnoId = "t1", registradoEm = Instant.parse("2026-11-02T00:55:00Z"), tipoVerificacao = tipo, codigoAutenticacao = "h")

    private fun item(
        podeAvaliar: Boolean = false,
        avaliacao: Boolean? = null,
        checkoutEm: Instant? = Instant.parse("2026-11-02T08:50:00Z"),
        fimDoTurno: Instant? = fim,
    ) = ItemTurno(
        turnoId = "t1", posicaoId = "p1", inicio = Instant.parse("2026-11-02T01:00:00Z"), fim = fimDoTurno,
        funcaoNome = "Garçom", estabelecimentoNome = "Bar do Zé", dataHorarioFormatado = "", valorFormatado = "", estado = "confirmada",
        podeAvaliar = podeAvaliar, avaliacaoResposta = avaliacao, checkoutEm = checkoutEm,
    )

    // ── A regra (a mesma do iOS: MeuTurnoViewModel.liberacaoDaAvaliacao) ──────────────────────────────────────────────

    @Test
    fun `presenca verificada, check-out feito e fim no futuro devolvem o fim`() {
        assertEquals(fim, liberacaoDaAvaliacao(item(), comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO), umaHoraAntes))
        assertEquals(fim, liberacaoDaAvaliacao(item(), comprovante(TipoVerificacaoCheckin.MANUAL_CONFIRMADO), umaHoraAntes))
    }

    @Test
    fun `sem presenca verificada nao promete horario`() {
        assertNull(liberacaoDaAvaliacao(item(), comprovante(TipoVerificacaoCheckin.MANUAL_PENDENTE), umaHoraAntes))
        assertNull(liberacaoDaAvaliacao(item(), comprovante(TipoVerificacaoCheckin.NAO_VERIFICADO), umaHoraAntes))
        assertNull(liberacaoDaAvaliacao(item(), null, umaHoraAntes))
    }

    @Test
    fun `sem check-out nao promete horario`() {
        assertNull(liberacaoDaAvaliacao(item(checkoutEm = null), comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO), umaHoraAntes))
    }

    @Test
    fun `ja liberada ou ja avaliada nao mostra aviso`() {
        assertNull(liberacaoDaAvaliacao(item(podeAvaliar = true), comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO), umaHoraAntes))
        assertNull(liberacaoDaAvaliacao(item(avaliacao = true), comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO), umaHoraAntes))
    }

    @Test
    fun `fim no passado, no instante ou desconhecido nao mostra aviso`() {
        val verificada = comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO)
        assertNull(liberacaoDaAvaliacao(item(), verificada, fim))
        assertNull(liberacaoDaAvaliacao(item(), verificada, fim.plusSeconds(1)))
        assertNull(liberacaoDaAvaliacao(item(fimDoTurno = null), verificada, umaHoraAntes))
    }

    @Test
    fun `o texto e a hora sao os do iOS no fuso de Sao Paulo`() {
        assertEquals("A avaliação libera às 07:00", TextosAvaliacao.liberaAs(horaDaLiberacao(fim)))
        assertEquals("A avaliação libera às 21:30", TextosAvaliacao.liberaAs(horaDaLiberacao(Instant.parse("2026-11-03T00:30:00Z"))))
    }

    // ── A tela, com relógio e espera controlados ──────────────────────────────────────────────────────────────────────

    private val umaHoraEmMs = 60 * 60 * 1000L

    @Test
    fun `antes do horario o cartao mostra o aviso e nao o botao, e agenda uma espera ate o fim`() {
        val espera = EsperaControlada()
        montar(criarViewModel(Servidor(turnoJson(false), turnoJson(true))), espera) { umaHoraAntes }

        compose.onNodeWithText("A avaliação libera às 07:00").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("aviso-liberacao-avaliacao").assertIsDisplayed()
        compose.onNodeWithText("Avaliar turno").assertDoesNotExist()
        assertEquals("uma espera, do tamanho de agora até o fim", listOf(umaHoraEmMs), espera.pedidas.toList())
    }

    @Test
    fun `no horario o botao aparece sem sair e voltar, com uma so releitura`() {
        val espera = EsperaControlada()
        val servidor = Servidor(turnoJson(false), turnoJson(true))
        montar(criarViewModel(servidor), espera) { umaHoraAntes }
        compose.onNodeWithText("A avaliação libera às 07:00").performScrollTo().assertIsDisplayed()
        assertEquals("uma leitura ao abrir, nenhuma enquanto espera (sem polling)", 1, servidor.leituras.get())

        espera.liberar.complete(Unit) // o fim chegou
        compose.waitUntil(5_000) { servidor.leituras.get() >= 2 && botaoVisivel() }

        compose.onNodeWithText("Avaliar turno").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("A avaliação libera às 07:00").assertDoesNotExist()
        compose.waitForIdle()
        assertEquals("uma só releitura no horário", 2, servidor.leituras.get())
        assertEquals("uma só espera", 1, espera.pedidas.size)
    }

    @Test
    fun `se a releitura falha o aviso some mesmo assim e nao fica uma hora que ja passou`() {
        val espera = EsperaControlada()
        val servidor = Servidor(turnoJson(false), "{}", statusSeguintes = HttpStatusCode.InternalServerError)
        montar(criarViewModel(servidor), espera) { umaHoraAntes }
        compose.onNodeWithText("A avaliação libera às 07:00").performScrollTo().assertIsDisplayed()

        espera.liberar.complete(Unit)
        compose.waitUntil(5_000) { servidor.leituras.get() >= 2 }
        compose.waitForIdle()

        compose.onNodeWithText("A avaliação libera às 07:00").assertDoesNotExist()
    }

    @Test
    fun `sem presenca verificada a tela nao mostra aviso nem agenda espera`() {
        val espera = EsperaControlada()
        val servidor = Servidor(turnoJson(false, verificacao = "pendente"), turnoJson(true))
        montar(criarViewModel(servidor), espera) { umaHoraAntes }

        compose.onNodeWithText("A avaliação libera às 07:00").assertDoesNotExist()
        assertEquals("nenhuma espera agendada", emptyList<Long>(), espera.pedidas.toList())
        assertEquals("nenhuma releitura", 1, servidor.leituras.get())
    }

    private fun botaoVisivel() = compose.onAllNodesWithTextCount("Avaliar turno") > 0

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTextCount(texto: String): Int =
        onAllNodes(androidx.compose.ui.test.hasText(texto)).fetchSemanticsNodes().size
}
