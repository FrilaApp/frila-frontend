package br.com.frila.feature.turnos

import androidx.compose.runtime.remember
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * L1-4 (TELA PROVISÓRIA): o check-out na lista de Meus turnos. O turno vai de 21:00 de 01/11 às
 * 03:00 de 02/11 (UTC); o check-out vale até 04:00 de 02/11.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaCheckoutECodigoTest {

    @get:Rule
    val compose = createComposeRule()

    private val semLocalizacao = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    private val noMeioDoTurno = Instant.parse("2026-11-01T23:00:00Z")
    private val logoDepoisDoFim = Instant.parse("2026-11-02T03:30:00Z")
    private val passouDaJanelaDoCheckout = Instant.parse("2026-11-02T04:10:00Z")

    private fun turnoJson(
        checkinEm: String? = "2026-11-01T21:05:00Z",
        checkinTipo: String? = "geolocalizado",
        verificacao: String = "verificado",
        checkoutEm: String? = null,
    ) = """
        {
          "id": "t1", "posicao_id": "p1",
          "vaga": {"id": "v1", "funcao": "Garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "2026-11-01T21:00:00Z", "fim_em": "2026-11-02T03:00:00Z", "valor_centavos": 16000},
          "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "contato_visivel_ate": null, "a_caminho_em": null,
          "checkin_em": ${checkinEm?.let { "\"$it\"" }}, "checkin_tipo": ${checkinTipo?.let { "\"$it\"" }},
          "checkin_distancia_m": null, "checkin_confirmado_em": null,
          "checkout_em": ${checkoutEm?.let { "\"$it\"" }}, "checkout_distancia_m": null,
          "verificacao": "$verificacao", "valor_acordado_centavos": 16000, "pode_avaliar": false,
          "estado": "confirmada", "avaliacao": null, "cancelamento": null
        }
    """.trimIndent()

    private class Rede {
        val caminhos = mutableListOf<String>()
    }

    private fun cliente(rede: Rede, status: HttpStatusCode, corpo: String) = ClienteSupabase(
        "https://frila.supabase.co", "chave-teste",
        engine = MockEngine { request ->
            rede.caminhos += request.url.encodedPath
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        },
    )

    private val registroJson =
        """{"turno_id":"t1","tipo":"geolocalizado","verificacao":"verificado","registrado_em":"2026-11-02T03:10:00Z","distancia_m":null}"""

    private fun montar(
        turno: String,
        agora: Instant,
        rede: Rede = Rede(),
        statusDoCheckout: HttpStatusCode = HttpStatusCode.OK,
        corpoDoCheckout: String = registroJson,
    ): Rede {
        val meusTurnos = MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(
                ClienteSupabase(
                    "https://frila.supabase.co", "chave-teste",
                    engine = MockEngine { respond("[$turno]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
                ),
            ),
            escopo = CoroutineScope(Dispatchers.Default),
        )
        runBlocking { meusTurnos.carregar().join() }
        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = meusTurnos,
                    criarCheckinViewModel = { item ->
                        remember(item.turnoId) {
                            CheckinViewModel(
                                turnoId = item.turnoId,
                                coordenadaDaVaga = null,
                                servicoTurnos = ServicoTurnos(cliente(rede, statusDoCheckout, corpoDoCheckout)),
                                provedorDeLocalizacao = semLocalizacao,
                                instanteAtual = { agora },
                                escopo = CoroutineScope(Dispatchers.Default),
                            )
                        }
                    },
                    relogio = { agora },
                )
            }
        }
        return rede
    }

    private fun contar(texto: String) = compose.onAllNodesWithText(texto).fetchSemanticsNodes().size

    // ---- Check-out ----

    @Test
    fun `no meio do turno, com check-in feito, aparece fazer check-out com alvo minimo e ele registra`() {
        val rede = montar(turnoJson(), noMeioDoTurno)

        compose.onNodeWithText(TextosCheckoutECodigo.BOTAO_CHECKOUT).performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        compose.waitUntil(5_000) { contar(TextosCheckoutECodigo.CHECKOUT_FEITO) > 0 }
        assertEquals(listOf("/rest/v1/rpc/fazer_checkout"), rede.caminhos)
        assertEquals(0, contar(TextosCheckoutECodigo.BOTAO_CHECKOUT))
    }

    @Test
    fun `logo depois do fim, ainda dentro dos 60 minutos, o botao continua`() {
        montar(turnoJson(), logoDepoisDoFim)

        compose.onNodeWithText(TextosCheckoutECodigo.BOTAO_CHECKOUT).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `passados 60 minutos do fim o botao some`() {
        montar(turnoJson(), passouDaJanelaDoCheckout)

        assertEquals(0, contar(TextosCheckoutECodigo.BOTAO_CHECKOUT))
    }

    @Test
    fun `sem check-in nao ha check-out`() {
        montar(turnoJson(checkinEm = null, checkinTipo = null, verificacao = "pendente"), noMeioDoTurno)

        assertEquals(0, contar(TextosCheckoutECodigo.BOTAO_CHECKOUT))
    }

    @Test
    fun `turno que ja tem check-out mostra que foi registrado e nao oferece de novo`() {
        montar(turnoJson(checkoutEm = "2026-11-02T03:05:00Z"), logoDepoisDoFim)

        compose.onNodeWithText(TextosCheckoutECodigo.CHECKOUT_FEITO).performScrollTo().assertIsDisplayed()
        assertEquals(0, contar(TextosCheckoutECodigo.BOTAO_CHECKOUT))
    }

    @Test
    fun `recusa do servidor mostra o motivo e deixa tentar de novo`() {
        montar(
            turnoJson(), noMeioDoTurno,
            statusDoCheckout = HttpStatusCode.UnprocessableEntity,
            corpoDoCheckout = """{"code":"fora_da_janela","message":"x"}""",
        )

        compose.onNodeWithText(TextosCheckoutECodigo.BOTAO_CHECKOUT).performScrollTo().performClick()

        compose.waitUntil(5_000) { contar(TextosCheckoutECodigo.CHECKOUT_FORA_DA_JANELA) > 0 }
        compose.onNodeWithText(TextosCheckoutECodigo.BOTAO_CHECKOUT_TENTAR_DE_NOVO).performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).assertIsDisplayed()
    }
}
