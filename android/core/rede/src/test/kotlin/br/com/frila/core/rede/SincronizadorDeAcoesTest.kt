package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class SincronizadorDeAcoesTest {
    @TempDir lateinit var diretorio: File
    private val fila by lazy { FilaDeAcoes(File(diretorio, "fila.json")) }
    private val enviadas = mutableListOf<AcaoPendente>()
    private var falha: ((AcaoPendente) -> Throwable?) = { null }
    private var conta: suspend () -> String = { "conta-a" }

    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name, null, "Erro sintético")
    private fun acao(tipo: TipoAcaoPendente = TipoAcaoPendente.CHECKIN, dono: String = "conta-a", turno: String = "turno-1") =
        AcaoPendente(tipo, dono, "2026-11-23T12:00:00Z", turnoId = turno, alvoId = "alvo", motivo = "motivo")
    private val envio: EnvioDeAcao = { a -> enviadas += a; falha(a)?.let { throw it } }
    private fun sincronizador() = SincronizadorDeAcoes(fila, { conta() }, TipoAcaoPendente.entries.associateWith { envio })

    @Test fun `sem rede a acao fica na fila e a passada para sem tentar as seguintes`() = runTest {
        val a = acao(); val b = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(a); fila.enfileirar(b)
        falha = { erro(CodigoErroAPI.SEM_REDE) }
        sincronizador().sincronizar()
        assertEquals(listOf(a), enviadas)
        assertEquals(listOf(a, b), fila.pendentes())
        assertTrue(fila.recusadas(true).isEmpty())
    }

    @Test fun `volta da rede envia uma unica vez, em ordem, com a chave e o instante guardados`() = runTest {
        val a = acao(); val b = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(a); fila.enfileirar(b)
        val sinc = sincronizador()
        sinc.sincronizar(); sinc.sincronizar()
        assertEquals(listOf(a, b), enviadas)
        assertEquals(a.chave, enviadas[0].chave)
        assertEquals("2026-11-23T12:00:00Z", enviadas[0].instanteDoToque)
        assertTrue(fila.pendentes().isEmpty())
    }

    @Test fun `erro que nao e rede nem recusa mantem a acao e segue para a proxima`() = runTest {
        val a = acao(); val b = acao(TipoAcaoPendente.CANCELAMENTO_VAGA)
        fila.enfileirar(a); fila.enfileirar(b)
        falha = { if (it.id == a.id) erro(CodigoErroAPI.DESCONHECIDO) else null }
        sincronizador().sincronizar()
        assertEquals(listOf(a), fila.pendentes())
        assertEquals(listOf(a, b), enviadas)
        assertTrue(fila.recusadas(true).isEmpty())
    }

    @Test fun `recusa definitiva sai dos reenvios e vira aviso minimo, uma por tipo de regra`() = runTest {
        val casos = listOf(
            TipoAcaoPendente.CHECKIN to CodigoErroAPI.FORA_DA_JANELA, TipoAcaoPendente.CHECKOUT to CodigoErroAPI.REGISTRO_NO_FUTURO,
            TipoAcaoPendente.AVALIACAO to CodigoErroAPI.AVALIACAO_INDISPONIVEL, TipoAcaoPendente.PUBLICACAO_VAGA to CodigoErroAPI.HORARIO_INVALIDO,
            TipoAcaoPendente.REPUBLICACAO_VAGA to CodigoErroAPI.VAGA_OCULTA, TipoAcaoPendente.CANCELAMENTO_POSICAO to CodigoErroAPI.POSICAO_NAO_CANCELAVEL,
            TipoAcaoPendente.CANCELAMENTO_VAGA to CodigoErroAPI.VAGA_ENCERRADA,
        )
        casos.forEach { (tipo, codigo) -> fila.enfileirar(acao(tipo)) }
        falha = { a -> erro(casos.first { it.first == a.tipo }.second) }
        sincronizador().sincronizar()
        assertTrue(fila.pendentes().isEmpty())
        assertEquals(casos.map { it.first to it.second }, fila.recusadas().map { it.tipo to it.codigo })
        sincronizador().sincronizar()
        assertEquals(7, enviadas.size, "recusa não volta aos reenvios")
    }

    @Test fun `checkout recusado por checkin pendente espera enquanto o checkin ainda esta na fila`() = runTest {
        val checkin = acao(); val checkout = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(checkin); fila.enfileirar(checkout)
        falha = { if (it.tipo == TipoAcaoPendente.CHECKIN) erro(CodigoErroAPI.DESCONHECIDO) else erro(CodigoErroAPI.CHECKIN_PENDENTE) }
        sincronizador().sincronizar()
        assertEquals(listOf(checkin, checkout), fila.pendentes())
    }

    @Test fun `acao de outra conta e descartada sem enviar e a da conta atual segue`() = runTest {
        val alheia = acao(dono = "conta-b"); val minha = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(alheia); fila.enfileirar(minha)
        sincronizador().sincronizar()
        assertEquals(listOf(minha), enviadas)
        assertTrue(fila.pendentes().isEmpty())
        assertTrue(fila.recusadas(true).isEmpty())
    }

    @Test fun `sem conhecer a conta nada e enviado nem descartado`() = runTest {
        val a = acao(); fila.enfileirar(a)
        conta = { throw erro(CodigoErroAPI.SEM_REDE) }
        sincronizador().sincronizar()
        conta = { throw IllegalStateException("sintético") }
        sincronizador().sincronizar()
        assertTrue(enviadas.isEmpty())
        assertEquals(listOf(a), fila.pendentes())
    }

    @Test fun `logout no meio do envio nao devolve a acao nem o aviso para a fila`() = runTest {
        val a = acao(); fila.enfileirar(a)
        falha = { fila.limpar(); erro(CodigoErroAPI.FORA_DA_JANELA) }
        sincronizador().sincronizar()
        assertTrue(fila.pendentes().isEmpty() && fila.recusadas(true).isEmpty())
    }

    @Test fun `observar reenvia quando o monitor passa a conectado`() = runTest {
        val a = acao(); fila.enfileirar(a)
        val monitor = MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO)
        sincronizador().observar(monitor, backgroundScope)
        runCurrent()
        assertTrue(enviadas.isEmpty())
        monitor.definirStatus(StatusConectividade.CONECTADO)
        runCurrent()
        assertEquals(listOf(a), enviadas)
        assertTrue(fila.pendentes().isEmpty())
    }

    /** Revisão do #1039 (R1): limpar a fila e trocar de conta durante um envio encerra a passada da conta que saiu. */
    @Test fun `fila limpa e troca de conta durante o envio param a passada antes do proximo envio`() = runTest {
        var dona = "conta-a"
        conta = { dona }
        val entrada = acao(); val saida = acao(TipoAcaoPendente.CHECKOUT)
        val daB = acao(dono = "conta-b", turno = "turno-b")
        fila.enfileirar(entrada); fila.enfileirar(saida)
        val vistos = mutableListOf<String>()
        val envioQueTrocaDeConta: EnvioDeAcao = { a ->
            vistos += "${a.tipo}:dono=${a.contaId}:sessao=$dona"
            if (a.id == entrada.id) { fila.limpar(); dona = "conta-b"; fila.enfileirar(daB) }
        }
        val sinc = SincronizadorDeAcoes(fila, { conta() }, TipoAcaoPendente.entries.associateWith { envioQueTrocaDeConta })
        sinc.sincronizar()
        assertEquals(listOf("CHECKIN:dono=conta-a:sessao=conta-a"), vistos)
        // A ação da conta nova não foi descartada pela passada antiga: sai na próxima, com a conta relida.
        assertEquals(listOf(daB), fila.pendentes())
        sinc.sincronizar()
        assertEquals(listOf("CHECKIN:dono=conta-a:sessao=conta-a", "CHECKIN:dono=conta-b:sessao=conta-b"), vistos)
        assertTrue(fila.pendentes().isEmpty())
    }

    @Test fun `logout enquanto a conta e confirmada nao envia nada`() = runTest {
        fila.enfileirar(acao())
        conta = { fila.limpar(); "conta-a" }
        sincronizador().sincronizar()
        assertTrue(enviadas.isEmpty())
        assertTrue(fila.pendentes().isEmpty())
    }

    @Test fun `acao que saiu da fila durante a passada nao e enviada`() = runTest {
        val a = acao(); val b = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(a); fila.enfileirar(b)
        falha = { if (it.id == a.id) fila.remover(b.id); null }
        sincronizador().sincronizar()
        assertEquals(listOf(a), enviadas)
    }

    @Test fun `disco que falha ao encerrar os avisos nao impede a acao aceita de sair da fila nem a faz ser reenviada`() = runTest {
        val arquivo = File(diretorio, "acoes/fila.json")
        val comDisco = FilaDeAcoes(arquivo)
        val a = acao()
        comDisco.enfileirar(a)
        // A pasta da fila vira um arquivo: o envio é aceito e a gravação seguinte lança IOException.
        val pasta = File(diretorio, "acoes")
        pasta.deleteRecursively(); assertTrue(pasta.createNewFile())
        val sinc = SincronizadorDeAcoes(comDisco, { "conta-a" }, TipoAcaoPendente.entries.associateWith { envio })
        sinc.sincronizar(); sinc.sincronizar()
        assertEquals(listOf(a), enviadas)
        assertTrue(comDisco.pendentes().isEmpty())
    }
}
