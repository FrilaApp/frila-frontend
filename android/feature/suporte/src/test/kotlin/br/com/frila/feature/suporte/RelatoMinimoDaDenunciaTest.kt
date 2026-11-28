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
 * Cartão VUUPvQj3 (item 207): na denúncia, 10 caracteres (depois de aparados) valem e 9 não; antes só havia 5 ou 9 contra relatos longos,
 * e `>=` virar `>` passava. A constante do mínimo também é conferida pelo que ela deixa passar.
 */
class RelatoMinimoDaDenunciaTest {

    private val alvoId = "11111111-1111-1111-1111-111111111111"
    private val dez = "1234567890"
    private val nove = "123456789"

    private val enviados = mutableListOf<DenunciarDto>()

    private fun viewModel() = DenunciaViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
        alvoId = alvoId,
        denunciar = { corpo ->
            enviados += corpo
            ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17")
        },
        bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
        gerarChave = { "chave-1" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `o minimo declarado e 10`() {
        assertEquals(10, RELATO_MINIMO_CARACTERES)
    }

    @Test
    fun `exatamente 10 caracteres valem e a denuncia sai`() = runBlocking {
        val vm = viewModel()
        vm.editarRelato(dez)
        assertTrue(vm.estado.value.relatoValido)
        assertTrue(vm.estado.value.podeEnviar)

        vm.enviarDenuncia().join()

        assertEquals(listOf(dez), enviados.map { it.relato })
        assertEquals(null, vm.estado.value.erroDenuncia)
    }

    @Test
    fun `10 caracteres com espacos nas pontas valem e saem aparados`() = runBlocking {
        val vm = viewModel()
        vm.editarRelato("   $dez   ")
        assertTrue(vm.estado.value.relatoValido)

        vm.enviarDenuncia().join()

        assertEquals(listOf(dez), enviados.map { it.relato })
    }

    @Test
    fun `9 caracteres nao valem, nem com espacos que completariam 10 sem o aparo`() = runBlocking {
        for (relato in listOf(nove, "   $nove   ", " $nove")) {
            val vm = viewModel()
            vm.editarRelato(relato)
            assertFalse(vm.estado.value.relatoValido, relato)
            assertFalse(vm.estado.value.podeEnviar, relato)

            vm.enviarDenuncia().join()

            assertEquals(TextosSuporte.RELATO_MINIMO, vm.estado.value.erroDenuncia, relato)
        }
        assertTrue(enviados.isEmpty())
    }
}
