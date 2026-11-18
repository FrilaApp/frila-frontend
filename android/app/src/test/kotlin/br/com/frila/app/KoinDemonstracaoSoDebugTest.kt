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
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeFalse
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/**
 * Fixa o que o `ModulosKoin.kt` decide com `permitirDominioDeTeste = BuildConfig.DEBUG`: a entrada por conta de
 * demonstração (`@frila.test`, `/functions/v1/entrar-demonstracao`) existe só no build debug. No release, um e-mail
 * `@frila.test` segue o caminho normal (`/auth/v1/otp` e `/auth/v1/verify`).
 *
 * Cada teste vale numa variante: o debug roda em `testDebugUnitTest` (o que a CI roda) e o release só em
 * `testReleaseUnitTest`. Trocar `BuildConfig.DEBUG` por `true` no `ModulosKoin.kt` só quebra a variante release.
 * Complementa o `KoinContasDeDemonstracaoTest` (debug), que já prova o lado do debug.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinDemonstracaoSoDebugTest : KoinTest {
    private val email = "qualquer@frila.test"
    private val pedidos = mutableListOf<String>()

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        pedidos.clear()
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
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `no build debug o email de teste entra pela demonstracao e nao pede OTP`() = runBlocking {
        assumeTrue(BuildConfig.DEBUG, "só vale no build debug")

        val entrada = get<EntradaViewModel>()
        entrada.aoMudarEmail(email)
        assertTrue(entrada.estado.value.ehContaDeDemonstracao)
        entrada.solicitarCodigo()?.join()
        assertTrue(pedidos.isEmpty(), "debug não solicita OTP para o domínio de teste: $pedidos")

        get<CodigoViewModel> { parametersOf(email) }.aoMudarCodigo("123456")?.join()
        assertEquals(listOf("/functions/v1/entrar-demonstracao"), pedidos)
    }

    @Test
    fun `no build release o email de teste NAO vai a entrar-demonstracao e segue o OTP normal`() = runBlocking {
        assumeFalse(BuildConfig.DEBUG, "só vale no build release")

        val entrada = get<EntradaViewModel>()
        entrada.aoMudarEmail(email)
        assertFalse(entrada.estado.value.ehContaDeDemonstracao, "release não trata @frila.test como demonstração")
        entrada.solicitarCodigo()?.join()
        assertEquals(listOf("/auth/v1/otp"), pedidos)
        assertTrue(entrada.estado.value.otpSolicitado)

        val codigo = get<CodigoViewModel> { parametersOf(email) }
        codigo.aoMudarCodigo("123456")?.join()
        assertEquals(listOf("/auth/v1/otp", "/auth/v1/verify"), pedidos)
        assertFalse(pedidos.any { it.contains("entrar-demonstracao") }, "release não chama a demonstração: $pedidos")
    }
}
