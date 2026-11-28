package br.com.frila.feature.perfil

import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import io.mockk.coEvery
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
 * Op6iZHX8: o filtro do extrato (CSV) e o resumo do PDF. Entram só os turnos cumpridos e confirmados, pelo dia do início em
 * São Paulo, com as duas pontas do período incluídas. O turno de `HistoricoDeTurnosViewModelTest` nasce sempre `cumprida` e as
 * datas dele nunca encostam nas pontas, então esses limites ficavam sem cobertura. O período é o do atalho "este mês" com o
 * relógio em 03/10/2026 12:00 BRT: de 01/10 a 03/10.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HistoricoDeTurnosFiltroDoExtratoTest {

    private val testDispatcher = StandardTestDispatcher()
    private val relogio = Clock.fixed(Instant.parse("2026-10-03T15:00:00Z"), ZoneId.of("America/Sao_Paulo"))
    private val servicoTurnos: ServicoTurnos = mockk(relaxed = true)

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** Cada turno leva uma função própria, que é como o teste o reconhece no CSV. */
    private fun turno(funcao: String, inicioEm: String, estado: String = "cumprida", valor: Long = 10_000) = TurnoDto(
        id = "t-$funcao",
        posicaoId = "posicao-$funcao",
        vaga = VagaResumoDto(
            id = "vaga-$funcao", funcao = funcao, local = "Asa Norte", regiaoAdministrativa = "Brasília",
            inicioEm = inicioEm, fimEm = inicioEm, valorCentavos = valor,
        ),
        contraparte = PerfilPublicoDto(id = "c-$funcao", tipo = "estabelecimento", nome = "Bistrô Ipê", reputacao = ReputacaoDto(0, 0, null, 0, 0)),
        verificacao = "verificado",
        valorAcordadoCentavos = valor,
        podeAvaliar = false,
        estado = estado,
        checkinEm = null,
        checkoutEm = null,
    )

    /** As funções que o CSV gerado para o período contém. */
    private fun TestScope.funcoesNoCsv(vararg turnos: TurnoDto): Set<String> {
        val pasta = Files.createTempDirectory("extrato-csv").toFile()
        try {
            coEvery { servicoTurnos.listarMeusTurnos() } returns turnos.toList()
            val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogio)
            vm.escolher(FormatoExportacao.CSV)
            vm.exportar(pasta)
            advanceUntilIdle()
            val arquivo = vm.estado.value.arquivoParaCompartilhar ?: return emptySet()
            return turnos.map { it.vaga.funcao }.filter { arquivo.readText().contains(it) }.toSet()
        } finally {
            pasta.deleteRecursively()
        }
    }

    private class PdfCapturado(val resumo: ResumoFinanceiroPerfil, val turnos: List<TurnoDto>)

    /** O que o PDF recebe: o resumo e a lista já filtrada, sem desenhar nada. */
    private fun TestScope.pdfPara(vararg turnos: TurnoDto): PdfCapturado? {
        val pasta = Files.createTempDirectory("extrato-pdf").toFile()
        var capturado: PdfCapturado? = null
        try {
            coEvery { servicoTurnos.listarMeusTurnos() } returns turnos.toList()
            val vm = HistoricoDeTurnosViewModel(
                servicoTurnos, relogio,
                geradorPdf = { dir, resumo, lista, _, _, nome ->
                    capturado = PdfCapturado(resumo, lista)
                    File(dir, nome ?: "extrato.pdf").also { it.writeText("") }
                },
            )
            vm.escolher(FormatoExportacao.PDF)
            vm.exportar(pasta)
            advanceUntilIdle()
            return capturado
        } finally {
            pasta.deleteRecursively()
        }
    }

    @Test
    fun `so os turnos cumpridos e confirmados entram no CSV, o cancelado fica de fora`() = runTest {
        val noCsv = funcoesNoCsv(
            turno("Cumprido", "2026-10-02T21:00:00Z", estado = "cumprida"),
            turno("Confirmado", "2026-10-02T22:00:00Z", estado = "confirmada"),
            turno("Cancelado", "2026-10-02T23:00:00Z", estado = "cancelada"),
        )

        assertEquals(setOf("Cumprido", "Confirmado"), noCsv)
    }

    @Test
    fun `o cancelado tambem fica fora da lista que vai ao PDF`() = runTest {
        val pdf = pdfPara(
            turno("Cumprido", "2026-10-02T21:00:00Z", estado = "cumprida"),
            turno("Cancelado", "2026-10-02T23:00:00Z", estado = "cancelada", valor = 50_000),
        )!!

        assertEquals(listOf("Cumprido"), pdf.turnos.map { it.vaga.funcao })
    }

    @Test
    fun `a ponta inicial do periodo entra e o dia anterior em Sao Paulo nao, e os dias do meio entram`() = runTest {
        // 01/10 00:00:00 em Sao Paulo (03:00Z) entra; 30/09 23:59:59 (02:59:59Z de 01/10) fica fora.
        val noCsv = funcoesNoCsv(
            turno("PrimeiroInstante", "2026-10-01T03:00:00Z"),
            turno("DiaAnterior", "2026-10-01T02:59:59Z"),
            turno("Meio", "2026-10-02T15:00:00Z"),
        )

        assertEquals(setOf("PrimeiroInstante", "Meio"), noCsv)
    }

    @Test
    fun `a ponta final do periodo entra e o dia seguinte em Sao Paulo nao`() = runTest {
        // 03/10 23:59:59 em Sao Paulo (02:59:59Z de 04/10) entra; 04/10 00:00:00 (03:00Z) fica fora.
        val noCsv = funcoesNoCsv(
            turno("UltimoInstante", "2026-10-04T02:59:59Z"),
            turno("DiaSeguinte", "2026-10-04T03:00:00Z"),
        )

        assertEquals(setOf("UltimoInstante"), noCsv)
    }

    @Test
    fun `o dia do turno e o de Sao Paulo e nao o do UTC, nas duas pontas`() = runTest {
        // 01:30Z de 01/10 e 30/09 22:30 em Sao Paulo (fora); 01:30Z de 04/10 e 03/10 22:30 em Sao Paulo (dentro).
        val noCsv = funcoesNoCsv(
            turno("UtcDiaUmSpDiaAnterior", "2026-10-01T01:30:00Z"),
            turno("UtcDiaQuatroSpDiaTres", "2026-10-04T01:30:00Z"),
        )

        assertEquals(setOf("UtcDiaQuatroSpDiaTres"), noCsv)
        assertFalse(noCsv.contains("UtcDiaUmSpDiaAnterior"))
    }

    @Test
    fun `o resumo do PDF soma so os cumpridos como concluido e so os confirmados como pendente, sem o cancelado`() = runTest {
        val pdf = pdfPara(
            turno("CumpridoA", "2026-10-02T21:00:00Z", estado = "cumprida", valor = 18_000),
            turno("CumpridoB", "2026-10-02T22:00:00Z", estado = "cumprida", valor = 9_000),
            turno("Confirmado", "2026-10-03T15:00:00Z", estado = "confirmada", valor = 12_000),
            turno("Cancelado", "2026-10-03T16:00:00Z", estado = "cancelada", valor = 50_000),
            turno("ForaDoPeriodo", "2026-09-20T15:00:00Z", estado = "cumprida", valor = 70_000),
        )!!

        assertEquals(27_000L, pdf.resumo.totalConcluidoCentavos)
        assertEquals(12_000L, pdf.resumo.totalPendenteCentavos)
        assertEquals(2, pdf.resumo.turnosCumpridosQtd)
        assertEquals(1, pdf.resumo.turnosAgendadosQtd)
        assertEquals(3, pdf.turnos.size)
        assertTrue(pdf.turnos.none { it.vaga.funcao == "Cancelado" || it.vaga.funcao == "ForaDoPeriodo" })
    }
}
