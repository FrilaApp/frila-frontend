package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaPublicadaDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RepublicarPosicoesRestantesViewModelTest {

    private val pedidos = mutableListOf<Pair<String, String>>()
    private val republicadas = mutableListOf<String>()
    private var releiturasDoPainel = 0
    private var chaves = 0

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(republicar: suspend () -> VagaPublicadaDto = { VagaPublicadaDto("nova", listOf("p1", "p2")) }) =
        RepublicarPosicoesRestantesViewModel(
            vagaId = "v1",
            posicoesRestantes = 2,
            republicar = { vaga, chave -> pedidos += vaga to chave; republicar() },
            aoRepublicar = { republicadas += it },
            aoMudarOPainel = { releiturasDoPainel++ },
            novaChave = { "chave-${++chaves}" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

    @Test
    fun `executar manda a vaga de origem e a chave, guarda a vaga nova e avisa quem abriu`() {
        val vm = viewModel()

        vm.executar()

        assertEquals(listOf("v1" to "chave-1"), pedidos)
        assertEquals("nova", vm.estado.value.vagaPublicadaId)
        assertEquals(2, vm.estado.value.posicoesRestantes)
        assertFalse(vm.estado.value.carregando)
        assertEquals(listOf("nova"), republicadas)
        assertEquals(1, releiturasDoPainel)
        assertNull(vm.executar(), "depois de republicada não envia de novo")
    }

    @Test
    fun `cada motivo de republicacao_indisponivel vira texto do Frila e pede a releitura do painel`() {
        val casos = mapOf(
            "ja_republicada" to TextosRepublicarPosicoesRestantes.JA_REPUBLICADA,
            "sem_posicoes_restantes" to TextosRepublicarPosicoesRestantes.SEM_POSICOES_RESTANTES,
            "selecao_em_curso" to TextosRepublicarPosicoesRestantes.SELECAO_EM_CURSO,
            "ja_comecou" to TextosRepublicarPosicoesRestantes.JA_COMECOU,
            "vaga_cancelada" to TextosRepublicarPosicoesRestantes.VAGA_CANCELADA,
            "nao_e_selecao" to TextosRepublicarPosicoesRestantes.NAO_E_SELECAO,
            "motivo_novo_do_servidor" to TextosRepublicarPosicoesRestantes.INDISPONIVEL,
            null to TextosRepublicarPosicoesRestantes.INDISPONIVEL,
        )
        for ((detalhes, texto) in casos) {
            releiturasDoPainel = 0
            val vm = viewModel { throw erro(CodigoErroAPI.REPUBLICACAO_INDISPONIVEL, detalhes) }

            vm.executar()

            assertEquals(texto, vm.estado.value.erro, detalhes)
            assertEquals(1, releiturasDoPainel, detalhes)
            assertNull(vm.estado.value.vagaPublicadaId)
        }
        assertTrue(republicadas.isEmpty())
    }

    @Test
    fun `as outras recusas viram texto do Frila sem reler o painel`() {
        val casos = listOf(
            erro(CodigoErroAPI.VAGA_OCULTA) to TextosRepublicarPosicoesRestantes.VAGA_OCULTA,
            erro(CodigoErroAPI.SEM_PERMISSAO) to TextosRepublicarPosicoesRestantes.SEM_PERMISSAO,
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosRepublicarPosicoesRestantes.CONTA_SUSPENSA,
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosRepublicarPosicoesRestantes.NAO_ENCONTRADO,
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to TextosRepublicarPosicoesRestantes.PERFIL_INCOMPATIVEL,
            erro(CodigoErroAPI.SEM_REDE) to TextosRepublicarPosicoesRestantes.SEM_REDE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosRepublicarPosicoesRestantes.SESSAO_EXPIRADA,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosRepublicarPosicoesRestantes.ERRO_GENERICO,
            IllegalStateException("corpo que não é JSON") to TextosRepublicarPosicoesRestantes.ERRO_GENERICO,
        )
        for ((falha, texto) in casos) {
            val vm = viewModel { throw falha }

            vm.executar()

            assertEquals(texto, vm.estado.value.erro, falha.toString())
            assertFalse(vm.estado.value.carregando)
        }
        assertEquals(0, releiturasDoPainel)
    }

    @Test
    fun `tentar de novo depois de uma falha usa a mesma chave, e dois toques seguidos mandam um pedido so`() {
        var falhas = 0
        val resposta = CompletableDeferred<VagaPublicadaDto>()
        val vm = viewModel { if (falhas++ == 0) throw erro(CodigoErroAPI.SEM_REDE) else resposta.await() }

        vm.executar()
        vm.executar()
        assertTrue(vm.estado.value.carregando)
        assertNull(vm.executar())
        resposta.complete(VagaPublicadaDto("nova", emptyList()))

        assertEquals(listOf("v1" to "chave-1", "v1" to "chave-1"), pedidos)
        assertEquals("nova", vm.estado.value.vagaPublicadaId)
        assertNull(vm.estado.value.erro)
    }
}
