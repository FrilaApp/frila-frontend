package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.*
import br.com.frila.core.seguranca.*
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import io.mockk.coEvery
import io.mockk.mockk
import java.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.koin.dsl.koinApplication
import org.koin.core.parameter.parametersOf
import org.koin.core.qualifier.named
import org.koin.dsl.module

@OptIn(ExperimentalCoroutinesApi::class)
class KoinFilaDeAvaliacaoTest {
    @Test fun `factories reais enfileiram avaliacao e checkin com a mesma conta da sessao`() = runBlocking {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val fila = FilaDeAcoes(null)
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"conta-sintetica"}""".toByteArray())
        armazenamento.salvarSessao(Sessao("cabecalho.$corpo.assinatura", "refresh-sintetico", "bearer", 3600))
        val servico = mockk<ServicoTurnos>()
        val erro = ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.SEM_REDE, "sem_rede", null, "sintético")
        coEvery { servico.avaliarTurno(any(), any()) } throws erro
        coEvery { servico.fazerCheckin(any(), any(), any()) } throws erro
        val app = koinApplication { modules(moduloFeatures, module {
            single { servico }
            single { fila }
            single<ArmazenamentoDeSessao> { armazenamento }
            single { mockk<RegistradorDeTelemetria>(relaxed = true) }
            single { mockk<ProvedorDeLocalizacao>(relaxed = true) }
            single { mockk<SincronizadorDeAcoes>(relaxed = true) }
            single(named("escopoDaFilaDeAcoes")) { CoroutineScope(SupervisorJob()) }
        }) }
        try {
            app.koin.get<CheckinViewModel> { parametersOf("turno", null) }.prosseguirCheckinManual().join()
            app.koin.get<AvaliacaoViewModel>().avaliar("turno", true).join()
            assertEquals(listOf(TipoAcaoPendente.CHECKIN, TipoAcaoPendente.AVALIACAO), fila.pendentes().map { it.tipo })
            assertEquals(listOf("conta-sintetica", "conta-sintetica"), fila.pendentes().map { it.contaId })
        } finally { app.close(); Dispatchers.resetMain() }
    }
}
