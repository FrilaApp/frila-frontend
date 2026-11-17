package br.com.frila.app

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.Url
import io.ktor.http.headersOf
import io.mockk.Called
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/**
 * Privacidade (dado pessoal: localização): abrir ou atualizar a lista de vagas não lê a posição do aparelho nem manda coordenada ao servidor.
 * O `vagas_abertas` vai sem `latitude` e sem `longitude`, e o servidor ordena pelo ponto base do perfil, como no iOS. A posição só é lida no
 * toque de marcar presença e saída.
 *
 * Roda no grafo real do app: o provedor de localização fica registrado (o check-in precisa dele) e, mesmo com permissão e posição
 * disponíveis, o feed não o toca.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class FeedSemLocalizacaoTest : KoinTest {

    private val pedidos = mutableListOf<Url>()

    private val provedor = mockk<ProvedorDeLocalizacao>(relaxed = true).also {
        coEvery { it.obterCoordenadaAtual() } returns Coordenada(latitude = -15.79, longitude = -47.88)
    }

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                pedidos += request.url
                respond("[]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloFeatures) + module {
                    single<ProvedorDeLocalizacao> { provedor }
                    single { ServicoVagas(cliente) }
                },
            )
        }
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun conferirSemPosicao() {
        val pedido = pedidos.single()
        assertEquals("/rest/v1/rpc/vagas_abertas", pedido.encodedPath)
        assertFalse(pedido.parameters.contains("latitude"), "o pedido de vagas_abertas levou latitude: $pedido")
        assertFalse(pedido.parameters.contains("longitude"), "o pedido de vagas_abertas levou longitude: $pedido")
        verify { provedor wasNot Called }
    }

    @Test
    fun `abrir a lista de vagas nao pede a posicao nem manda latitude e longitude`() = runBlocking {
        get<FeedVagasViewModel>().carregar().join()

        conferirSemPosicao()
    }

    @Test
    fun `atualizar a lista de vagas nao pede a posicao nem manda latitude e longitude`() = runBlocking {
        get<FeedVagasViewModel>().atualizar().join()

        conferirSemPosicao()
    }
}
