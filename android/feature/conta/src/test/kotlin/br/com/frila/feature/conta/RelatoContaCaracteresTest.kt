package br.com.frila.feature.conta

import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão BOZIhNlL (item 214): o servidor conta CARACTERES do relato (`char_length`/`length` de `text`, depois de `btrim`), não unidades
 * UTF-16. Um emoji vale 1 lá e 2 em `String.length`. O mínimo de 10 vale por caracteres: "12345678" + emoji tem 9 e é recusado
 * (antes passava aqui e voltava 422 do servidor); "123456789" + emoji tem 10 e é aceito.
 */
class RelatoContaCaracteresTest {

    private val emoji = "😀" // 1 caractere, 2 unidades UTF-16
    private val nove = "12345678$emoji" // 9 caracteres, 10 unidades
    private val dez = "123456789$emoji" // 10 caracteres, 11 unidades

    // ---- Contestar o despacho ----

    private val enviadosDoDespacho = mutableListOf<String>()

    private fun despacho() = ContestarDespachoViewModel(
        pedirRevisao = { texto -> enviadosDoDespacho += texto; protocoloDoServidor(tipo = "revisao_despacho") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `despacho, 9 caracteres com emoji nao vao ao servidor, mesmo com 10 unidades UTF-16`() {
        for (relato in listOf(nove, "  $nove  ")) {
            val vm = despacho()
            vm.mudarRelato(relato)
            assertFalse(vm.estado.value.relatoValido, relato)

            assertNull(vm.contestar(), relato)

            assertEquals(TextosContestarDespacho.RELATO_MINIMO, vm.estado.value.mensagemErro, relato)
        }
        assertTrue(enviadosDoDespacho.isEmpty())
    }

    @Test
    fun `despacho, 10 caracteres com emoji vao ao servidor, com o emoji inteiro`() {
        val vm = despacho()
        vm.mudarRelato("  $dez  ")
        assertTrue(vm.estado.value.relatoValido)

        assertNotNull(vm.contestar())

        assertEquals(listOf(dez), enviadosDoDespacho)
    }

    @Test
    fun `despacho, 5 emojis nao bastam e 10 emojis bastam`() {
        val cinco = emoji.repeat(5)
        val vm = despacho()
        vm.mudarRelato(cinco)
        assertFalse(vm.estado.value.relatoValido)
        assertNull(vm.contestar())

        vm.mudarRelato(emoji.repeat(10))
        assertTrue(vm.estado.value.relatoValido)
        assertNotNull(vm.contestar())
    }

    // ---- Contestar a suspensão da conta ----

    private val enviadosDaSuspensao = mutableListOf<String>()

    private fun suspensao() = ContaSuspensaViewModel(
        buscarSituacao = {
            SituacaoDaContaDto(
                estado = "suspensa",
                suspensao = SuspensaoDaContaDto(motivo = "Faltas sem aviso", desde = "2026-11-10T12:00:00Z", contestacao = null),
            )
        },
        contestar = { texto -> enviadosDaSuspensao += texto; protocoloDoServidor() },
        aoReativar = {},
        relogio = { Instant.parse("2026-11-17T15:00:00Z") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    ).also {
        it.carregar()
        it.abrirFormulario()
    }

    @Test
    fun `suspensao, 9 caracteres com emoji nao vao ao servidor, mesmo com 10 unidades UTF-16`() {
        for (relato in listOf(nove, "  $nove  ")) {
            val vm = suspensao()
            vm.mudarRelato(relato)
            assertFalse(vm.estado.value.relatoValido, relato)

            assertNull(vm.enviarContestacao(), relato)

            assertEquals(TextosContaSuspensa.RELATO_MINIMO, vm.estado.value.mensagemErro, relato)
        }
        assertTrue(enviadosDaSuspensao.isEmpty())
    }

    @Test
    fun `suspensao, 10 caracteres com emoji vao ao servidor, com o emoji inteiro`() {
        val vm = suspensao()
        vm.mudarRelato("  $dez  ")
        assertTrue(vm.estado.value.relatoValido)

        assertNotNull(vm.enviarContestacao())

        assertEquals(listOf(dez), enviadosDaSuspensao)
    }

    @Test
    fun `suspensao, 5 emojis nao bastam e 10 emojis bastam`() {
        val vm = suspensao()
        vm.mudarRelato(emoji.repeat(5))
        assertFalse(vm.estado.value.relatoValido)
        assertNull(vm.enviarContestacao())

        vm.mudarRelato(emoji.repeat(10))
        assertTrue(vm.estado.value.relatoValido)
        assertNotNull(vm.enviarContestacao())
    }
}
