package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.*
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.vagas.painel.RepublicarVagaViewModel
import br.com.frila.feature.vagas.publicacao.*
import java.io.File
import java.time.Duration
import java.time.Instant
import java.util.Base64
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

@OptIn(ExperimentalCoroutinesApi::class)
class PublicacoesNaFilaTest {
    @TempDir lateinit var raiz: File
    private val toque = Instant.ofEpochSecond(1795521600)
    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, "sintético", null, "sintético")
    private inner class Cenario(val republicar: Boolean, val escopo: CoroutineScope) {
        val diretorio = File(raiz, "caso-$republicar-${System.nanoTime()}")
        val cache = CacheVagasDaSessao(diretorio)
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
        val fila get() = cache.filaDeAcoes
        val tipo = if (republicar) TipoAcaoPendente.REPUBLICACAO_VAGA else TipoAcaoPendente.PUBLICACAO_VAGA
        var codigo: CodigoErroAPI? = CodigoErroAPI.SEM_REDE
        var pedidos = 0
        var leituras = 0
        val eventos = mutableListOf<EventoDeTelemetria>()
        val corpos = mutableListOf<Any>()
        var liberar: CompletableDeferred<Unit>? = null
        lateinit var executar: () -> Job?
        lateinit var estaNaFila: () -> Boolean
        lateinit var concluida: () -> Boolean
        lateinit var recusada: () -> Boolean
        init { entrar("pessoa-a"); abrir() }
        fun entrar(conta: String) {
            val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$conta\"}".toByteArray())
            armazenamento.salvarSessao(Sessao("cabecalho.$corpo.assinatura-sintetica", "renovacao", "bearer", 60, null))
        }
        fun conta(): String? {
            check(++leituras < 30) { "releitura em ciclo" }
            return contaDaSessaoParaTelemetria(armazenamento.obterSessao())
        }
        suspend fun enviar(corpo: Any): VagaPublicadaDto {
            pedidos++; corpos += corpo
            liberar?.await()
            codigo?.let { throw erro(it) }
            return VagaPublicadaDto("vaga-nova", listOf("posicao-sintetica"))
        }
        fun abrir(preencher: Boolean = true) {
            if (republicar) {
                val vm = RepublicarVagaViewModel("vaga-origem", false, Duration.ofHours(3),
                    republicar = { vaga, inicio, fim, chave -> enviar(RepublicarVagaDto(vaga, inicio.toString(), fim.toString(), chave)) },
                    relogio = { toque }, novaChave = { "chave-sintetica" }, escopo = escopo,
                    filaDeAcoes = fila, contaAtual = ::conta, registrarEvento = { e, _, _ -> eventos += e })
                executar = vm::republicar
                estaNaFila = { vm.estado.value.naFila }
                concluida = { vm.estado.value.enviadaPelaFila || vm.estado.value.vagaPublicadaId != null }
                recusada = { vm.estado.value.mensagemErro == br.com.frila.feature.vagas.painel.TextosRepublicarVaga.RECUSADA_NA_FILA }
            } else {
                val vm = PublicarVagaViewModel(EstabelecimentoDaVaga("casa", "Endereço sintético", "Região sintética", CoordenadaDto(0.0, 0.0)),
                    buscarFuncoes = { listOf(FuncaoDto("funcao", "Função sintética", "Categoria sintética")) }, enviarVaga = ::enviar,
                    relogio = { toque }, novaChave = { "chave-sintetica" }, escopo = escopo,
                    filaDeAcoes = fila, contaAtual = ::conta, registrarEvento = { e, _, _ -> eventos += e })
                vm.carregarFuncoes()
                if (preencher) { vm.escolherFuncao("funcao"); vm.editarValor("140"); vm.editarResponsavel("Pessoa sintética") }
                executar = vm::publicar
                estaNaFila = { vm.estado.value.naFila }
                concluida = { vm.estado.value.concluida }
                recusada = { vm.estado.value.erro == ErroGlobalPublicacao.RECUSADA_NA_FILA }
            }
        }
        fun sincronizador(dona: String = "pessoa-a") = SincronizadorDeAcoes(fila, { dona }, mapOf(tipo to { a ->
            enviar(if (republicar) a.republicacao!!.copy(chave = a.chave) else a.publicacao!!); Unit
        }))
    }
    private suspend fun casos(bloco: suspend (Cenario) -> Unit) {
        for (republicar in listOf(false, true)) {
            val escopo = CoroutineScope(Dispatchers.Unconfined + SupervisorJob())
            try { bloco(Cenario(republicar, escopo)) } finally { escopo.cancel() }
        }
    }
    @Test fun `sem rede persiste corpo chave e toque sem duplicar ao reabrir e reenvia uma vez`() = runBlocking { casos { c ->
        c.executar()?.join()
        val acao = c.fila.pendentes().single()
        assertEquals(c.tipo, acao.tipo)
        assertEquals("pessoa-a", acao.contaId)
        assertEquals(toque.toString(), acao.instanteDoToque)
        assertEquals("chave-sintetica", acao.chave)
        assertEquals(c.corpos.single(), acao.republicacao ?: acao.publicacao)
        assertEquals(listOf(acao), CacheVagasDaSessao(c.diretorio).filaDeAcoes.pendentes())
        c.executar()?.join(); c.abrir(); c.executar()?.join()
        assertTrue(c.estaNaFila()); assertEquals(1, c.pedidos)
        assertEquals(listOf(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE), c.eventos)
        c.codigo = null
        c.sincronizador().sincronizar(); c.sincronizador().sincronizar()
        assertEquals(2, c.pedidos)
        assertEquals(c.corpos[0], c.corpos[1])
        assertTrue(c.fila.pendentes().isEmpty()); assertTrue(c.concluida())
    } }
    @Test fun `recusa definitiva vira aviso minimo e libera uma nova tentativa`() = runBlocking { casos { c ->
        c.executar()?.join(); c.codigo = CodigoErroAPI.CAMPO_INVALIDO
        c.sincronizador().sincronizar()
        assertTrue(c.fila.pendentes().isEmpty()); assertTrue(c.recusada()); assertFalse(c.concluida())
        assertEquals(1, c.fila.recusadas().size)
        c.abrir(false); assertTrue(c.recusada()); c.abrir()
        c.codigo = null; c.executar()?.join()
        assertTrue(c.concluida()); assertTrue(c.fila.recusadas().isEmpty())
    } }
    @Test fun `outra conta descarta sem enviar e logout limpa estado e arquivo sem ciclo R4`() = runBlocking { casos { c ->
        c.executar()?.join(); c.sincronizador("pessoa-b").sincronizar()
        assertEquals(1, c.pedidos); assertTrue(c.fila.pendentes().isEmpty())
        c.entrar("pessoa-b"); c.abrir(); c.executar()?.join()
        val antes = c.leituras
        c.armazenamento.limparSessao()
        assertTrue(c.fila.pendentes().isEmpty()); assertFalse(c.estaNaFila()); assertFalse(c.concluida())
        assertFalse(File(c.diretorio, "acoes/fila.json").exists())
        assertTrue(c.leituras <= antes + 2)
        val versao = c.fila.versao.value
        repeat(3) { assertNull(c.armazenamento.obterSessao()) }
        assertEquals(versao, c.fila.versao.value)
    } }
    @Test fun `R4 logout com observador agendado estabiliza com fila vazia ou preenchida`() = runTest {
        for (republicar in listOf(false, true)) for (comAcao in listOf(false, true)) {
            val escopo = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
            try {
                val c = Cenario(republicar, escopo)
                runCurrent()
                // O catálogo foi carregado pelo dispatcher; preenche o formulário agora.
                if (comAcao) { c.abrir(); runCurrent(); c.executar(); runCurrent() }
                if (comAcao) assertTrue(c.estaNaFila())
                val antes = c.leituras
                val versao = c.fila.versao.value
                c.armazenamento.limparSessao(); runCurrent()
                assertEquals(if (comAcao) 1 else 0, c.fila.versao.value - versao)
                assertTrue(c.leituras <= antes + 2)
                assertFalse(c.estaNaFila()); assertFalse(c.concluida())
                println("R4-publicacao republicar=$republicar comAcao=$comAcao leituras=$antes->${c.leituras}")
            } finally { escopo.cancel() }
        }
    }
    @Test fun `sem sessao ou erro diferente de rede nao enfileira`() = runBlocking { casos { c ->
        c.codigo = CodigoErroAPI.CAMPO_INVALIDO; c.executar()?.join()
        assertTrue(c.fila.pendentes().isEmpty())
        c.codigo = CodigoErroAPI.SEM_REDE; c.armazenamento.limparSessao(); c.abrir(); c.executar()?.join()
        assertTrue(c.fila.pendentes().isEmpty()); assertTrue(c.eventos.isEmpty())
    } }
    @Test fun `logout durante pedido invalida tentativa mesmo entrando de novo na mesma conta`() = runBlocking { casos { c ->
        c.liberar = CompletableDeferred()
        val envio = c.executar()
        c.armazenamento.limparSessao(); c.entrar("pessoa-a"); c.liberar!!.complete(Unit); envio?.join()
        assertTrue(c.fila.pendentes().isEmpty()); assertFalse(c.estaNaFila()); assertTrue(c.eventos.isEmpty())
    } }
}
