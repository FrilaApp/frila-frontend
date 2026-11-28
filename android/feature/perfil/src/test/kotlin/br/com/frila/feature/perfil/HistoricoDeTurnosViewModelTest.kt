package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
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
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HistoricoDeTurnosViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val fusoSaoPaulo = ZoneId.of("America/Sao_Paulo")
    // 03/10/2026 12:00 BRT (15:00 UTC)
    private val instantePadrao = Instant.parse("2026-10-03T15:00:00Z")
    private val relogioPadrao = Clock.fixed(instantePadrao, fusoSaoPaulo)

    private val servicoTurnos: ServicoTurnos = mockk(relaxed = true)

    private fun criarTurno(
        id: String,
        inicioEm: String,
        estado: String = "cumprida",
        funcao: String = "Garçom",
        contraparte: String = "Bistrô Ipê",
        valorAcordadoCentavos: Long = 18000,
        checkinEm: String? = "2026-10-03T21:02:00Z",
        checkoutEm: String? = "2026-10-04T02:05:00Z",
        verificacao: String = "verificado",
    ) = TurnoDto(
        id = id,
        posicaoId = "posicao-$id",
        vaga = VagaResumoDto(
            id = "vaga-$id",
            funcao = funcao,
            local = "Asa Norte",
            regiaoAdministrativa = "Brasília",
            inicioEm = inicioEm,
            fimEm = inicioEm,
            valorCentavos = valorAcordadoCentavos,
        ),
        contraparte = PerfilPublicoDto(
            id = "c-$id",
            tipo = "estabelecimento",
            nome = contraparte,
            reputacao = ReputacaoDto(0, 0, null, 0, 0),
        ),
        verificacao = verificacao,
        valorAcordadoCentavos = valorAcordadoCentavos,
        podeAvaliar = false,
        estado = estado,
        checkinEm = checkinEm,
        checkoutEm = checkoutEm,
    )

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun nomeDoArquivoSeguePadraoComExtensao() {
        val periodo = PeriodoDeExportacao(LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31))
        assertEquals("frila-turnos-2026-10-01_2026-10-31.csv", HistoricoDeTurnosViewModel.nomeDoArquivo(periodo, FormatoExportacao.CSV))
        assertEquals("frila-turnos-2026-10-01_2026-10-31.pdf", HistoricoDeTurnosViewModel.nomeDoArquivo(periodo, FormatoExportacao.PDF))
    }

    @Test
    fun atalhoEsteMesCobreDoDiaUmAteHoje() {
        val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
        val periodo = vm.estado.value.periodoEscolhido
        assertNotNull(periodo)
        assertEquals(LocalDate.of(2026, 10, 1), periodo?.de)
        assertEquals(LocalDate.of(2026, 10, 3), periodo?.ate)
        assertFalse(vm.estado.value.excedeLimite)
        assertTrue(vm.estado.value.periodoValido)
    }

    @Test
    fun atalhoMesPassadoCobreMesAnteriorInteiro() {
        val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
        vm.escolher(AtalhoHistorico.MES_PASSADO)
        val periodo = vm.estado.value.periodoEscolhido
        assertNotNull(periodo)
        assertEquals(LocalDate.of(2026, 9, 1), periodo?.de)
        assertEquals(LocalDate.of(2026, 9, 30), periodo?.ate)
        assertEquals(30L, periodo?.dias)
        assertFalse(vm.estado.value.excedeLimite)
    }

    @Test
    fun limiteDeTrintaDiasExcedido() {
        val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
        vm.escolher(AtalhoHistorico.INTERVALO)
        // 04/09 a 03/10 = 27 dias em set + 3 dias em out = 30 dias
        vm.escolherInicio(LocalDate.of(2026, 9, 4))
        vm.escolherFim(LocalDate.of(2026, 10, 3))
        assertFalse(vm.estado.value.excedeLimite)
        assertTrue(vm.estado.value.periodoValido)

        // 03/09 a 03/10 = 31 dias -> excedeLimite
        vm.escolherInicio(LocalDate.of(2026, 9, 3))
        assertTrue(vm.estado.value.excedeLimite)
        assertFalse(vm.estado.value.periodoValido)

        // Em novembro, o mês passado (outubro) tem 31 dias -> excedeLimite
        val relogioNovembro = Clock.fixed(Instant.parse("2026-11-03T15:00:00Z"), fusoSaoPaulo)
        val vmNovembro = HistoricoDeTurnosViewModel(servicoTurnos, relogioNovembro)
        vmNovembro.escolher(AtalhoHistorico.MES_PASSADO)
        assertTrue(vmNovembro.estado.value.excedeLimite)
        assertFalse(vmNovembro.estado.value.periodoValido)
    }

    @Test
    fun regraDeLimitesAjustaDatas() {
        val hoje = LocalDate.of(2026, 10, 3)
        // Puxar fim para antes do início leva o início junto
        val ajustadoFim = RegraDeLimites.ajustarAoMudarFim(
            fim = LocalDate.of(2026, 9, 10),
            inicioAtual = LocalDate.of(2026, 9, 20),
            hoje = hoje,
        )
        assertEquals(LocalDate.of(2026, 9, 10), ajustadoFim.first)
        assertEquals(LocalDate.of(2026, 9, 10), ajustadoFim.second)

        // Puxar início para depois do fim leva o fim junto
        val ajustadoInicio = RegraDeLimites.ajustarAoMudarInicio(
            inicio = LocalDate.of(2026, 9, 20),
            fimAtual = LocalDate.of(2026, 9, 10),
            hoje = hoje,
        )
        assertEquals(LocalDate.of(2026, 9, 20), ajustadoInicio.first)
        assertEquals(LocalDate.of(2026, 9, 20), ajustadoInicio.second)

        // Data futura limitada a hoje
        val futuro = RegraDeLimites.ajustarAoMudarFim(
            fim = LocalDate.of(2026, 10, 15),
            inicioAtual = LocalDate.of(2026, 10, 1),
            hoje = hoje,
        )
        assertEquals(hoje, futuro.second)
    }

    @Test
    fun exportarCsvGeraArquivoLocal() = runTest {
        val tempDir = Files.createTempDirectory("teste-exportar-csv").toFile()
        try {
            val turno1 = criarTurno("t1", "2026-10-02T21:00:00Z", funcao = "=Garçom", contraparte = "Bistrô Ipê")
            val turno2 = criarTurno("t2", "2026-10-03T21:00:00Z", funcao = "Bartender", contraparte = "Café Central")
            coEvery { servicoTurnos.listarMeusTurnos() } returns listOf(turno1, turno2)

            val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
            vm.escolher(FormatoExportacao.CSV)

            vm.exportar(tempDir)
            advanceUntilIdle()

            assertEquals(EstadoHistorico.Ocioso, vm.estado.value.estado)
            val arquivo = vm.estado.value.arquivoParaCompartilhar
            assertNotNull(arquivo)
            assertTrue(arquivo!!.exists())
            assertEquals("frila-turnos-2026-10-01_2026-10-03.csv", arquivo.name)

            val conteudo = arquivo.readText()
            assertTrue(conteudo.startsWith("data,funcao,checkin,checkout,valor_acordado,contraparte,verificacao\n"))
            assertTrue(conteudo.contains("'=Garçom"))
            assertTrue(conteudo.contains("Bartender"))
            assertTrue(conteudo.contains("180,00"))

            vm.limparArquivoParaCompartilhar()
            assertNull(vm.estado.value.arquivoParaCompartilhar)
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun exportarPdfGeraArquivoFisico() = runTest {
        val tempDir = Files.createTempDirectory("teste-exportar-pdf").toFile()
        try {
            val turno = criarTurno("t1", "2026-10-02T21:00:00Z")
            coEvery { servicoTurnos.listarMeusTurnos() } returns listOf(turno)

            val vm = HistoricoDeTurnosViewModel(
                servicoTurnos = servicoTurnos,
                relogio = relogioPadrao,
                geradorPdf = { dir, _, _, _, _, nomeArq ->
                    File(dir, nomeArq ?: "extrato.pdf").apply { writeText("%PDF-1.4 teste") }
                },
            )
            vm.escolher(FormatoExportacao.PDF)

            vm.exportar(tempDir, "João Silva")
            advanceUntilIdle()

            assertEquals(EstadoHistorico.Ocioso, vm.estado.value.estado)
            val arquivo = vm.estado.value.arquivoParaCompartilhar
            assertNotNull(arquivo)
            assertTrue(arquivo!!.exists())
            assertEquals("frila-turnos-2026-10-01_2026-10-03.pdf", arquivo.name)
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun semTurnosNoPeriodoResultaEmEstadoSemTurnos() = runTest {
        val tempDir = Files.createTempDirectory("teste-sem-turnos").toFile()
        try {
            val turnoFora = criarTurno("t0", "2026-09-15T21:00:00Z")
            coEvery { servicoTurnos.listarMeusTurnos() } returns listOf(turnoFora)

            val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
            vm.exportar(tempDir)
            advanceUntilIdle()

            assertEquals(EstadoHistorico.SemTurnos, vm.estado.value.estado)
            assertNull(vm.estado.value.arquivoParaCompartilhar)

            vm.escolher(AtalhoHistorico.MES_PASSADO)
            assertEquals(EstadoHistorico.Ocioso, vm.estado.value.estado)
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun tratamentoDeErrosMapeiaRepetibilidade() = runTest {
        val tempDir = Files.createTempDirectory("teste-erros").toFile()
        try {
            coEvery { servicoTurnos.listarMeusTurnos() } throws ErroDaApi(
                codigo = CodigoErroAPI.NAO_AUTENTICADO,
                codigoOriginal = "nao_autenticado",
                detalhes = "Sessão expirada",
                mensagemCrua = "Sessão expirada",
            )
            val vm1 = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
            vm1.exportar(tempDir)
            advanceUntilIdle()
            val estado1 = vm1.estado.value.estado
            assertTrue(estado1 is EstadoHistorico.Erro)
            assertFalse((estado1 as EstadoHistorico.Erro).repetivel)

            coEvery { servicoTurnos.listarMeusTurnos() } throws RuntimeException("Falha de rede")
            val vm2 = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
            vm2.exportar(tempDir)
            advanceUntilIdle()
            val estado2 = vm2.estado.value.estado
            assertTrue(estado2 is EstadoHistorico.Erro)
            assertTrue((estado2 as EstadoHistorico.Erro).repetivel)

            vm2.escolher(FormatoExportacao.PDF)
            assertEquals(EstadoHistorico.Ocioso, vm2.estado.value.estado)
        } finally {
            tempDir.deleteRecursively()
        }
    }

    /** AMKlGp1o: o `message` do ErroDaApi é o texto de depuração e nunca vai à tela; cada recusa tem o texto do iOS. */
    @Test
    fun recusaDaApiNaExportacaoMostraOTextoDoIosENuncaODeDepuracao() = runTest {
        val tempDir = Files.createTempDirectory("teste-erros-texto").toFile()
        try {
            val casos = listOf(
                Triple(CodigoErroAPI.SEM_REDE, "sem_rede", TextosHistoricoDeTurnos.SEM_REDE to true),
                Triple(CodigoErroAPI.NAO_AUTENTICADO, "nao_autenticado", TextosHistoricoDeTurnos.SESSAO_EXPIRADA to false),
                Triple(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", TextosHistoricoDeTurnos.SEM_PERMISSAO to false),
                Triple(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", TextosHistoricoDeTurnos.SEM_PERMISSAO to true),
                Triple(CodigoErroAPI.LIMITE_EXCEDIDO, "limite_excedido", TextosHistoricoDeTurnos.LIMITE_EXCEDIDO to true),
                Triple(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado", TextosHistoricoDeTurnos.ERRO_DESCONHECIDO to true),
                Triple(CodigoErroAPI.DESCONHECIDO, "algo_novo", TextosHistoricoDeTurnos.ERRO_DESCONHECIDO to true),
            )
            for ((codigo, original, esperado) in casos) {
                val erro = ErroDaApi(codigo = codigo, codigoOriginal = original, detalhes = null, mensagemCrua = "corpo cru do servidor")
                coEvery { servicoTurnos.listarMeusTurnos() } throws erro
                val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
                vm.exportar(tempDir)
                advanceUntilIdle()

                val estado = vm.estado.value.estado as EstadoHistorico.Erro
                assertEquals(original, esperado.first, estado.mensagem)
                assertEquals(original, esperado.second, estado.repetivel)
                assertFalse("$original: o texto de depuração chegou ao estado", vm.estado.value.toString().contains("ErroDaApi("))
                assertFalse(original, estado.mensagem.contains("corpo cru"))
            }
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun limparArquivosAntigosRemoveApenasRelatorios() {
        val tempDir = Files.createTempDirectory("teste-limpeza").toFile()
        try {
            val antigoCsv = File(tempDir, "frila-turnos-2026-09-01_2026-09-30.csv").apply { writeText("antigo") }
            val antigoPdf = File(tempDir, "frila-turnos-2026-09-01_2026-09-30.pdf").apply { writeText("antigo") }
            val alheio = File(tempDir, "outro-arquivo.txt").apply { writeText("nao mexer") }

            val vm = HistoricoDeTurnosViewModel(servicoTurnos, relogioPadrao)
            vm.limparArquivosAntigos(tempDir)

            assertFalse(antigoCsv.exists())
            assertFalse(antigoPdf.exists())
            assertTrue(alheio.exists())
        } finally {
            tempDir.deleteRecursively()
        }
    }
}
