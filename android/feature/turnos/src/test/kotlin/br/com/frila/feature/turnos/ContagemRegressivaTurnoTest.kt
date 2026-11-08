package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ContagemRegressivaTurnoTest {

    @get:Rule
    val compose = createComposeRule()

    private val relogioFixo: Instant = Instant.parse("2026-11-01T17:00:00Z")

    @Test
    fun `exibe contagem regressiva e acessibilidade quando janela de checkin esta fechada`() {
        val json = turnoJson(
            id = "turno-1",
            inicioEm = "2026-11-01T20:00:00Z",
            fimEm = "2026-11-02T02:00:00Z",
        )
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }
        org.junit.Assert.assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        org.junit.Assert.assertEquals(1, viewModel.estado.value.agendados.size)

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { criarCheckinVM(it) },
                    relogio = { relogioFixo },
                )
            }
        }
        compose.onNodeWithText("Garçom").assertExists()
        compose.onNodeWithText("Janela de check-in (RN06)").assertExists()
        compose.onNodeWithText("Check-in abre em 2h 00min").assertExists()
        compose.onNodeWithContentDescription("Check-in abre em: 2h 00min").assertExists()
        compose.onNodeWithText("Cancelar turno").assertExists()
        compose.onAllNodesWithText("Fazer check-in").assertCountEquals(0)
    }

    @Test
    fun `exibe secao de checkin quando relogio entra na janela permitida`() {
        // Início às 17:45:00Z. Às 17:00:00Z, faltam 45 min (dentro da janela de 60 min).
        val json = turnoJson(
            id = "turno-2",
            inicioEm = "2026-11-01T17:45:00Z",
            fimEm = "2026-11-01T23:45:00Z",
        )
        val viewModel = criarViewModel(json)
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { criarCheckinVM(it) },
                    relogio = { relogioFixo },
                )
            }
        }
        compose.onNodeWithText("Fazer check-in").assertExists()
        compose.onAllNodesWithText("Janela de check-in (RN06)").assertCountEquals(0)
        compose.onNodeWithText("Cancelar turno").assertExists()
    }

    private fun turnoJson(
        id: String,
        inicioEm: String,
        fimEm: String,
    ) = """
        [
          {
            "id": "$id",
            "posicao_id": "posicao-$id",
            "vaga": {
              "id": "vaga-$id",
              "funcao": "Garçom",
              "local": "CLS 405 Bloco C",
              "regiao_administrativa": "Plano Piloto",
              "inicio_em": "$inicioEm",
              "fim_em": "$fimEm",
              "valor_centavos": 15000
            },
            "contraparte": {
              "id": "c1",
              "tipo": "estabelecimento",
              "nome": "Bar do Zé",
              "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
            },
            "contato_visivel_ate": "2026-11-09T03:00:00Z",
            "a_caminho_em": null,
            "checkin_em": null,
            "checkin_tipo": null,
            "checkin_distancia_m": null,
            "checkin_confirmado_em": null,
            "checkout_em": null,
            "checkout_distancia_m": null,
            "verificacao": "pendente",
            "valor_acordado_centavos": 15000,
            "pode_avaliar": false,
            "estado": "confirmada",
            "avaliacao": null,
            "cancelamento": null
          }
        ]
    """.trimIndent()

    private fun criarViewModel(respostaJson: String): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            relogio = Clock.fixed(relogioFixo, ZoneId.of("UTC")),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun criarCheckinVM(turnoId: String): CheckinViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = "{}",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val provedorFalso = object : ProvedorDeLocalizacao {
            override suspend fun obterCoordenadaAtual(): Coordenada? = null
            override fun temPermissaoDeLocalizacao(): Boolean = false
            override fun isGpsAtivado(): Boolean = false
        }
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = null,
            servicoTurnos = ServicoTurnos(cliente),
            provedorDeLocalizacao = provedorFalso,
            instanteAtual = { relogioFixo },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }
}
