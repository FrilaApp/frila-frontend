package br.com.frila.feature.conta

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ContestarDespachoViewModelTest {

    private val relato = "Não recebi a vaga de garçom de sexta à noite."
    private val relatosEnviados = mutableListOf<String>()

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(pedir: suspend () -> ProtocoloDto = { protocoloDoServidor(tipo = "revisao_despacho") }) = ContestarDespachoViewModel(
        pedirRevisao = { texto -> relatosEnviados += texto; pedir() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `relato vazio ou curto nao vai ao servidor e a tela diz por que`() {
        val vm = viewModel()

        assertNull(vm.contestar())
        val vazio = vm.estado.value.mensagemErro
        vm.mudarRelato("  curto  ")
        assertNull(vm.contestar())

        assertEquals(TextosContestarDespacho.RELATO_OBRIGATORIO, vazio)
        assertEquals(TextosContestarDespacho.RELATO_MINIMO, vm.estado.value.mensagemErro)
        assertTrue(relatosEnviados.isEmpty())
    }

    @Test
    fun `contestar manda o relato sem espacos nas pontas, guarda o protocolo e nao oferece outro pedido`() {
        val vm = viewModel()
        vm.mudarRelato("  $relato  ")

        vm.contestar()

        val estado = vm.estado.value
        assertEquals(listOf(relato), relatosEnviados)
        assertEquals("6F1C2A4E", estado.protocolo!!.numero)
        assertEquals("17/11/2026", estado.protocolo!!.enviadoEm)
        assertEquals("24/11/2026", estado.protocolo!!.prazoRespostaAte)
        assertFalse(estado.podeContestar)
        assertNull(vm.contestar())
        assertEquals(1, relatosEnviados.size)
    }

    @Test
    fun `dois toques seguidos mandam um pedido so`() {
        val resposta = CompletableDeferred<ProtocoloDto>()
        val vm = viewModel { resposta.await() }
        vm.mudarRelato(relato)

        vm.contestar()
        assertTrue(vm.estado.value.enviando)
        assertNull(vm.contestar())
        resposta.complete(protocoloDoServidor(tipo = "revisao_despacho"))

        assertEquals(1, relatosEnviados.size)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `contestacao que ja existe encerra o pedido pelo app`() {
        val vm = viewModel { throw erro(CodigoErroAPI.CONTESTACAO_JA_ABERTA) }
        vm.mudarRelato(relato)

        vm.contestar()

        assertTrue(vm.estado.value.contestacaoJaAberta)
        assertFalse(vm.estado.value.podeContestar)
        assertNull(vm.estado.value.mensagemErro)
        assertNull(vm.contestar())
    }

    @Test
    fun `cada recusa do contrato vira texto do Frila e deixa tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "relato") to TextosContestarDespacho.RELATO_OBRIGATORIO,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "relato") to TextosContestarDespacho.RELATO_MINIMO,
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosContestarDespacho.CONTA_SUSPENSA,
            erro(CodigoErroAPI.CONTA_SUSPENSA) to TextosContestarDespacho.CONTA_SUSPENSA,
            erro(CodigoErroAPI.SEM_PERMISSAO) to TextosContestarDespacho.ERRO_ENVIAR,
            erro(CodigoErroAPI.LIMITE_EXCEDIDO) to TextosContestarDespacho.LIMITE_EXCEDIDO,
            erro(CodigoErroAPI.SEM_REDE) to TextosContestarDespacho.ERRO_SEM_REDE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosContestarDespacho.ERRO_SESSAO,
            IllegalStateException("corpo que não é JSON") to TextosContestarDespacho.ERRO_ENVIAR,
        )
        for ((falha, texto) in casos) {
            val vm = viewModel { throw falha }
            vm.mudarRelato(relato)

            vm.contestar()

            assertEquals(texto, vm.estado.value.mensagemErro, falha.toString())
            assertTrue(vm.estado.value.podeContestar)
            assertFalse(vm.estado.value.enviando)
        }
    }
}
