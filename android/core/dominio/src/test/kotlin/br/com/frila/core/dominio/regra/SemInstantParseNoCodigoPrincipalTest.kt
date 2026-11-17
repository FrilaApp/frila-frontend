package br.com.frila.core.dominio.regra

import java.io.File
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Guarda do leitor único de datas. O servidor devolve instantes com `+00:00` e `Instant.parse` só lê esse
 * formato a partir do Java 12: no Android 9 a 11 ele lança exceção. Os testes de `instanteDoServidor` rodam
 * no Java 17, onde `Instant.parse` também leria, então sozinhos não pegam a volta do defeito. Este teste
 * varre o código principal e falha se alguém voltar a usar `Instant.parse(` para ler dado do servidor.
 *
 * Única exceção: `AppNavegacao.kt`, que lê de volta um `Instant.toString()` escrito pelo próprio app num
 * argumento de rota (sempre termina em `Z`).
 */
class SemInstantParseNoCodigoPrincipalTest {

    private val chamada = Regex("""\bInstant\.parse\(""")

    /** Arquivo → quantas chamadas são aceitas nele. */
    private val excecoes = mapOf("AppNavegacao.kt" to 1)

    private fun raizDoAndroid(): File {
        var pasta: File? = File(System.getProperty("user.dir")).absoluteFile
        while (pasta != null && !File(pasta, "settings.gradle.kts").exists()) pasta = pasta.parentFile
        return requireNotNull(pasta) { "não achei settings.gradle.kts acima de ${System.getProperty("user.dir")}" }
    }

    @Test
    fun `codigo principal so le data do servidor pelo leitor unico`() {
        val raiz = raizDoAndroid()
        val arquivos = raiz.walkTopDown()
            .onEnter { it.name != "build" && it.name != ".gradle" }
            .filter { it.isFile && it.extension == "kt" && it.path.contains("${File.separator}src${File.separator}main${File.separator}") }
            .toList()
        assertTrue(arquivos.size > 100, "a varredura achou só ${arquivos.size} arquivos em $raiz: caminho errado?")

        val achados = arquivos.mapNotNull { arquivo ->
            val linhas = arquivo.readLines().withIndex().filter { chamada.containsMatchIn(it.value) }.map { it.index + 1 }
            if (linhas.isEmpty()) null else arquivo to linhas
        }
        val foraDaRegra = achados
            .filter { (arquivo, linhas) -> linhas.size > (excecoes[arquivo.name] ?: 0) }
            .map { (arquivo, linhas) -> "${arquivo.relativeTo(raiz)}:${linhas.joinToString(",")}" }

        assertEquals(
            emptyList<String>(),
            foraDaRegra,
            "Use instanteDoServidor(...) no lugar de Instant.parse(...) para ler data do servidor",
        )
    }
}
