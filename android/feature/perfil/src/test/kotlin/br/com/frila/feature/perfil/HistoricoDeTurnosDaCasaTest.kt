package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import java.io.File
import java.nio.file.Files
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * rUFapFEL: o histórico e o extrato da casa. `meus_turnos` sem `estabelecimento_id` devolve lista vazia para conta de contratante
 * (contrato), então a casa lê `listarMeusTurnosDaCasa(id)`. O PDF local é do profissional ("Remunerações", "Profissional:"), então
 * nesta entrega a casa exporta só CSV; o iOS gera os dois lados pelo `/exportar-turnos`, o que aqui fica de fora.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HistoricoDeTurnosDaCasaTest {

    private val testDispatcher = StandardTestDispatcher()
    private val relogio = Clock.fixed(Instant.parse("2026-10-03T15:00:00Z"), ZoneId.of("America/Sao_Paulo"))
    private val servicoTurnos: ServicoTurnos = mockk(relaxed = true)
    private val casa = "casa-1"

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun turno(funcao: String, estado: String = "cumprida", inicioEm: String = "2026-10-02T21:00:00Z") = TurnoDto(
        id = "t-$funcao",
        posicaoId = "posicao-$funcao",
        vaga = VagaResumoDto(
            id = "vaga-$funcao", funcao = funcao, local = "Asa Norte", regiaoAdministrativa = "Brasília",
            inicioEm = inicioEm, fimEm = inicioEm, valorCentavos = 10_000,
        ),
        contraparte = PerfilPublicoDto(id = "p-$funcao", tipo = "profissional", nome = "Ana", reputacao = ReputacaoDto(0, 0, null, 0, 0)),
        verificacao = "verificado",
        valorAcordadoCentavos = 10_000,
        podeAvaliar = false,
        estado = estado,
        checkinEm = null,
        checkoutEm = null,
    )

    private fun viewModelDaCasa(geradorPdf: (File, ResumoFinanceiroPerfil, List<TurnoDto>, String, Instant, String?) -> File = { d, _, _, _, _, _ -> File(d, "x.pdf") }) =
        HistoricoDeTurnosViewModel(servicoTurnos, relogio, geradorPdf, estabelecimentoId = casa)

    /** Exporta no formato que o view model já tem; só escolhe CSV quando [forcarCsv]. */
    private fun TestScope.exportarCsv(vm: HistoricoDeTurnosViewModel, forcarCsv: Boolean = true): String? {
        val pasta = Files.createTempDirectory("extrato-casa").toFile()
        try {
            if (forcarCsv) vm.escolher(FormatoExportacao.CSV)
            vm.exportar(pasta)
            advanceUntilIdle()
            return vm.estado.value.arquivoParaCompartilhar?.readText()
        } finally {
            pasta.deleteRecursively()
        }
    }

    @Test
    fun `a casa le os turnos da casa pelo id e nao le meus_turnos sem o id`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnosDaCasa(casa) } returns listOf(turno("Garcom"))

        exportarCsv(viewModelDaCasa())

        coVerify(exactly = 1) { servicoTurnos.listarMeusTurnosDaCasa(casa) }
        coVerify(exactly = 0) { servicoTurnos.listarMeusTurnos() }
    }

    @Test
    fun `sem o id da casa o profissional continua lendo meus_turnos e nunca os da casa`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnos() } returns listOf(turno("Garcom"))

        exportarCsv(HistoricoDeTurnosViewModel(servicoTurnos, relogio))

        coVerify(exactly = 1) { servicoTurnos.listarMeusTurnos() }
        coVerify(exactly = 0) { servicoTurnos.listarMeusTurnosDaCasa(any()) }
    }

    @Test
    fun `o CSV da casa traz os turnos cumpridos e confirmados da casa, com o mesmo filtro do profissional`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnosDaCasa(casa) } returns listOf(
            turno("Cumprido", "cumprida"),
            turno("Confirmado", "confirmada"),
            turno("Cancelado", "cancelada"),
            turno("ForaDoPeriodo", "cumprida", inicioEm = "2026-09-10T15:00:00Z"),
        )

        val csv = exportarCsv(viewModelDaCasa())!!

        assertTrue(csv.contains("Cumprido") && csv.contains("Confirmado"))
        assertFalse(csv.contains("Cancelado"))
        assertFalse(csv.contains("ForaDoPeriodo"))
    }

    @Test
    fun `casa sem turnos no periodo cai em sem turnos e nao gera arquivo`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnosDaCasa(casa) } returns emptyList()
        val vm = viewModelDaCasa()

        exportarCsv(vm)

        assertEquals(EstadoHistorico.SemTurnos, vm.estado.value.estado)
        assertEquals(null, vm.estado.value.arquivoParaCompartilhar)
    }

    @Test
    fun `quem nao e membro da casa recebe sem permissao, sem repetir`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnosDaCasa(casa) } throws ErroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", null, "x")
        val vm = viewModelDaCasa()

        exportarCsv(vm)

        val erro = vm.estado.value.estado as EstadoHistorico.Erro
        assertEquals(TextosHistoricoDeTurnos.SEM_PERMISSAO, erro.mensagem)
        assertFalse(erro.repetivel)
    }

    @Test
    fun `a casa so tem o CSV e escolher PDF nao muda o formato, o profissional tem os dois`() = runTest {
        val casaVm = viewModelDaCasa()
        assertEquals(listOf(FormatoExportacao.CSV), casaVm.formatosDisponiveis)
        casaVm.escolher(FormatoExportacao.PDF)
        assertEquals(FormatoExportacao.CSV, casaVm.estado.value.formato)

        val profissional = HistoricoDeTurnosViewModel(servicoTurnos, relogio)
        assertEquals(listOf(FormatoExportacao.CSV, FormatoExportacao.PDF), profissional.formatosDisponiveis)
        profissional.escolher(FormatoExportacao.PDF)
        assertEquals(FormatoExportacao.PDF, profissional.estado.value.formato)
    }

    @Test
    fun `o PDF do profissional nunca e gerado para a casa`() = runTest {
        coEvery { servicoTurnos.listarMeusTurnosDaCasa(casa) } returns listOf(turno("Garcom"))
        var geradoPdf = false
        val vm = viewModelDaCasa(geradorPdf = { d, _, _, _, _, _ -> geradoPdf = true; File(d, "x.pdf") })

        vm.escolher(FormatoExportacao.PDF)
        exportarCsv(vm, forcarCsv = false)

        assertFalse("o PDF do profissional nao pode sair para a casa", geradoPdf)
    }
}
