package br.com.frila.feature.conta

import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão VUUPvQj3 (item 207): o contrato pede relato com no mínimo 10 caracteres, depois de aparado (`openapi.yaml`). Os testes antigos
 * só usam 5 ou 9 caracteres contra relatos longos, e então `<` virar `<=` ou `>=` virar `>` passavam. Aqui a fronteira exata:
 * 10 vale, 9 não, e os espaços das pontas não contam.
 */
class RelatoMinimoDeDezCaracteresTest {

    private val dez = "1234567890"
    private val nove = "123456789"

    // ---- Contestar o despacho ----

    private val enviadosDoDespacho = mutableListOf<String>()

    private fun despacho() = ContestarDespachoViewModel(
        pedirRevisao = { texto -> enviadosDoDespacho += texto; protocoloDoServidor(tipo = "revisao_despacho") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `despacho, exatamente 10 caracteres vao ao servidor`() {
        val vm = despacho()
        vm.mudarRelato(dez)
        assertTrue(vm.estado.value.relatoValido)

        assertNotNull(vm.contestar())

        assertEquals(listOf(dez), enviadosDoDespacho)
    }

    @Test
    fun `despacho, 10 caracteres com espacos nas pontas vao aparados`() {
        val vm = despacho()
        vm.mudarRelato("   $dez   ")

        assertNotNull(vm.contestar())

        assertEquals(listOf(dez), enviadosDoDespacho)
    }

    @Test
    fun `despacho, 9 caracteres nao vao, nem com espacos que completariam 10 sem o aparo`() {
        for (relato in listOf(nove, "   $nove   ", " $nove")) {
            val vm = despacho()
            vm.mudarRelato(relato)
            assertEquals(false, vm.estado.value.relatoValido, relato)

            assertNull(vm.contestar(), relato)

            assertEquals(TextosContestarDespacho.RELATO_MINIMO, vm.estado.value.mensagemErro, relato)
        }
        assertTrue(enviadosDoDespacho.isEmpty())
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
    fun `suspensao, exatamente 10 caracteres vao ao servidor`() {
        val vm = suspensao()
        vm.mudarRelato(dez)
        assertTrue(vm.estado.value.relatoValido)

        assertNotNull(vm.enviarContestacao())

        assertEquals(listOf(dez), enviadosDaSuspensao)
    }

    @Test
    fun `suspensao, 10 caracteres com espacos nas pontas vao aparados`() {
        val vm = suspensao()
        vm.mudarRelato("   $dez   ")

        assertNotNull(vm.enviarContestacao())

        assertEquals(listOf(dez), enviadosDaSuspensao)
    }

    @Test
    fun `suspensao, 9 caracteres nao vao, nem com espacos que completariam 10 sem o aparo`() {
        for (relato in listOf(nove, "   $nove   ", " $nove")) {
            val vm = suspensao()
            vm.mudarRelato(relato)
            assertEquals(false, vm.estado.value.relatoValido, relato)

            assertNull(vm.enviarContestacao(), relato)

            assertEquals(TextosContaSuspensa.RELATO_MINIMO, vm.estado.value.mensagemErro, relato)
        }
        assertTrue(enviadosDaSuspensao.isEmpty())
    }
}
