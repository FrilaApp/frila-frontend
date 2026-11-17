package br.com.frila.app.falhas

import java.io.File
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-6: o que vai ao destino é só código, rota e duração, e nada vai com a coleta desligada. */
class TelemetriaDeFalhasTest {

    private class DestinoEspiao : DestinoDeFalhas {
        val gravados = mutableListOf<Triple<String, String, Long>>()
        override fun gravar(codigo: String, rpc: String, duracaoNs: Long) { gravados += Triple(codigo, rpc, duracaoNs) }
    }

    @Test
    fun `com a coleta desligada nada chega ao destino`() {
        val destino = DestinoEspiao()
        TelemetriaDeFalhas(coletaLigada = false, destino = destino).registrarErroDaApi("sem_permissao", "minha_conta", 1_500_000)
        assertTrue(destino.gravados.isEmpty())
    }

    @Test
    fun `com a coleta ligada o destino recebe so codigo rota e duracao`() {
        val destino = DestinoEspiao()
        TelemetriaDeFalhas(coletaLigada = true, destino = destino).registrarErroDaApi("sem_permissao", "minha_conta", 1_500_000)
        assertEquals(listOf(Triple("sem_permissao", "minha_conta", 1_500_000L)), destino.gravados)
    }

    @Test
    fun `o registro do Crashlytics tem excecao sem pilha e so as tres chaves`() {
        val registro = RegistroDeFalha.montar("sem_permissao", "minha_conta", 1_500_000)
        assertEquals("erro_api_sem_permissao", registro.excecao.message)
        assertEquals(0, registro.excecao.stackTrace.size, "a pilha levaria nome de classe e linha do app")
        assertEquals(mapOf<String, Any>("codigo" to "sem_permissao", "rpc" to "minha_conta", "duracao_ns" to 1_500_000L), registro.chaves)
    }

    @Test
    fun `o codigo do app nunca chama o identificador de usuario do Crashlytics`() {
        val pasta = File("src/main/kotlin/br/com/frila/app/falhas")
        val codigo = pasta.walkTopDown().filter { it.extension == "kt" }
            .flatMap { it.readLines().asSequence() }
            .filterNot { it.trim().startsWith("//") || it.trim().startsWith("*") || it.trim().startsWith("/*") }
            .joinToString("\n")
        assertTrue(pasta.isDirectory)
        assertFalse(Regex("""setUserId|setUserIdentifier""", RegexOption.IGNORE_CASE).containsMatchIn(codigo))
    }
}
