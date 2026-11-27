package br.com.frila.app.diagnostico

import java.io.PrintWriter
import java.io.StringWriter
import java.time.Instant
import kotlin.coroutines.AbstractCoroutineContextElement
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.CoroutineExceptionHandler

/**
 * DIAGNOSTICO TEMPORARIO (hWad2l0H), PR de laboratorio que não será mesclado: imprime em stderr toda exceção de corrotina
 * que chega ao handler global, com a pilha completa e a cadeia de causas. A classe em curso vem das linhas "DIAG-CLASSE"
 * que o build imprime a cada classe de teste.
 */
class DiagnosticoDeVazamentos : AbstractCoroutineContextElement(CoroutineExceptionHandler), CoroutineExceptionHandler {
    override fun handleException(context: CoroutineContext, exception: Throwable) {
        val pilha = StringWriter().also { exception.printStackTrace(PrintWriter(it)) }
        System.err.println(
            "DIAG-VAZAMENTO [${Instant.now()}] thread=${Thread.currentThread().name}\n" +
                "DIAG-VAZAMENTO contexto=$context\n" +
                pilha.toString().lines().joinToString("\n") { "DIAG-VAZAMENTO $it" },
        )
    }
}
