package br.com.frila.core.designsystem.abertura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A duração da abertura mora numa constante só ([duracaoDaAbertura]); o encaixe, a saída e os quadros-chave derivam dela
 * por proporção. Estes testes provam que o roteiro escala ao trocar a duração e que o roteiro reduzido é o de 0,9 s.
 */
class RoteiroDaAberturaTest {

    private val folga = 1e-9

    @Test
    fun `a duracao da abertura e 2,8 s, o valor do Fabricio`() {
        assertEquals(2.8, duracaoDaAbertura, 0.0)
    }

    @Test
    fun `o roteiro completo usa a constante e guarda as proporcoes do prototipo`() {
        val roteiro = RoteiroDaAbertura.completo()
        assertEquals(duracaoDaAbertura, roteiro.duracao, folga)
        val escala = duracaoDaAbertura / 2.82
        assertEquals(1.11 * escala, roteiro.encaixe!!, folga)
        assertEquals(2.40 * escala, roteiro.saida, folga)
        // As razões do protótipo (1,11 / 2,82 e 2,40 / 2,82) não mudam com a duração.
        assertEquals(1.11 / 2.82, roteiro.encaixe!! / roteiro.duracao, folga)
        assertEquals(2.40 / 2.82, roteiro.saida / roteiro.duracao, folga)
    }

    @Test
    fun `com 2,82 s o roteiro e exatamente o do prototipo`() {
        val roteiro = RoteiroDaAbertura.completo(2.82)
        assertEquals(1.11, roteiro.encaixe!!, folga)
        assertEquals(2.40, roteiro.saida, folga)
        assertEquals(2.82, roteiro.duracao, folga)
        assertEquals(1.0, roteiro.escala, folga)
    }

    @Test
    fun `trocar a duracao para 1,5 s escala encaixe, saida e o tempo dos quadros`() {
        val padrao = RoteiroDaAbertura.completo()
        val curto = RoteiroDaAbertura.completo(1.5)

        assertEquals(1.5, curto.duracao, folga)
        // Tudo escala pela mesma razão entre as duas durações.
        val razao = 1.5 / duracaoDaAbertura
        assertEquals(padrao.encaixe!! * razao, curto.encaixe!!, folga)
        assertEquals(padrao.saida * razao, curto.saida, folga)
        assertEquals(padrao.escala * razao, curto.escala, folga)

        // O instante do encaixe do roteiro curto cai no mesmo quadro da coreografia que o do padrão.
        assertEquals(padrao.tempoDeReferencia(padrao.encaixe!!), curto.tempoDeReferencia(curto.encaixe!!), folga)
        assertEquals(1.11, curto.tempoDeReferencia(curto.encaixe!!), folga)
        assertEquals(2.40, curto.tempoDeReferencia(curto.saida), folga)
        // O fim do roteiro cai no fim da coreografia, qualquer que seja a duração.
        assertEquals(CoreografiaDaAbertura.DURACAO_DE_REFERENCIA, curto.tempoDeReferencia(curto.duracao), folga)
        assertEquals(CoreografiaDaAbertura.DURACAO_DE_REFERENCIA, padrao.tempoDeReferencia(padrao.duracao), folga)
    }

    @Test
    fun `os quadros da coreografia escalam - o mesmo quadro chega proporcionalmente antes`() {
        val padrao = RoteiroDaAbertura.completo()
        val curto = RoteiroDaAbertura.completo(1.4)
        // No meio do roteiro de cada um (50%), o quadro é o mesmo.
        val meioPadrao = CoreografiaDaAbertura.quadro(padrao.tempoDeReferencia(padrao.duracao * 0.5))
        val meioCurto = CoreografiaDaAbertura.quadro(curto.tempoDeReferencia(curto.duracao * 0.5))
        assertEquals(meioPadrao.rX, meioCurto.rX, 1e-9)
        assertEquals(meioPadrao.iCurva, meioCurto.iCurva, 1e-9)
        assertEquals(meioPadrao.zoom, meioCurto.zoom, 1e-9)
        assertEquals(meioPadrao.sacudida, meioCurto.sacudida, 1e-9)
        assertEquals(meioPadrao.fOpacidade, meioCurto.fOpacidade, 1e-9)
        // E a janela do pingo só começa a abrir na saída, em qualquer duração.
        val antesDaSaida = CoreografiaDaAbertura.quadro(curto.tempoDeReferencia(curto.saida * 0.99))
        val depoisDaSaida = CoreografiaDaAbertura.quadro(curto.tempoDeReferencia(curto.saida + curto.duracao * 0.05))
        assertEquals(0.0, antesDaSaida.abertura, 1e-3)
        assertTrue(depoisDaSaida.abertura > 0.0)
    }

    @Test
    fun `o roteiro reduzido tem 0,9 s, saida em 0,6 s, sem encaixe e com esmaecimento`() {
        val reduzido = RoteiroDaAbertura.reduzido()
        assertEquals(0.9, reduzido.duracao, folga)
        assertEquals(0.6, reduzido.saida, folga)
        assertNull(reduzido.encaixe)
        assertTrue(reduzido.reduzido)

        assertEquals(1.0, reduzido.opacidadeReduzida(0.3), folga)
        assertEquals(1.0, reduzido.opacidadeReduzida(0.6), folga)
        assertEquals(0.5, reduzido.opacidadeReduzida(0.75), folga)
        assertEquals(0.0, reduzido.opacidadeReduzida(0.9), folga)
    }

    @Test
    fun `o roteiro cheio nunca esmaece como o reduzido`() {
        val cheio = RoteiroDaAbertura.completo()
        assertEquals(1.0, cheio.opacidadeReduzida(2.7), folga)
    }

    @Test
    fun `o reduzido nunca passa da duracao cheia pedida`() {
        assertEquals(0.5, RoteiroDaAbertura.reduzido(0.5).duracao, folga)
        assertEquals(0.9, RoteiroDaAbertura.reduzido(5.0).duracao, folga)
    }

    @Test
    fun `para escolhe o roteiro pelo movimento reduzido`() {
        assertTrue(RoteiroDaAbertura.para(reduzirMovimento = true).reduzido)
        assertEquals(duracaoDaAbertura, RoteiroDaAbertura.para(reduzirMovimento = false).duracao, folga)
    }

    @Test
    fun `a coreografia comeca fora de cena e termina com a janela aberta e o rotulo sumido`() {
        val inicio = CoreografiaDaAbertura.quadro(0.0)
        assertEquals(0.0, inicio.rOpacidade, 0.0)
        assertEquals(0.0, inicio.iOpacidade, 0.0)
        assertEquals(0.0, inicio.abertura, 0.0)

        val fim = CoreografiaDaAbertura.quadro(CoreografiaDaAbertura.DURACAO_DE_REFERENCIA)
        assertEquals(1.0, fim.abertura, 1e-6)
        assertEquals(0.0, fim.rotuloOpacidade, 1e-6)
        assertEquals(1.0, fim.zoom, 1e-6)
        assertEquals(0.0, fim.fX, 1e-6)
        assertEquals(0.0, fim.lX, 1e-6)
        assertEquals(0.0, fim.aX, 1e-6)
    }

    @Test
    fun `o par assenta no repouso do rotulo antes da camera sair`() {
        val q = CoreografiaDaAbertura.quadro(2.0)
        assertEquals(0.0, q.rX, 0.5)
        assertEquals(0.0, q.iX, 0.5)
        assertEquals(1.0, q.maos, 1e-6)
        assertEquals(1.0, q.pingoEscala, 1e-3)
    }

    @Test
    fun `faixa linear, cubica e mola chegam ao alvo e seguram o valor`() {
        val f = faixa(0.0) {
            linear(1.0, 1.0)
            cubica(2.0, 1.0)
            mola(3.0, 1.0, MolaDaAbertura(0.5, 0.2))
            cubica(3.0, 0.5)
        }
        assertEquals(0.0, f.valor(0.0), folga)
        assertEquals(1.0, f.valor(1.0), 1e-6)
        assertEquals(2.0, f.valor(2.0), 1e-6)
        assertEquals(3.0, f.valor(3.5), 1e-6)
        assertEquals(3.0, f.valor(10.0), 1e-6)
        assertEquals(3.5, f.duracao, folga)
    }

    @Test
    fun `a mola passa do alvo uma vez e volta`() {
        val f = faixa(0.0) { mola(1.0, 0.6, MolaDaAbertura(0.45, 0.2)) }
        val maximo = (0..60).maxOf { f.valor(it / 100.0) }
        assertTrue("a mola com sobra passa do alvo", maximo > 1.0)
        assertTrue("mas pouco", maximo < 1.3)
    }
}
