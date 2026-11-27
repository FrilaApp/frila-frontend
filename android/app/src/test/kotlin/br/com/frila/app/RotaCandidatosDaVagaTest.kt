package br.com.frila.app

import android.app.Application
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * iUpi3Es4: a rota dos candidatos leva a casa (`estabelecimentoId`, opcional), para o ViewModel conferir o painel quando a
 * resposta da escolha se perde. O aviso push abre a rota só com a vaga. `Uri.encode` pede o Robolectric.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RotaCandidatosDaVagaTest {

    private val inicio = Instant.parse("2026-11-12T18:00:00Z")

    @Test
    fun `o padrao da rota tem a casa opcional`() {
        assertTrue(Rotas.CANDIDATOS_DA_VAGA, Rotas.CANDIDATOS_DA_VAGA.contains("estabelecimentoId={estabelecimentoId}"))
    }

    @Test
    fun `a rota montada leva a casa codificada, junto dos outros parametros`() {
        assertEquals(
            "candidatos_da_vaga/vaga-1?posicoesAbertas=2&inicioDaVaga=2026-11-12T18%3A00%3A00Z&estabelecimentoId=casa%201%2Fx",
            Rotas.candidatosDaVaga("vaga-1", 2, inicio, "casa 1/x"),
        )
        assertEquals("candidatos_da_vaga/vaga-1?estabelecimentoId=casa-1", Rotas.candidatosDaVaga("vaga-1", estabelecimentoId = "casa-1"))
    }

    @Test
    fun `sem a casa, como no aviso push, a rota nao traz o parametro`() {
        assertEquals("candidatos_da_vaga/vaga-1", Rotas.candidatosDaVaga("vaga-1"))
        assertEquals("candidatos_da_vaga/vaga-1?posicoesAbertas=2", Rotas.candidatosDaVaga("vaga-1", 2))
    }
}
