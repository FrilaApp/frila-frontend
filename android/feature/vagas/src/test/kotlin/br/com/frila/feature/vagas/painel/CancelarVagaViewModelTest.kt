package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaCanceladaDto
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CancelarVagaViewModelTest {

    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")
    private val pedidos = mutableListOf<Pair<String, String>>()

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(
        inicio: Instant? = agora.plusSeconds(5 * 3600),
        cancelar: suspend (String, String) -> VagaCanceladaDto = { vaga, _ -> VagaCanceladaDto(vaga, "cancelada", 3) },
    ) = CancelarVagaViewModel(
        vagaId = "v1",
        inicioDaVaga = inicio,
        cancelar = { vaga, motivo -> pedidos += vaga to motivo; cancelar(vaga, motivo) },
        relogio = { agora },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `o aviso diz quanto falta em horas inteiras para baixo e o efeito de cancelar a vaga inteira`() {
        assertEquals("Faltam 23 h para o início. ${TextosCancelarVaga.EFEITO}", avisoDoCancelamento(agora.plusSeconds(23 * 3600 + 1800), agora))
        assertEquals("Faltam menos de 1 h para o início. ${TextosCancelarVaga.EFEITO}", avisoDoCancelamento(agora.plusSeconds(1800), agora))
        assertEquals("O turno já começou. ${TextosCancelarVaga.EFEITO_COMECADA}", avisoDoCancelamento(agora, agora))
        assertEquals(TextosCancelarVaga.EFEITO, avisoDoCancelamento(null, agora))
        assertEquals("Faltam 5 h para o início. ${TextosCancelarVaga.EFEITO}", viewModel().estado.value.aviso)
    }

    @Test
    fun `sem motivo nao confirma e nada vai ao servidor`() {
        val vm = viewModel()

        assertFalse(vm.estado.value.podeConfirmar)
        assertNull(vm.confirmar())
        assertTrue(pedidos.isEmpty())
    }

    @Test
    fun `outro motivo exige ao menos 3 caracteres e vai ao servidor so o texto digitado`() {
        val vm = viewModel()
        vm.escolherMotivo(MotivoDeCancelamentoDaVaga.OUTRO)
        vm.mudarDetalhes(" ab ")
        assertFalse(vm.estado.value.podeConfirmar)

        vm.mudarDetalhes("  Obra na cozinha  ")
        vm.confirmar()

        assertEquals(listOf("v1" to "Obra na cozinha"), pedidos)
    }

    @Test
    fun `motivo da lista vai sozinho ou com o detalhe depois de dois pontos, e a vaga fica cancelada`() {
        val semDetalhe = viewModel()
        semDetalhe.escolherMotivo(MotivoDeCancelamentoDaVaga.MOVIMENTO_MENOR)
        semDetalhe.confirmar()
        val comDetalhe = viewModel()
        comDetalhe.escolherMotivo(MotivoDeCancelamentoDaVaga.MUDANCA_DE_PLANOS)
        comDetalhe.mudarDetalhes("adiado para dezembro")
        comDetalhe.confirmar()

        assertEquals("v1" to "Movimento menor que o esperado", pedidos[0])
        assertEquals("v1" to "O evento ou o turno mudou: adiado para dezembro", pedidos[1])
        assertTrue(semDetalhe.estado.value.concluida)
        assertFalse(semDetalhe.estado.value.podeConfirmar)
        assertNull(semDetalhe.confirmar(), "depois de cancelada não envia de novo")
        assertEquals(2, pedidos.size)
    }

    @Test
    fun `dois toques seguidos mandam um cancelamento so`() {
        val resposta = CompletableDeferred<VagaCanceladaDto>()
        val vm = viewModel(cancelar = { _, _ -> resposta.await() })
        vm.escolherMotivo(MotivoDeCancelamentoDaVaga.PROBLEMA_NO_LOCAL)

        vm.confirmar()
        assertTrue(vm.estado.value.enviando)
        assertNull(vm.confirmar())
        resposta.complete(VagaCanceladaDto("v1", "cancelada", 1))

        assertEquals(1, pedidos.size)
        assertTrue(vm.estado.value.concluida)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `cada recusa do contrato vira texto do Frila e da para tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.VAGA_ENCERRADA) to TextosCancelarVaga.VAGA_JA_FECHADA,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "motivo") to TextosCancelarVaga.MOTIVO_RECUSADO,
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "motivo") to TextosCancelarVaga.DETALHES_OBRIGATORIOS,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "vaga_id") to TextosCancelarVaga.FALHA_GENERICA,
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosCancelarVaga.FALHA_GENERICA,
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to TextosCancelarVaga.CONTA_NAO_PODE,
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosCancelarVaga.CONTA_NAO_PODE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosCancelarVaga.SESSAO_EXPIRADA,
            erro(CodigoErroAPI.SEM_REDE) to TextosCancelarVaga.SEM_REDE,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosCancelarVaga.FALHA_GENERICA,
            IllegalStateException("corpo que não é JSON") to TextosCancelarVaga.FALHA_GENERICA,
        )
        for ((falha, texto) in casos) {
            val vm = viewModel(cancelar = { _, _ -> throw falha })
            vm.escolherMotivo(MotivoDeCancelamentoDaVaga.PREENCHIDA_FORA)

            vm.confirmar()

            val estado = vm.estado.value
            assertEquals(texto, estado.erro, falha.toString())
            assertFalse(estado.concluida)
            assertFalse(estado.enviando)
            assertTrue(estado.podeConfirmar, "depois da falha dá para tentar de novo")
        }
    }
}
