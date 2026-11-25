package br.com.frila.app

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class ConfiguracaoDoAppGuardadaTest {

    private class CacheEmMemoria : CacheDeConfiguracaoDoApp {
        val guardado = mutableMapOf<String, ConfiguracaoDoAppDto>()
        override fun ler(plataforma: String, versaoApp: String?) = guardado["$plataforma|$versaoApp"]
        override fun gravar(versaoApp: String?, configuracao: ConfiguracaoDoAppDto) {
            guardado["${configuracao.plataforma}|$versaoApp"] = configuracao
        }
    }

    private fun configuracao(busca: Boolean, chamada: Boolean = busca, minima: String = "1.0.0") = ConfiguracaoDoAppDto(
        plataforma = "android",
        versaoMinima = minima,
        mensagem = "Atualize",
        recursos = RecursosDoAppDto(chamadaDireta = chamada, buscaProfissionais = busca),
    )

    @Test
    fun `o prazo da configuracao e de 10 segundos`() {
        assertEquals(10_000L, TEMPO_MAXIMO_CONFIGURACAO_MS)
    }

    @Test
    fun `configuracao que demora mais de 3 segundos ainda liga as chaves`() = runTest {
        val cache = CacheEmMemoria()

        val resultado = obterConfiguracaoDoApp(cache, versaoApp = "1.2.0") {
            delay(5_000)
            configuracao(busca = true)
        }

        assertNotNull(resultado)
        assertTrue(resultado!!.recursos.buscaProfissionais)
        assertTrue(resultado.recursos.chamadaDireta)
    }

    @Test
    fun `configuracao recebida fica guardada para a versao do app`() = runTest {
        val cache = CacheEmMemoria()

        obterConfiguracaoDoApp(cache, versaoApp = "1.2.0") { configuracao(busca = true) }

        assertTrue(cache.ler("android", "1.2.0")!!.recursos.buscaProfissionais)
        assertNull(cache.ler("android", "1.3.0"))
    }

    @Test
    fun `estourou o prazo com configuracao guardada usa a guardada`() = runTest {
        val cache = CacheEmMemoria().apply { gravar("1.2.0", configuracao(busca = true, minima = "1.1.0")) }

        val resultado = obterConfiguracaoDoApp(cache, versaoApp = "1.2.0") {
            delay(60_000)
            configuracao(busca = false)
        }

        assertTrue(resultado!!.recursos.buscaProfissionais)
        assertEquals("1.1.0", resultado.versaoMinima)
    }

    @Test
    fun `falha de rede com configuracao guardada usa a guardada`() = runTest {
        val cache = CacheEmMemoria().apply { gravar("1.2.0", configuracao(busca = true)) }

        val resultado = obterConfiguracaoDoApp(cache, versaoApp = "1.2.0") { throw IOException("sem rede") }

        assertTrue(resultado!!.recursos.buscaProfissionais)
    }

    @Test
    fun `sem rede e sem guardado devolve nulo e o chamador mantem tudo desligado`() = runTest {
        val resultado = obterConfiguracaoDoApp(CacheEmMemoria(), versaoApp = "1.2.0") {
            delay(60_000)
            configuracao(busca = true)
        }

        assertNull(resultado)
    }

    @Test
    fun `guardado de outra versao do app nao vale`() = runTest {
        val cache = CacheEmMemoria().apply { gravar("1.1.0", configuracao(busca = true)) }

        val resultado = obterConfiguracaoDoApp(cache, versaoApp = "1.2.0") { throw IOException("sem rede") }

        assertNull(resultado)
    }

    @Test
    fun `cache em preferencias guarda e le a configuracao por plataforma e versao`() {
        val contexto = ApplicationProvider.getApplicationContext<Context>()
        val cache = CacheDeConfiguracaoDoAppPreferencias(contexto)
        val original = configuracao(busca = true, chamada = false, minima = "2.0.0")

        cache.gravar("1.2.0", original)

        val lida = cache.ler("android", "1.2.0")!!
        assertEquals("2.0.0", lida.versaoMinima)
        assertEquals("Atualize", lida.mensagem)
        assertTrue(lida.recursos.buscaProfissionais)
        assertFalse(lida.recursos.chamadaDireta)
        assertNull(cache.ler("android", "1.3.0"))
        assertNull(cache.ler("ios", "1.2.0"))
    }

    @Test
    fun `guardado corrompido vale como sem guardado`() {
        val contexto = ApplicationProvider.getApplicationContext<Context>()
        contexto.getSharedPreferences("configuracao_do_app", Context.MODE_PRIVATE)
            .edit().putString("android|9.9.9", "{isso nao e json").commit()

        assertNull(CacheDeConfiguracaoDoAppPreferencias(contexto).ler("android", "9.9.9"))
    }

    private class AberturaSimulada(
        escopo: CoroutineScope,
        scheduler: TestCoroutineScheduler,
        guardada: ConfiguracaoDoAppDto? = null,
        consulta: suspend () -> ConfiguracaoDoAppDto,
    ) {
        val cache = CacheEmMemoria().apply { if (guardada != null) gravar("1.2.0", guardada) }
        var estado = EstadoDaConfiguracaoDoApp()
        var verificando = true
        val job: Job = escopo.launch {
            carregarConfiguracaoNaAbertura(
                cache = cache,
                versaoApp = "1.2.0",
                aoAplicar = { estado = it },
                aoLiberarAbertura = { verificando = false },
                dispatcherIo = StandardTestDispatcher(scheduler),
                consulta = consulta,
            )
        }
    }

    private fun todasChaves(ligadas: Boolean) = RecursosDoAppDto(
        fotoDePerfil = ligadas,
        chamadaDireta = ligadas,
        perfilRico = ligadas,
        checkinPorCodigo = ligadas,
        buscaProfissionais = ligadas,
    )

    @Test
    fun `paraEstado limpa mensagem nula ou em branco para a padrao e preserva mensagem explicita`() {
        val nula = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "1.0.0", mensagem = null).paraEstado()
        val emBranco = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "1.0.0", mensagem = "   ").paraEstado()
        val explicita = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "1.0.0", mensagem = "B").paraEstado()

        assertEquals(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO, nula.mensagemBloqueio)
        assertEquals(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO, emBranco.mensagemBloqueio)
        assertEquals("B", explicita.mensagemBloqueio)
    }

    @Test
    fun `cada uma das cinco chaves de recurso mapeia para o campo certo sem troca`() {
        val casos = listOf(
            RecursosDoAppDto(fotoDePerfil = true) to EstadoDaConfiguracaoDoApp(versaoMinima = "1.0.0", fotoDePerfil = true),
            RecursosDoAppDto(chamadaDireta = true) to EstadoDaConfiguracaoDoApp(versaoMinima = "1.0.0", chamadaDireta = true),
            RecursosDoAppDto(perfilRico = true) to EstadoDaConfiguracaoDoApp(versaoMinima = "1.0.0", perfilRico = true),
            RecursosDoAppDto(checkinPorCodigo = true) to EstadoDaConfiguracaoDoApp(versaoMinima = "1.0.0", checkinPorCodigo = true),
            RecursosDoAppDto(buscaProfissionais = true) to EstadoDaConfiguracaoDoApp(versaoMinima = "1.0.0", buscaProfissionais = true),
        )
        casos.forEach { (recursos, esperado) ->
            assertEquals(esperado, ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "1.0.0", recursos = recursos).paraEstado())
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `guardada com mensagem A seguida de resposta nula ou em branco volta para a mensagem padrao`() = runTest {
        listOf<String?>(null, "   ").forEach { mensagemDoServidor ->
            val abertura = AberturaSimulada(
                this,
                testScheduler,
                guardada = ConfiguracaoDoAppDto("android", "99.0.0", mensagem = "A"),
            ) {
                delay(TEMPO_MAXIMO_ABERTURA_MS + 1_000L)
                ConfiguracaoDoAppDto("android", "99.0.0", mensagem = mensagemDoServidor)
            }
            runCurrent()
            assertFalse(abertura.verificando)
            assertEquals("A", abertura.estado.mensagemBloqueio)

            advanceUntilIdle()
            assertEquals(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO, abertura.estado.mensagemBloqueio)
            abertura.job.join()
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `resposta atrasada depois da abertura aplica as cinco chaves mensagem e versao minima`() = runTest {
        val abertura = AberturaSimulada(
            this,
            testScheduler,
            guardada = ConfiguracaoDoAppDto("android", "99.0.0", mensagem = "A", recursos = todasChaves(false)),
        ) {
            delay(TEMPO_MAXIMO_ABERTURA_MS + 1_000L)
            ConfiguracaoDoAppDto("android", "1.0.0", mensagem = null, recursos = todasChaves(true))
        }
        runCurrent()
        assertFalse(abertura.verificando)
        assertEquals(EstadoDaConfiguracaoDoApp(versaoMinima = "99.0.0", mensagemBloqueio = "A"), abertura.estado)

        advanceUntilIdle()
        assertEquals(
            EstadoDaConfiguracaoDoApp(
                versaoMinima = "1.0.0",
                mensagemBloqueio = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
                fotoDePerfil = true,
                chamadaDireta = true,
                perfilRico = true,
                checkinPorCodigo = true,
                buscaProfissionais = true,
            ),
            abertura.estado,
        )
        abertura.job.join()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `sem guardada libera no prazo de abertura e aplica chaves mensagem e minima quando resposta atrasa`() = runTest {
        val abertura = AberturaSimulada(this, testScheduler) {
            delay(TEMPO_MAXIMO_ABERTURA_MS + 1_000L)
            ConfiguracaoDoAppDto("android", "1.0.0", mensagem = "B", recursos = todasChaves(true))
        }
        advanceTimeBy(TEMPO_MAXIMO_ABERTURA_MS - 1)
        runCurrent()
        assertTrue(abertura.verificando)

        advanceTimeBy(1)
        runCurrent()
        assertFalse(abertura.verificando)
        assertEquals(EstadoDaConfiguracaoDoApp(), abertura.estado)

        advanceUntilIdle()
        assertEquals(
            EstadoDaConfiguracaoDoApp(
                versaoMinima = "1.0.0",
                mensagemBloqueio = "B",
                fotoDePerfil = true,
                chamadaDireta = true,
                perfilRico = true,
                checkinPorCodigo = true,
                buscaProfissionais = true,
            ),
            abertura.estado,
        )
        abertura.job.join()
    }
}
