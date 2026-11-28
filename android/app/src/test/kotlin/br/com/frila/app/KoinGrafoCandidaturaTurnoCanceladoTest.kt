package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.candidaturas.ListaDeCandidaturas
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoGrafoDeCandidaturas = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * ARHvBJEK: o grafo liga `MinhasCandidaturasViewModel` a `meus_turnos`. Com o grafo real e a rede simulada, a aceita cujo
 * `turno_id` aponta um turno cancelado sai marcada, e a aceita de turno de pé não. Sem a fiação do Koin o view model nasce
 * sem a leitura dos turnos e nenhuma candidatura sai marcada.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoCandidaturaTurnoCanceladoTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val caminhos = CopyOnWriteArrayList<String>()
    private var cliente: ClienteSupabase? = null

    private fun candidatura(id: String, turno: String) = """
        {"id": "$id", "estado": "aceita", "criada_em": "2026-11-16T10:00:00Z", "turno_id": "$turno",
         "vaga": {"id": "vaga-1", "funcao": "Garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                  "inicio_em": "2026-12-01T21:00:00Z", "fim_em": "2026-12-02T03:00:00Z", "valor_centavos": 16000}}
    """.trimIndent()

    private fun turno(id: String, estado: String, cancelamento: String) = """
        {"id": "$id", "posicao_id": "posicao-$id",
         "vaga": {"id": "vaga-1", "funcao": "Garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                  "inicio_em": "2026-12-01T21:00:00Z", "fim_em": "2026-12-02T03:00:00Z", "valor_centavos": 16000},
         "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                         "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
         "contato_visivel_ate": null, "a_caminho_em": null, "checkin_em": null, "checkin_tipo": null, "checkin_distancia_m": null,
         "checkin_confirmado_em": null, "checkout_em": null, "checkout_distancia_m": null, "verificacao": "pendente",
         "valor_acordado_centavos": 16000, "pode_avaliar": false, "estado": "$estado", "avaliacao": null, "cancelamento": $cancelamento}
    """.trimIndent()

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @AfterEach
    fun depois() {
        // Espera as chamadas do Ktor antes de repor o Main (hWad2l0H).
        cliente?.encerrarEEsperar()
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `o grafo cruza a candidatura aceita com meus_turnos pelo turno_id e marca a de turno cancelado`() {
        val c = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                val caminho = request.url.encodedPath
                caminhos += caminho
                val corpo = when {
                    caminho.endsWith("minhas_candidaturas") -> "[${candidatura("c1", "t1")}, ${candidatura("c2", "t2")}]"
                    caminho.endsWith("meus_turnos") ->
                        "[${turno("t1", "cancelada", """{"causa": "estabelecimento", "falta": false, "cancelada_em": "2026-11-20T10:00:00Z"}""")}, " +
                            "${turno("t2", "confirmada", "null")}]"
                    else -> "{}"
                }
                respond(corpo, HttpStatusCode.OK, json)
            },
        ).also { cliente = it }
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDeCandidaturas, moduloFeatures) +
                    module {
                        single { ServicoVagas(c) }
                        single { ServicoTurnos(c) }
                    },
            )
        }

        val vm = get<MinhasCandidaturasViewModel>()
        runBlocking { vm.carregar().join() }

        val lista = vm.estado.value.lista as ListaDeCandidaturas.Carregadas
        val itens = (lista.pendentes + lista.anteriores).associateBy { it.id }
        assertTrue(itens.getValue("c1").turnoCancelado, "o turno t1 esta cancelado em meus_turnos")
        assertFalse(itens.getValue("c2").turnoCancelado, "o turno t2 esta de pe")
        assertEquals(1, caminhos.count { it.endsWith("minhas_candidaturas") })
        assertEquals(1, caminhos.count { it.endsWith("meus_turnos") })
    }
}
