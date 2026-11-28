package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.io.File
import java.io.IOException
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/**
 * TK6oQV0R: o texto da fila de presença, com as frases do iOS (`TextosDaPresenca.swift`, `checkinNaFila(_:manual:)` e
 * `checkoutNaFila`). O check-in sem localização entra na fila como manual e diz que aguarda a confirmação do contratante; o
 * check-out tem a frase própria.
 */
class TextosDaFilaDePresencaTest {
    @TempDir lateinit var diretorio: File

    /** 03:10 UTC são 00:10 em São Paulo. */
    private val agora = Instant.parse("2026-11-02T03:10:00Z")

    private val checkinComum =
        "Sem conexão. O check-in das 00:10 está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."
    private val checkinManual =
        "Sem conexão. O check-in manual das 00:10 está guardado neste aparelho e será enviado quando a internet voltar, com esse horário. " +
            "Depois ele aguarda a confirmação do contratante."
    private val checkout =
        "Sem conexão. O check-out das 00:10 está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."

    @Test
    fun `check-in manual na fila diz que aguarda a confirmacao do contratante`() {
        assertEquals(checkinManual, TextosDaFilaDePresenca.checkinNaFila(RegistroNaFila(agora, manual = true)))
    }

    @Test
    fun `check-in com localizacao na fila nao fala em confirmacao`() {
        assertEquals(checkinComum, TextosDaFilaDePresenca.checkinNaFila(RegistroNaFila(agora, manual = false)))
    }

    @Test
    fun `check-out na fila tem a frase propria, e nao a do check-in`() {
        assertEquals(checkout, TextosDaFilaDePresenca.checkoutNaFila(RegistroNaFila(agora, manual = false)))
    }

    // ---- pelo CheckinViewModel de verdade, sem rede ----

    private val semRede: ServicoTurnos by lazy {
        ServicoTurnos(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { throw IOException("sem rede sintética") }))
    }

    /** Com permissão e GPS, mas sem leitura (sem sinal): o check-in segue sem distância, como manual. */
    private fun semLeitura(): ProvedorDeLocalizacao = mockk<ProvedorDeLocalizacao>().also {
        every { it.temPermissaoDeLocalizacao() } returns true
        every { it.isGpsAtivado() } returns true
        coEvery { it.lerParaCheckin() } returns null
    }

    private fun viewModel() = CheckinViewModel(
        turnoId = "11111111-1111-1111-1111-111111111111",
        coordenadaDaVaga = Coordenada(latitude = -15.7942, longitude = -47.8822),
        servicoTurnos = semRede,
        provedorDeLocalizacao = semLeitura(),
        instanteAtual = { agora },
        escopo = CoroutineScope(Dispatchers.Unconfined),
        filaDeAcoes = FilaDeAcoes(File(diretorio, "fila.json")),
        contaAtual = { "conta-sintetica" },
        pedirReenvio = {},
    )

    @Test
    fun `check-in sem distancia e sem rede entra na fila como manual e mostra a frase do manual`() {
        val vm = viewModel()

        runBlocking { vm.fazerCheckin().join() }

        val registro = vm.estado.value.checkinNaFila
        assertEquals(RegistroNaFila(agora, manual = true), registro)
        assertEquals(checkinManual, TextosDaFilaDePresenca.checkinNaFila(registro!!))
    }

    @Test
    fun `check-out sem rede entra na fila e mostra a frase do check-out`() {
        val vm = viewModel()

        runBlocking { vm.fazerCheckout().join() }

        assertEquals(StatusCheckout.NA_FILA, vm.estado.value.checkout)
        assertEquals(checkout, TextosDaFilaDePresenca.checkoutNaFila(vm.estado.value.checkoutNaFila!!))
    }
}
