package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** GpINsbhj: o bloqueio avulso (chamada recebida e perfil público). O estado e a idempotência são os da tela de denúncia. */
class BloqueioDeAlvoViewModelTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val pedidos = mutableListOf<Pair<String, String>>()
    private var comportamento: suspend () -> Unit = { }

    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name.lowercase(), null, "x")

    private fun viewModel(tipo: TipoDeAlvo = TipoDeAlvo.ESTABELECIMENTO) = BloqueioDeAlvoViewModel(
        alvoTipo = tipo,
        alvoId = casa,
        bloquear = { t, id -> pedidos += t to id; comportamento(); BloqueioDto(t, id, "2026-11-10T12:00:00Z") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `confirmar bloqueia o alvo com o tipo e o id, uma vez, e fecha o dialogo`() {
        val vm = viewModel()
        vm.abrirDialogo()
        assertTrue(vm.estado.value.dialogoAberto)

        vm.confirmar()

        assertEquals(listOf("estabelecimento" to casa), pedidos)
        assertTrue(vm.estado.value.bloqueado)
        assertFalse(vm.estado.value.dialogoAberto)
        assertFalse(vm.estado.value.bloqueando)
    }

    @Test
    fun `o tipo profissional vai como profissional`() {
        val vm = viewModel(TipoDeAlvo.PROFISSIONAL)

        vm.confirmar()

        assertEquals(listOf("profissional" to casa), pedidos)
    }

    @Test
    fun `cancelar fecha o dialogo e nao bloqueia`() {
        val vm = viewModel()
        vm.abrirDialogo()

        vm.cancelar()

        assertFalse(vm.estado.value.dialogoAberto)
        assertFalse(vm.estado.value.bloqueado)
        assertTrue(pedidos.isEmpty())
    }

    @Test
    fun `depois de bloqueado nao abre o dialogo nem pede de novo`() {
        val vm = viewModel()
        vm.confirmar()

        vm.abrirDialogo()
        vm.confirmar()

        assertFalse(vm.estado.value.dialogoAberto)
        assertEquals(1, pedidos.size)
    }

    @Test
    fun `com um pedido em voo, confirmar de novo nao abre um segundo`() {
        val portao = CompletableDeferred<Unit>()
        comportamento = { portao.await() }
        val vm = viewModel()

        vm.confirmar()
        assertTrue(vm.estado.value.bloqueando)
        vm.abrirDialogo()
        vm.confirmar()
        portao.complete(Unit)

        assertEquals(1, pedidos.size)
        assertFalse(vm.estado.value.dialogoAberto)
        assertTrue(vm.estado.value.bloqueado)
    }

    @Test
    fun `falha de rede mostra o erro, nao bloqueia e deixa tentar de novo`() {
        var falhar = true
        comportamento = { if (falhar) throw erro(CodigoErroAPI.SEM_REDE) }
        val vm = viewModel()

        vm.confirmar()

        assertEquals(TextosSuporte.ERRO_SEM_REDE, vm.estado.value.erro)
        assertFalse(vm.estado.value.bloqueado)
        assertFalse(vm.estado.value.bloqueando)

        falhar = false
        vm.abrirDialogo()
        assertNull(vm.estado.value.erro)
        vm.confirmar()
        assertTrue(vm.estado.value.bloqueado)
        assertEquals(2, pedidos.size)
    }

    @Test
    fun `alvo nao encontrado diz perfil indisponivel e qualquer outra falha diz o erro generico`() {
        comportamento = { throw erro(CodigoErroAPI.NAO_ENCONTRADO) }
        val vm = viewModel()
        vm.confirmar()
        assertEquals(TextosSuporte.INDISPONIVEL, vm.estado.value.erro)

        comportamento = { throw IllegalStateException("x") }
        val outro = viewModel()
        outro.confirmar()
        assertEquals(TextosSuporte.ERRO_GENERICO, outro.estado.value.erro)
    }

    @Test
    fun `cancelar o trabalho nao vira erro nem bloqueio`() {
        val portao = CompletableDeferred<Unit>()
        comportamento = { portao.await() }
        val vm = viewModel()

        val trabalho = vm.confirmar()
        trabalho.cancel()

        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.bloqueado)
    }
}
