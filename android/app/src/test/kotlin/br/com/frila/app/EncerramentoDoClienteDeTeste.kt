package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
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
