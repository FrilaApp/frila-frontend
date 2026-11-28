package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.DenunciarDto
import br.com.frila.core.rede.ProtocoloDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão BOZIhNlL (item 214): `denunciar` no servidor conta caracteres (`char_length` depois de `btrim`), não unidades UTF-16. Um emoji
 * vale 1 lá e 2 em `String.length`: "12345678" + emoji tem 9 caracteres e é recusado; "123456789" + emoji tem 10 e é aceito.
 */
class RelatoDaDenunciaContaCaracteresTest {

    private val emoji = "😀" // 1 caractere, 2 unidades UTF-16
    private val nove = "12345678$emoji" // 9 caracteres, 10 unidades
    private val dez = "123456789$emoji" // 10 caracteres, 11 unidades

    private val enviados = mutableListOf<DenunciarDto>()

    private fun viewModel() = DenunciaViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
        alvoId = "11111111-1111-1111-1111-111111111111",
        denunciar = { corpo ->
            enviados += corpo
            ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17")
        },
        bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
        gerarChave = { "chave-1" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `9 caracteres com emoji nao valem, mesmo com 10 unidades UTF-16`() = runBlocking {
        for (relato in listOf(nove, "  $nove  ")) {
            val vm = viewModel()
            vm.editarRelato(relato)
            assertFalse(vm.estado.value.relatoValido, relato)
            assertFalse(vm.estado.value.podeEnviar, relato)

            vm.enviarDenuncia().join()

            assertEquals(TextosSuporte.RELATO_MINIMO, vm.estado.value.erroDenuncia, relato)
        }
        assertTrue(enviados.isEmpty())
    }

    @Test
    fun `10 caracteres com emoji valem e saem com o emoji inteiro`() = runBlocking {
        val vm = viewModel()
        vm.editarRelato("  $dez  ")
        assertTrue(vm.estado.value.relatoValido)

        vm.enviarDenuncia().join()

        assertEquals(listOf(dez), enviados.map { it.relato })
    }

    @Test
    fun `5 emojis nao bastam e 10 emojis bastam`() = runBlocking {
        val vm = viewModel()
        vm.editarRelato(emoji.repeat(5))
        assertFalse(vm.estado.value.relatoValido)

        vm.editarRelato(emoji.repeat(10))
        assertTrue(vm.estado.value.relatoValido)
    }
}
