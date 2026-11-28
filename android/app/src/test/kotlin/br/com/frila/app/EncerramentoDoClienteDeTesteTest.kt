package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * hWad2l0H. Uma chamada do Ktor em voo, iniciada de uma corrotina em `Dispatchers.Main`, termina depois de o teste repor o
 * Main. Medido aqui: sem esperar o cliente, o chamador nunca retoma (a continuação que despacharia em Main se perde); esperando
 * o cliente antes do `resetMain`, retoma e nada vaza. Na CI (KoinGrafoLote2Test) a mesma causa apareceu como exceção do
 * Ktor no handler global, que o `runTest` seguinte cobrou. A exceção em si não foi reproduzida isoladamente.
 */
class EncerramentoDoClienteDeTesteTest {

    private class Resultado(val chamadorRetomou: Boolean, val vazadas: List<Throwable>)

    /** Se o chamador da chamada em voo retomou, e as exceções não tratadas que chegaram à thread do Ktor (o `runTest` seguinte as cobraria). */
    private fun cenario(encerrar: Boolean): Resultado {
        val retomou = CompletableDeferred<Unit>()
        val vazadas = CopyOnWriteArrayList<Throwable>()
        val anterior = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { _, erro -> vazadas += erro }
        Dispatchers.setMain(UnconfinedTestDispatcher())
        try {
            runBlocking {
                val emVoo = CompletableDeferred<Unit>()
                val cliente = ClienteSupabase(
                    baseUrl = "https://frila.supabase.co",
                    apiKey = "chave-teste",
                    engine = MockEngine {
                        emVoo.complete(Unit)
                        // Tempo real, em thread própria: o `delay` herdaria o dispatcher de teste e andaria em tempo virtual.
                        withContext(Dispatchers.IO) { Thread.sleep(300) }
                        respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                    },
                )
                CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate).launch {
                    runCatching { cliente.http.get("https://frila.supabase.co/rest/v1/rpc/situacao_da_conta") }
                    retomou.complete(Unit)
                }
                emVoo.await()
                if (encerrar) cliente.encerrarEEsperar()
                Dispatchers.resetMain()
                // Tempo real para a chamada terminar e a continuação tentar despachar em Main.
                withContext(Dispatchers.Default) { delay(700) }
            }
        } finally {
            Dispatchers.resetMain()
            Thread.setDefaultUncaughtExceptionHandler(anterior)
        }
        return Resultado(retomou.isCompleted, vazadas.toList())
    }

    private fun Throwable.cadeia(): Sequence<Throwable> = generateSequence(this) { it.cause }

    @Test
    fun `sem esperar o cliente, a chamada em voo se perde depois do resetMain e o chamador nunca retoma`() {
        val r = cenario(encerrar = false)
        assertFalse(r.chamadorRetomou, "esperava a continuacao perdida; este teste documenta o defeito (na CI ele aparece como excecao no runTest seguinte)")
    }

    @Test
    fun `esperando o cliente antes do resetMain, o chamador retoma e nada vaza`() {
        val r = cenario(encerrar = true)
        assertTrue(r.chamadorRetomou, "o chamador deveria retomar antes de o Main ser reposto")
        assertEquals(emptyList<Throwable>(), r.vazadas)
    }

    @Test
    fun `encerrarOsClientesDoTeste fecha e espera cada cliente da fabrica e esvazia o registro`() {
        val a = clienteSupabaseDeTeste("https://frila.supabase.co", "chave-teste")
        val b = clienteSupabaseDeTeste("https://frila.supabase.co", "chave-teste")
        val trabalhoA = a.http.coroutineContext[kotlinx.coroutines.Job]!!
        val trabalhoB = b.http.coroutineContext[kotlinx.coroutines.Job]!!
        assertTrue(trabalhoA.isActive && trabalhoB.isActive)

        encerrarOsClientesDoTeste()

        assertTrue(trabalhoA.isCompleted, "o primeiro cliente deveria estar fechado e terminado")
        assertTrue(trabalhoB.isCompleted, "o segundo cliente deveria estar fechado e terminado")
        val c = clienteSupabaseDeTeste("https://frila.supabase.co", "chave-teste")
        encerrarOsClientesDoTeste()
        assertTrue(c.http.coroutineContext[kotlinx.coroutines.Job]!!.isCompleted, "o registro foi esvaziado e o novo cliente tambem fecha")
    }
}
