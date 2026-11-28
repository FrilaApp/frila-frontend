package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.engine.HttpClientEngine
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking

/**
 * Fecha o cliente de um teste e espera o trabalho dele terminar. Teste que troca o `Dispatchers.Main` (`setMain`/`resetMain`)
 * chama isto ANTES de repor o Main: a corrotina de chamada do Ktor termina em outra thread, e se o `join()` do teste volta
 * antes dela, a continuação que despacha em `Main` roda depois do `resetMain`, falha ("main looper is not available") e a
 * exceção cai no próximo `runTest` da mesma JVM (`UncaughtExceptionsBeforeTest`, hWad2l0H).
 */
internal fun ClienteSupabase.encerrarEEsperar() = runBlocking {
    val trabalho = http.coroutineContext[Job]
    close()
    trabalho?.join()
}

private val clientesDoTeste = CopyOnWriteArrayList<ClienteSupabase>()

/**
 * Cria um [ClienteSupabase] de teste e o registra para [encerrarOsClientesDoTeste]. É o `ClienteSupabase(...)` das classes que
 * trocam o Main: cada uma o usa no lugar do construtor e chama [encerrarOsClientesDoTeste] no `@AfterEach`, antes do
 * `stopKoin()`/`resetMain()`.
 */
internal fun clienteSupabaseDeTeste(baseUrl: String, apiKey: String, engine: HttpClientEngine? = null): ClienteSupabase =
    ClienteSupabase(baseUrl = baseUrl, apiKey = apiKey, engine = engine).also { clientesDoTeste += it }

/** Fecha e espera todos os clientes criados por [clienteSupabaseDeTeste] desde a última chamada. */
internal fun encerrarOsClientesDoTeste() {
    val abertos = clientesDoTeste.toList()
    clientesDoTeste.clear()
    abertos.forEach { it.encerrarEEsperar() }
}
