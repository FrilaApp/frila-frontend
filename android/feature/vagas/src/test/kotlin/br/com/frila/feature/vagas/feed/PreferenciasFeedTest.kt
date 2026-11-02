package br.com.frila.feature.vagas.feed

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoVagas
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PreferenciasFeedTest {
    private fun criar(armazenamento: ArmazenamentoPreferenciasFiltro, escopo: CoroutineScope): FeedVagasViewModel {
        val servico = mockk<ServicoVagas>()
        coEvery { servico.listarVagasAbertas(any()) } returns emptyList()
        val localizacao = mockk<ProvedorDeLocalizacao>()
        coEvery { localizacao.obterCoordenadaAtual() } returns null
        return FeedVagasViewModel(servico, localizacao, armazenamento, escopo)
    }

    @Test fun `leitura antiga que termina depois do toque nao desfaz filtro escolhido`() = runTest {
        val liberarLeitura = CompletableDeferred<Unit>()
        val armazenamento = object : ArmazenamentoPreferenciasFiltro {
            var salva: PreferenciaFaixaRemuneracao? = null
            override suspend fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao {
                liberarLeitura.await()
                return PreferenciaFaixaRemuneracao(35f, 95f, true)
            }
            override suspend fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
                salva = PreferenciaFaixaRemuneracao(minimo, maximo, ativa)
            }
            override suspend fun limparFaixaRemuneracaoHora() { salva = null }
        }
        val vm = criar(armazenamento, this)
        vm.carregar()
        runCurrent()
        vm.aoAlterarFaixaRemuneracaoHora(40f..80f, false)
        liberarLeitura.complete(Unit)
        advanceUntilIdle()
        assertEquals(FaixaRemuneracaoHora(40f, 80f, false), vm.estado.value.faixaRemuneracaoHora)
        assertEquals(PreferenciaFaixaRemuneracao(40f, 80f, false), armazenamento.salva)
    }

    @Test fun `gravacao lenta mantem ordem dos toques e limpeza nao ressuscita filtro`() = runTest {
        val liberarGravacao = CompletableDeferred<Unit>()
        val operacoes = mutableListOf<String>()
        val armazenamento = object : ArmazenamentoPreferenciasFiltro {
            var salva: PreferenciaFaixaRemuneracao? = null
            override suspend fun obterFaixaRemuneracaoHora() = salva
            override suspend fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
                operacoes += minimo.toString()
                if (operacoes.size == 1) liberarGravacao.await()
                salva = PreferenciaFaixaRemuneracao(minimo, maximo, ativa)
            }
            override suspend fun limparFaixaRemuneracaoHora() { operacoes += "limpar"; salva = null }
        }
        val vm = criar(armazenamento, this)
        vm.aoAlterarFaixaRemuneracaoHora(30f..70f)
        vm.aoAlterarFaixaRemuneracaoHora(40f..80f)
        vm.aoLimparFiltrosAvancados()
        runCurrent()
        assertEquals(listOf("30.0"), operacoes)
        liberarGravacao.complete(Unit)
        advanceUntilIdle()
        assertEquals(listOf("30.0", "40.0", "limpar"), operacoes)
        assertNull(armazenamento.salva)
        assertEquals(FaixaRemuneracaoHora.PADRAO, vm.estado.value.faixaRemuneracaoHora)
    }
}
