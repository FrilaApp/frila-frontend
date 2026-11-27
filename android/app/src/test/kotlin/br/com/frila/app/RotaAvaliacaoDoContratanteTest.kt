package br.com.frila.app

import android.app.Application
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 288rCCAg: a rota da avaliação do contratante leva a casa (`estabelecimentoId`), porque `meus_turnos` sem `estabelecimento_id`
 * devolve lista vazia para a conta de contratante e a tela não acharia o turno. `Uri.encode` pede o Robolectric.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RotaAvaliacaoDoContratanteTest {

    @Test
    fun `o padrao da rota tem o turno e a casa opcional`() {
        assertEquals("avaliacao_contratante/{turnoId}?estabelecimentoId={estabelecimentoId}", Rotas.AVALIACAO_DO_CONTRATANTE)
    }

    @Test
    fun `a rota montada leva a casa, codificada`() {
        assertEquals("avaliacao_contratante/t-1?estabelecimentoId=casa-1", Rotas.avaliacaoDoContratante("t-1", "casa-1"))
        assertEquals(
            "avaliacao_contratante/t-1?estabelecimentoId=casa%201%2Fx",
            Rotas.avaliacaoDoContratante("t-1", "casa 1/x"),
        )
    }

    @Test
    fun `sem a casa a rota continua valendo, sem o parametro`() {
        assertEquals("avaliacao_contratante/t-1", Rotas.avaliacaoDoContratante("t-1"))
    }
}
