package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import java.io.IOException
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class FilaDeAcoesTest {
    @TempDir lateinit var diretorio: File
    private val arquivo get() = File(diretorio, "acoes/fila.json")
    private fun acao(tipo: TipoAcaoPendente = TipoAcaoPendente.CHECKIN, conta: String = "conta-a") =
        AcaoPendente(tipo, conta, "2026-11-23T12:00:00Z", turnoId = "turno-1", distanciaMetros = 42)

    @Test fun `guarda a acao com instante, chave e campos e uma nova instancia le o mesmo arquivo`() {
        val a = acao()
        FilaDeAcoes(arquivo).enfileirar(a)
        assertEquals(listOf(a), FilaDeAcoes(arquivo).pendentes())
        assertEquals("2026-11-23T12:00:00Z", FilaDeAcoes(arquivo).pendentes().single().instanteDoToque)
    }

    @Test fun `enfileirar o mesmo id duas vezes nao duplica e a ordem de chegada e mantida`() {
        val fila = FilaDeAcoes(arquivo)
        val a = acao(); val b = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(a); fila.enfileirar(b); fila.enfileirar(a)
        assertEquals(listOf(a, b), fila.pendentes())
    }

    @Test fun `recusar tira dos reenvios e guarda so o registro minimo na mesma gravacao`() {
        val fila = FilaDeAcoes(arquivo)
        val a = acao()
        fila.enfileirar(a)
        fila.recusar(a, CodigoErroAPI.FORA_DA_JANELA)
        val outra = FilaDeAcoes(arquivo)
        assertTrue(outra.pendentes().isEmpty())
        assertEquals(AcaoRecusada(a.id, a.tipo, "conta-a", CodigoErroAPI.FORA_DA_JANELA, turnoId = "turno-1"), outra.recusadas().single())
        assertFalse(arquivo.readText().contains("distancia"), "a distância não vai para o registro da recusa")
    }

    @Test fun `reconhecer fecha o aviso, mas o registro continua para a reconciliacao`() {
        val fila = FilaDeAcoes(arquivo)
        val a = acao(); fila.enfileirar(a); fila.recusar(a, CodigoErroAPI.SEM_PERMISSAO)
        fila.reconhecerRecusa(a.id)
        assertTrue(fila.recusadas().isEmpty())
        assertEquals(1, fila.recusadas(incluirReconhecidas = true).size)
    }

    @Test fun `tentativa aceita encerra os avisos anteriores da mesma operacao e conta`() {
        val fila = FilaDeAcoes(arquivo)
        val antiga = acao(); fila.enfileirar(antiga); fila.recusar(antiga, CodigoErroAPI.FORA_DA_JANELA)
        val outraConta = acao(conta = "conta-b"); fila.enfileirar(outraConta); fila.recusar(outraConta, CodigoErroAPI.FORA_DA_JANELA)
        val nova = acao(); fila.enfileirar(nova)
        fila.resolverRecusas(nova)
        assertEquals(listOf(outraConta.id), fila.recusadas(incluirReconhecidas = true).map { it.id })
    }

    @Test fun `limpar apaga memoria e arquivo e retorno de envio em voo nao repovoa a fila`() {
        val fila = FilaDeAcoes(arquivo)
        val a = acao(); fila.enfileirar(a)
        fila.limpar()
        fila.recusar(a, CodigoErroAPI.FORA_DA_JANELA); fila.remover(a.id); fila.resolverRecusas(a)
        assertTrue(fila.pendentes().isEmpty() && fila.recusadas(true).isEmpty())
        assertFalse(arquivo.exists())
        assertTrue(FilaDeAcoes(arquivo).pendentes().isEmpty())
    }

    @Test fun `arquivo corrompido comeca uma fila vazia e sem arquivo funciona so em memoria`() {
        arquivo.parentFile.mkdirs(); arquivo.writeText("{não é json")
        assertTrue(FilaDeAcoes(arquivo).pendentes().isEmpty())
        val emMemoria = FilaDeAcoes(null)
        emMemoria.enfileirar(acao())
        assertEquals(1, emMemoria.pendentes().size)
    }

    @Test fun `limpar fila ja vazia nao muda a versao mas sempre muda a geracao`() {
        val fila = FilaDeAcoes(File(diretorio, "vazia.json"))
        val versao = fila.versao.value
        val geracao = fila.geracao()
        fila.limpar()
        assertEquals(versao, fila.versao.value)
        assertEquals(geracao + 1, fila.geracao())
        fila.enfileirar(AcaoPendente(TipoAcaoPendente.CHECKIN, "conta-a", "2026-11-23T12:00:00Z", turnoId = "turno-1"))
        val comAcao = fila.versao.value
        fila.limpar()
        assertEquals(comAcao + 1, fila.versao.value)
        assertEquals(geracao + 2, fila.geracao())
        fila.limpar()
        assertEquals(comAcao + 1, fila.versao.value)
    }

    @Test fun `enfileirar com disco que falha deixa memoria e versao como estavam e a excecao sobe`() {
        val fila = FilaDeAcoes(arquivo)
        val primeira = acao()
        fila.enfileirar(primeira)
        val versao = fila.versao.value
        val pasta = arquivo.parentFile
        pasta.deleteRecursively(); pasta.writeText("agora é um arquivo: o disco não grava")
        assertThrows(IOException::class.java) { fila.enfileirar(acao(TipoAcaoPendente.CHECKOUT)) }
        assertEquals(listOf(primeira), fila.pendentes())
        assertEquals(versao, fila.versao.value)
        pasta.delete()
        val volta = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(volta)
        assertEquals(listOf(primeira, volta), fila.pendentes())
        assertEquals(versao + 1, fila.versao.value)
        assertEquals(listOf(primeira, volta), FilaDeAcoes(arquivo).pendentes())
    }

    @Test fun `recusar com disco que falha continua valendo na memoria para nao reenviar em laco`() {
        val fila = FilaDeAcoes(arquivo)
        val a = acao()
        fila.enfileirar(a)
        val pasta = arquivo.parentFile
        pasta.deleteRecursively(); pasta.writeText("sem disco")
        assertThrows(IOException::class.java) { fila.recusar(a, CodigoErroAPI.FORA_DA_JANELA) }
        assertTrue(fila.pendentes().isEmpty())
        assertEquals(a.id, fila.recusadas().single().id)
    }
}
