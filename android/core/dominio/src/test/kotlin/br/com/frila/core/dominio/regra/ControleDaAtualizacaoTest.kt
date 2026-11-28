package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.regra.DecisaoDaAtualizacao.Esperar
import br.com.frila.core.dominio.regra.DecisaoDaAtualizacao.Ignorar
import br.com.frila.core.dominio.regra.DecisaoDaAtualizacao.Recarregar
import br.com.frila.core.dominio.regra.ListaAtualizavel.EQUIPE_DE_CONFIANCA
import br.com.frila.core.dominio.regra.ListaAtualizavel.MEUS_TURNOS
import br.com.frila.core.dominio.regra.ListaAtualizavel.MINHAS_CANDIDATURAS
import br.com.frila.core.dominio.regra.ListaAtualizavel.MINHAS_VAGAS
import br.com.frila.core.dominio.regra.ListaAtualizavel.VAGAS
import java.time.Duration
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * A regra da atualização automática das listas (HaRJJ0L0, fatia 1), porte 1:1 de `ControleDaAtualizacaoTests`
 * (`AtualizacaoAutomaticaTests.swift`): mesmos cenários, mesmos instantes e mesmos resultados. O tempo é conduzido pelo teste.
 */
class ControleDaAtualizacaoTest {

    private val inicio = Instant.parse("2026-11-27T12:00:00Z")
    private fun depois(segundos: Long) = inicio.plusSeconds(segundos)
    private fun segundos(n: Long) = Duration.ofSeconds(n)

    private fun controleComSessao() = ControleDaAtualizacao(intervaloMinimo = segundos(30)).also { it.mudarSessao(ativa = true) }

    @Test
    fun `sem sessao nenhum pedido passa e o aviso de push nao conta`() {
        val controle = ControleDaAtualizacao(intervaloMinimo = segundos(30))
        assertEquals(Ignorar, controle.pedir(VAGAS, inicio))
        controle.avisoChegou()
        assertEquals(0, controle.avisos)
        assertFalse(controle.emVoo(VAGAS))
    }

    @Test
    fun `intervalo minimo entre recargas da mesma lista, contado do fim da anterior`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(VAGAS, inicio))
        assertEquals(Ignorar, controle.concluir(VAGAS, depois(2)))
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(20)))
        // 31 s do início, mas só 29 s do fim da anterior.
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(31)))
        assertEquals(Recarregar, controle.pedir(VAGAS, depois(32)))
    }

    @Test
    fun `a carga da propria tela conta como recarga para o intervalo`() {
        val controle = controleComSessao()
        controle.registrarCarga(MEUS_TURNOS, inicio)
        assertEquals(Ignorar, controle.pedir(MEUS_TURNOS, depois(10)))
        assertEquals(Recarregar, controle.pedir(MEUS_TURNOS, depois(30)))
    }

    @Test
    fun `com uma recarga em voo o segundo pedido da mesma lista nao abre outra`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(MINHAS_VAGAS, inicio))
        assertTrue(controle.emVoo(MINHAS_VAGAS))
        assertEquals(Ignorar, controle.pedir(MINHAS_VAGAS, depois(60)))
        assertEquals(Ignorar, controle.concluir(MINHAS_VAGAS, depois(61)))
        assertFalse(controle.emVoo(MINHAS_VAGAS))
    }

    @Test
    fun `cada lista tem a propria vez e o proprio intervalo`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(VAGAS, inicio))
        assertEquals(Recarregar, controle.pedir(MINHAS_CANDIDATURAS, inicio))
        controle.concluir(VAGAS, inicio)
        assertEquals(Recarregar, controle.pedir(MEUS_TURNOS, depois(1)))
    }

    @Test
    fun `o aviso de push passa por cima do intervalo, uma vez por aviso`() {
        val controle = controleComSessao()
        controle.registrarCarga(VAGAS, inicio)
        controle.avisoChegou()
        assertEquals(Recarregar, controle.pedir(VAGAS, depois(5)))
        assertEquals(Ignorar, controle.concluir(VAGAS, depois(6)))
        // O mesmo aviso, já atendido, não fura de novo.
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(7)))
    }

    @Test
    fun `aviso que chega com a recarga em voo faz a lista ser lida mais uma vez, e so uma, depois dos 3 s`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(VAGAS, inicio))
        controle.avisoChegou()
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(1)))
        controle.avisoChegou()
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(1)))
        // A repetição não sai colada na recarga que acabou: espera o intervalo curto do push.
        assertEquals(Esperar(segundos(3)), controle.concluir(VAGAS, depois(2)))
        assertTrue(controle.emVoo(VAGAS))
        assertEquals(Recarregar, controle.retomar(VAGAS, depois(5)))
        assertEquals(Ignorar, controle.concluir(VAGAS, depois(6)))
        assertFalse(controle.emVoo(VAGAS))
    }

    @Test
    fun `rajada de pushes logo depois de uma recarga - no maximo uma releitura a cada 3 s`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(VAGAS, inicio))
        assertEquals(Ignorar, controle.concluir(VAGAS, inicio))

        // Primeiro push, 1 s depois: passa por cima dos 30 s, mas espera o que falta dos 3 s.
        controle.avisoChegou()
        assertEquals(Esperar(segundos(2)), controle.pedir(VAGAS, depois(1)))
        assertTrue(controle.emVoo(VAGAS))
        // Mais pushes durante a espera: nenhum abre outra recarga nem outra espera.
        repeat(4) {
            controle.avisoChegou()
            assertEquals(Ignorar, controle.pedir(VAGAS, depois(2)))
        }
        // Retomar cedo demais espera o resto.
        assertEquals(Esperar(Duration.ofMillis(500)), controle.retomar(VAGAS, inicio.plusMillis(2500)))
        // A releitura que sai atende todos os avisos da rajada: ao concluir, nada de repetição.
        assertEquals(Recarregar, controle.retomar(VAGAS, depois(3)))
        assertEquals(Ignorar, controle.concluir(VAGAS, depois(4)))
        assertFalse(controle.emVoo(VAGAS))
        // Um push novo 1 s depois espera de novo os 3 s; não relê colado.
        controle.avisoChegou()
        assertEquals(Esperar(segundos(2)), controle.pedir(VAGAS, depois(5)))
    }

    @Test
    fun `saida da tela durante a espera do push libera a vez`() {
        val controle = controleComSessao()
        controle.registrarCarga(MINHAS_VAGAS, inicio)
        controle.avisoChegou()
        assertEquals(Esperar(segundos(2)), controle.pedir(MINHAS_VAGAS, depois(1)))
        controle.desistir(MINHAS_VAGAS)
        assertFalse(controle.emVoo(MINHAS_VAGAS))
        // O aviso continua sem atender: na volta da tela, relê.
        assertEquals(Recarregar, controle.pedir(MINHAS_VAGAS, depois(2)))
    }

    @Test
    fun `a lista escondida atende o aviso quando volta a pedir, mesmo dentro do intervalo`() {
        val controle = controleComSessao()
        controle.registrarCarga(MEUS_TURNOS, inicio)
        controle.avisoChegou()
        // Nenhum pedido enquanto escondida; ao reaparecer, 10 s depois:
        assertEquals(Recarregar, controle.pedir(MEUS_TURNOS, depois(10)))
    }

    @Test
    fun `troca de conta esquece os intervalos da anterior, e sair corta os pedidos`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(VAGAS, inicio))
        controle.concluir(VAGAS, inicio)
        controle.mudarSessao(ativa = false)
        assertEquals(Ignorar, controle.pedir(VAGAS, depois(100)))
        controle.mudarSessao(ativa = true)
        assertEquals(Recarregar, controle.pedir(VAGAS, depois(1)))
    }

    @Test
    fun `recarga cancelada libera a vez e nao conta para o intervalo`() {
        val controle = controleComSessao()
        assertEquals(Recarregar, controle.pedir(EQUIPE_DE_CONFIANCA, inicio))
        controle.desistir(EQUIPE_DE_CONFIANCA)
        assertFalse(controle.emVoo(EQUIPE_DE_CONFIANCA))
        assertEquals(Recarregar, controle.pedir(EQUIPE_DE_CONFIANCA, depois(1)))
    }

    @Test
    fun `os intervalos padrao sao 30 s e 3 s`() {
        assertEquals(segundos(30), ControleDaAtualizacao().intervaloMinimo)
        assertEquals(segundos(3), ControleDaAtualizacao().intervaloDoAviso)
    }
}
