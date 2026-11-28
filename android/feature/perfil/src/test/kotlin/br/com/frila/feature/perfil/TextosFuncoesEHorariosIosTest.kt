package br.com.frila.feature.perfil

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão hTiU4e4a (item 303): as três mensagens de validação de Funções e horários são as do iOS (`TextosDoProfissional.swift:317,319,333`), escritas aqui por extenso.
 * E as cópias dessas mensagens no `strings.xml`, que nenhum código usa hoje, não podem ficar com o texto antigo: um dia alguém as usa e a tela volta a dizer outra coisa.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TextosFuncoesEHorariosIosTest {

    private fun recurso(id: Int) = ApplicationProvider.getApplicationContext<Application>().getString(id)

    @Test
    fun `sem funcao, a mensagem e a do iOS`() {
        assertEquals("Selecione ao menos uma função.", TextosFuncoesEHorarios.ERRO_SEM_FUNCAO)
    }

    @Test
    fun `horarios iguais, a mensagem e a do iOS, com fim e nao termino`() {
        assertEquals("O horário de início e fim não podem ser iguais.", TextosFuncoesEHorarios.ERRO_HORARIOS_IGUAIS)
    }

    @Test
    fun `formato da hora, a mensagem e a do iOS`() {
        assertEquals("Horário inválido. Use o formato HH:mm.", TextosFuncoesEHorarios.ERRO_FORMATO_HORA)
    }

    @Test
    fun `a mensagem de sem funcao e a mesma da tela do ponto base`() {
        assertEquals(TextosPontoBase.ERRO_SEM_FUNCAO, TextosFuncoesEHorarios.ERRO_SEM_FUNCAO)
    }

    @Test
    fun `a copia do strings xml de sem funcao nao diverge`() {
        assertEquals(TextosFuncoesEHorarios.ERRO_SEM_FUNCAO, recurso(R.string.funcoes_horarios_erro_sem_funcao))
    }

    @Test
    fun `a copia do strings xml de horarios iguais nao diverge`() {
        assertEquals(TextosFuncoesEHorarios.ERRO_HORARIOS_IGUAIS, recurso(R.string.funcoes_horarios_erro_horarios_iguais))
    }

    @Test
    fun `a copia do strings xml do formato da hora nao diverge`() {
        assertEquals(TextosFuncoesEHorarios.ERRO_FORMATO_HORA, recurso(R.string.funcoes_horarios_erro_formato_hora))
    }
}
