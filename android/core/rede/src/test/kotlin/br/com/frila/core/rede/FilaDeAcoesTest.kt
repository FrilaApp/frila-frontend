package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
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
}
