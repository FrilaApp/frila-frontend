package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.rede.contaDaSessaoParaTelemetria
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.vagas.painel.CancelarVagaViewModel
import java.time.Instant
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.StatusAvaliacao
import io.mockk.mockk
import java.io.File
import java.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/** A6.1: a fila de ações sem rede sai com a sessão: logout, troca de conta e expiração. O refresh da mesma conta a preserva. */
class FilaDeAcoesDaSessaoTest {
    @TempDir lateinit var raiz: File
    private val acao = AcaoPendente(TipoAcaoPendente.CHECKIN, "conta-sintetica", "2026-11-23T12:00:00Z", turnoId = "turno")
    private fun sessao(pessoa: String, renovacao: String = "renovacao-teste"): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", renovacao, "bearer", 60, null)
    }
    private fun montar(): Pair<CacheVagasDaSessao, SessaoComCacheVagas> {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        cache.filaDeAcoes.enfileirar(acao)
        return cache to armazenamento
    }
    private val arquivo get() = File(raiz, "acoes/fila.json")

    @Test fun `a fila fica em arquivo privado do app e sobrevive a uma nova instancia`() {
        val (cache, _) = montar()
        assertTrue(arquivo.isFile)
        assertEquals(listOf(acao), CacheVagasDaSessao(raiz).filaDeAcoes.pendentes())
        assertEquals(listOf(acao), cache.filaDeAcoes.pendentes())
    }

    @Test fun `logout limpa a fila e apaga o arquivo`() {
        val (cache, armazenamento) = montar()
        armazenamento.limparSessao()
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(File(raiz, "acoes").exists())
    }

    @Test fun `outra conta entrando limpa a fila e o refresh da mesma conta a preserva`() {
        val (cache, armazenamento) = montar()
        armazenamento.salvarSessao(sessao("pessoa-a", "renovacao-nova"))
        assertEquals(listOf(acao), cache.filaDeAcoes.pendentes())
        armazenamento.salvarSessao(sessao("pessoa-b"))
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(File(raiz, "acoes").exists())
    }

    @Test fun `limpar o cache direto, como na expiracao, tambem apaga a fila`() {
        val (cache, _) = montar()
        cache.limpar()
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(arquivo.exists())
    }

    /**
     * Revisão do #1039 (R4): a tela de check-in relê a conta a cada mudança da fila. Antes, sem sessão, ler a conta limpava
     * o cache, a limpeza mudava a fila e a tela relia, sem fim (o limitador abaixo só existe para o teste não travar).
     */
    @Test fun `logout com a tela de check-in observando a fila nao entra em ciclo`() = runTest {
        for (comAcaoNaFila in listOf(false, true)) {
            val cache = CacheVagasDaSessao(File(raiz, "caso-$comAcaoNaFila"))
            val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
            armazenamento.salvarSessao(sessao("pessoa-a"))
            if (comAcaoNaFila) cache.filaDeAcoes.enfileirar(acao.copy(contaId = "pessoa-a"))
            val escopo = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
            var leituras = 0
            CheckinViewModel("turno", null, mockk<ServicoTurnos>(), mockk<ProvedorDeLocalizacao>(), escopo = escopo,
                filaDeAcoes = cache.filaDeAcoes, contaAtual = {
                    leituras++
                    if (leituras >= 20) escopo.cancel()
                    contaDaSessaoParaTelemetria(armazenamento.obterSessao())
                })
            runCurrent()
            val leiturasAntes = leituras
            val versaoAntes = cache.filaDeAcoes.versao.value
            armazenamento.limparSessao()
            runCurrent()
            val versoes = cache.filaDeAcoes.versao.value - versaoAntes
            println("R4 comAcaoNaFila=$comAcaoNaFila leiturasAntes=$leiturasAntes leiturasDepois=$leituras versoesGeradas=$versoes")
            // Com a fila vazia o logout não muda a fila; com uma ação, muda uma vez e a tela relê uma vez, sem limpar de novo.
            assertEquals(if (comAcaoNaFila) 1 else 0, versoes)
            assertTrue(leituras <= leiturasAntes + 1, "leituras: $leiturasAntes -> $leituras")
            assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
            escopo.cancel()
        }
    }

    /** Mesmo ciclo do R4, agora na tela de avaliação (#1042): logout com a tela aberta não pode reler em laço. */
    @Test fun `logout com a tela de avaliacao observando a fila nao entra em ciclo`() = runTest {
        for (comAcaoNaFila in listOf(false, true)) {
            val cache = CacheVagasDaSessao(File(raiz, "avaliacao-$comAcaoNaFila"))
            val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
            armazenamento.salvarSessao(sessao("pessoa-a"))
            if (comAcaoNaFila) {
                cache.filaDeAcoes.enfileirar(AcaoPendente(TipoAcaoPendente.AVALIACAO, "pessoa-a", "2026-11-23T12:00:00Z",
                    turnoId = "turno", resposta = true))
            }
            val escopo = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
            var leituras = 0
            val modelo = AvaliacaoViewModel(mockk<ServicoTurnos>(), escopo = escopo, filaDeAcoes = cache.filaDeAcoes, contaAtual = {
                leituras++
                if (leituras >= 20) escopo.cancel()
                contaDaSessaoParaTelemetria(armazenamento.obterSessao())
            })
            modelo.observar("turno")
            runCurrent()
            val leiturasAntes = leituras
            val versaoAntes = cache.filaDeAcoes.versao.value
            armazenamento.limparSessao()
            runCurrent()
            val versoes = cache.filaDeAcoes.versao.value - versaoAntes
            println("R4-avaliacao comAcaoNaFila=$comAcaoNaFila leiturasAntes=$leiturasAntes leiturasDepois=$leituras versoesGeradas=$versoes")
            assertEquals(if (comAcaoNaFila) 1 else 0, versoes)
            assertTrue(leituras <= leiturasAntes + 1, "leituras: $leiturasAntes -> $leituras")
            assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
            assertEquals(StatusAvaliacao.OCIOSO, modelo.estado.value.status)
            escopo.cancel()
        }
    }

    @Test fun `logout com cancelamentos observando a fila nao entra em ciclo`() = runTest {
        for (casa in listOf(false, true)) for (comAcao in listOf(false, true)) {
            val cache = CacheVagasDaSessao(File(raiz, "cancelamento-$casa-$comAcao"))
            val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
            armazenamento.salvarSessao(sessao("pessoa-a"))
            if (comAcao) cache.filaDeAcoes.enfileirar(AcaoPendente(
                if (casa) TipoAcaoPendente.CANCELAMENTO_VAGA else TipoAcaoPendente.CANCELAMENTO_POSICAO,
                "pessoa-a", "2026-11-23T12:00:00Z", turnoId = if (casa) null else "turno", alvoId = "alvo", motivo = "Imprevisto"))
            val escopo = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
            var leituras = 0
            val conta = {
                leituras++
                if (leituras >= 20) escopo.cancel()
                contaDaSessaoParaTelemetria(armazenamento.obterSessao())
            }
            if (casa) CancelarVagaViewModel("alvo", null, { _, _ -> error("não envia") }, escopo = escopo,
                filaDeAcoes = cache.filaDeAcoes, contaAtual = conta)
            else MeusTurnosViewModel(mockk<ServicoTurnos>(), escopo = escopo,
                filaDeAcoes = cache.filaDeAcoes, contaAtual = conta).abrirCancelamento(
                ItemTurno("turno", "alvo", Instant.EPOCH, funcaoNome = "", estabelecimentoNome = "",
                    dataHorarioFormatado = "", valorFormatado = "", estado = "confirmada"))
            runCurrent()
            val antes = leituras
            val versao = cache.filaDeAcoes.versao.value
            armazenamento.limparSessao(); runCurrent()
            val versoes = cache.filaDeAcoes.versao.value - versao
            println("R4-cancelamento casa=$casa comAcao=$comAcao leiturasAntes=$antes leiturasDepois=$leituras versoesGeradas=$versoes")
            assertEquals(if (comAcao) 1 else 0, versoes)
            assertTrue(leituras <= antes + 1, "leituras: $antes -> $leituras")
            assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
            escopo.cancel()
        }
    }

    @Test fun `sem sessao a primeira leitura limpa o que sobrou e as seguintes nao limpam de novo`() {
        val cache = CacheVagasDaSessao(raiz)
        cache.filaDeAcoes.enfileirar(acao)
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
        assertNull(armazenamento.obterSessao())
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(arquivo.exists())
        val versao = cache.filaDeAcoes.versao.value
        repeat(3) { assertNull(armazenamento.obterSessao()) }
        assertEquals(versao, cache.filaDeAcoes.versao.value)
        // Nova sessão e novo logout: limpa de novo.
        armazenamento.salvarSessao(sessao("pessoa-b"))
        cache.filaDeAcoes.enfileirar(acao.copy(contaId = "pessoa-b"))
        armazenamento.limparSessao()
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(arquivo.exists())
    }
}
