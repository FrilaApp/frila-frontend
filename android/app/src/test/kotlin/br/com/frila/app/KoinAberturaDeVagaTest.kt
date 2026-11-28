package br.com.frila.app

import br.com.frila.core.dominio.modelo.EstadoCandidatura
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.EstadoAberturaDeVaga
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.koin.core.parameter.parametersOf
import org.koin.dsl.koinApplication
import org.koin.dsl.module

/**
 * Cartão xdvUylw7 (item 271): a fiação real da abertura de vaga pelo aviso. Sem `buscarMinhasCandidaturas` no registro, o view
 * model não lê a candidatura, e quem foi recusado volta a ler "Vaga preenchida", sem crash nem log.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinAberturaDeVagaTest {

    private val modulos = listOf(
        moduloSeguranca, moduloRede, moduloNotificacoes, moduloFeatures, moduloDestinoDaConta,
        module { single<ProvedorDeLocalizacao> { mockk(relaxed = true) } },
    )

    private fun servicoDeVagas(): ServicoVagas {
        val preenchida = mockk<VagaDto> {
            every { estado } returns "preenchida"
            every { posicoesAbertas } returns 0
            every { modo } returns "selecao"
        }
        val recusada = CandidaturaDto(
            id = "c1",
            vaga = VagaResumoDto("v1", "Garçom", "CLS 405 Bloco C", "Plano Piloto", "2026-12-01T21:00:00Z", "2026-12-02T03:00:00Z", 16_000),
            estado = "recusada",
            criadaEm = "2026-11-17T12:00:00Z",
        )
        return mockk {
            coEvery { detalheVaga("v1") } returns preenchida
            coEvery { minhasCandidaturas(any()) } returns listOf(recusada)
        }
    }

    @Test
    fun `a abertura de vaga do grafo le a candidatura e leva a recusada a tela`() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val app = koinApplication { modules(modulos + module { single { servicoDeVagas() } }) }
        try {
            val viewModel = app.koin.get<AberturaDeVagaViewModel> { parametersOf("v1") }

            viewModel.carregar()

            val estado = viewModel.estado.value as EstadoAberturaDeVaga.Indisponivel
            assertEquals(EstadoCandidatura.RECUSADA, estado.candidatura, "sem o registro passar minhas_candidaturas, a recusa some")
        } finally {
            app.close()
            Dispatchers.resetMain()
        }
    }
}
