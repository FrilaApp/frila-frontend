package br.com.frila.app

import br.com.frila.core.localizacao.RemovedorDeGeofencesAntigos
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/**
 * O geofence de aproximação saiu do app. Na abertura, o que uma versão anterior deixou registrado no Play Services é cancelado
 * pelo id de cada turno da conta; sem sessão não há ids e nada é pedido ao servidor.
 */
class LimpezaDeGeofencesAntigosTest : KoinTest {

    @AfterEach
    fun depois() = stopKoin()

    private class Registro {
        val removidos = mutableListOf<List<String>>()
        var leiturasDosTurnos = 0
    }

    private fun limpeza(registro: Registro, comSessao: Boolean, turnos: suspend () -> List<String>) = LimpezaDeGeofencesAntigos(
        temSessao = { comSessao },
        idsDosTurnos = { registro.leiturasDosTurnos++; turnos() },
        remover = { registro.removidos += it },
    )

    @Test
    fun `com sessao remove o geofence de cada turno da conta`() = runBlocking {
        val registro = Registro()

        limpeza(registro, comSessao = true) { listOf("turno-agendado", "turno-de-ontem") }.executar()

        assertEquals(listOf(listOf("turno-agendado", "turno-de-ontem")), registro.removidos)
    }

    @Test
    fun `sem sessao nao le os turnos nem remove nada`() = runBlocking {
        val registro = Registro()

        limpeza(registro, comSessao = false) { listOf("turno-1") }.executar()

        assertEquals(0, registro.leiturasDosTurnos)
        assertTrue(registro.removidos.isEmpty())
    }

    @Test
    fun `falha ao ler os turnos nao lanca e nao remove nada`() = runBlocking {
        val registro = Registro()

        limpeza(registro, comSessao = true) { throw IllegalStateException("sem rede") }.executar()

        assertTrue(registro.removidos.isEmpty())
    }

    @Test
    fun `no grafo do app a limpeza le meus_turnos e manda remover os ids que vieram`() = runBlocking {
        val pedidos = mutableListOf<String>()
        val removidos = mutableListOf<List<String>>()
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                pedidos += request.url.encodedPath
                respond("[]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures) + module {
                    single { ServicoTurnos(cliente) }
                    single<RemovedorDeGeofencesAntigos> { RemovedorDeGeofencesAntigos { removidos += it } }
                },
            )
        }
        get<ArmazenamentoDeSessao>().salvarSessao(Sessao(accessToken = "token-de-teste", refreshToken = "renovacao-de-teste", tokenType = "bearer", expiresIn = 3600))

        get<LimpezaDeGeofencesAntigos>().executar()

        assertEquals(listOf("/rest/v1/rpc/meus_turnos"), pedidos)
        assertEquals(listOf(emptyList<String>()), removidos)
    }

    @Test
    fun `a abertura do app dispara a limpeza`() {
        val aplicacao = File("src/main/kotlin/br/com/frila/app/FrilaApplication.kt").readText()
        val abertura = aplicacao.substringAfter("override fun onCreate()").substringBefore("\n    }")

        assertTrue("cancelarGeofencesAntigos()" in abertura, "onCreate tem de chamar cancelarGeofencesAntigos(): $abertura")
    }
}
