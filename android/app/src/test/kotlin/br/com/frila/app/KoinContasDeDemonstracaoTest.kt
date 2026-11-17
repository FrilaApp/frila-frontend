package br.com.frila.app

import br.com.frila.core.notificacoes.RegistradorDeDispositivo
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

@OptIn(ExperimentalCoroutinesApi::class)
class KoinContasDeDemonstracaoTest : KoinTest {
    @BeforeEach
    fun antes() { Dispatchers.setMain(UnconfinedTestDispatcher()) }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `debug aceita o dominio de teste nos dois ViewModels do grafo real`() = runBlocking {
        val pedidos = mutableListOf<String>()
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { request ->
            pedidos += request.url.encodedPath
            respond(
                """{"access_token":"token-teste","refresh_token":"refresh-teste","token_type":"bearer","expires_in":3600}""",
                HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"),
            )
        })
        startKoin {
            modules(moduloFeatures, module {
                single { ServicoAutenticacao(cliente) }
                single<ArmazenamentoDeSessao> { ArmazenamentoDeSessaoEmMemoria() }
                single { mockk<RegistradorDeDispositivo>(relaxed = true) }
            })
        }
        val entrada = get<EntradaViewModel>()
        entrada.aoMudarEmail("qualquer@frila.test")
        assertTrue(entrada.estado.value.ehContaDeDemonstracao)
        entrada.solicitarCodigo()?.join()
        assertTrue(entrada.estado.value.otpSolicitado)
        assertTrue(pedidos.isEmpty(), "debug não solicita OTP para o domínio de teste")

        val codigo = get<CodigoViewModel> { parametersOf("qualquer@frila.test") }
        codigo.aoMudarCodigo("123456")?.join()
        assertEquals(listOf("/functions/v1/entrar-demonstracao"), pedidos)
        assertTrue(codigo.estado.value.autenticado)
    }
}
