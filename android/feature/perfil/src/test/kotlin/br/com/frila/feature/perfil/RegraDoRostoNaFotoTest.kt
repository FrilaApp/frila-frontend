package br.com.frila.feature.perfil

import br.com.frila.feature.perfil.MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL
import br.com.frila.feature.perfil.MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS
import br.com.frila.feature.perfil.MotivoDeBloqueioLocal.ROSTO_NAO_ENCONTRADO
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.CancellationException
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

/** L1-3a: a foto de perfil do profissional exige exatamente um rosto, e a conferência falha fechada (como o iOS). */
class RegraDoRostoNaFotoTest {

    private val liberada = ResultadoDaVerificacaoLocal.Liberada
    private fun bloqueada(m: MotivoDeBloqueioLocal) = ResultadoDaVerificacaoLocal.Bloqueada(m)

    @Test
    fun `um rosto que ocupa uma boa parte da foto libera`() {
        assertEquals(liberada, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(600, 700)), 1600, 1600))
    }

    @Test
    fun `nenhum rosto nao libera`() {
        assertEquals(bloqueada(ROSTO_NAO_ENCONTRADO), RegraDoRostoNaFoto.decidir(emptyList(), 1600, 1600))
    }

    @Test
    fun `mais de um rosto nao libera, o perfil e individual`() {
        val dois = listOf(RostoDetectado(600, 700), RostoDetectado(500, 600))
        assertEquals(bloqueada(MULTIPLOS_ROSTOS), RegraDoRostoNaFoto.decidir(dois, 1600, 1600))
    }

    @Test
    fun `rosto minusculo de fundo conta como rosto nao encontrado, abaixo de 1 por cento da area`() {
        // 1% de 1600 x 1600 = 25.600 px²: 159 x 159 = 25.281 fica abaixo; 160 x 160 = 25.600 já vale.
        assertEquals(bloqueada(ROSTO_NAO_ENCONTRADO), RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(159, 159)), 1600, 1600))
        assertEquals(liberada, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(160, 160)), 1600, 1600))
    }

    @Test
    fun `foto sem area nao tem rosto valido`() {
        assertEquals(bloqueada(ROSTO_NAO_ENCONTRADO), RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(10, 10)), 0, 0))
    }

    @Test
    fun `a area minima e de 1 por cento, como no iOS`() {
        assertEquals(0.01, RegraDoRostoNaFoto.AREA_MINIMA)
    }

    // ---- Falha fechada ----

    @Test
    fun `analise que termina no prazo devolve o resultado dela`() = runBlocking {
        assertEquals(liberada, RegraDoRostoNaFoto.comFalhaFechada(1_000) { liberada })
        assertEquals(bloqueada(MULTIPLOS_ROSTOS), RegraDoRostoNaFoto.comFalhaFechada(1_000) { bloqueada(MULTIPLOS_ROSTOS) })
    }

    @Test
    fun `prazo estourado bloqueia como analise indisponivel, mesmo que a analise ignore o cancelamento`() = runBlocking {
        val nuncaTermina = CompletableDeferred<ResultadoDaVerificacaoLocal>()

        // `withTimeout` do teste: se a regra não impuser o prazo, o teste falha em vez de travar o gradle.
        val resultado = withTimeout(5_000) { RegraDoRostoNaFoto.comFalhaFechada(prazoMs = 50) { nuncaTermina.await() } }

        assertEquals(bloqueada(ANALISE_INDISPONIVEL), resultado)
    }

    @Test
    fun `erro da analise bloqueia como analise indisponivel, nunca libera`() = runBlocking {
        val resultado = RegraDoRostoNaFoto.comFalhaFechada(1_000) { throw IllegalStateException("modelo não carregou") }

        assertEquals(bloqueada(ANALISE_INDISPONIVEL), resultado)
    }

    @Test
    fun `cancelar quem chamou propaga o cancelamento e nao vira bloqueio`() {
        assertThrows(CancellationException::class.java) {
            runBlocking { RegraDoRostoNaFoto.comFalhaFechada(1_000) { throw CancellationException("tela fechou") } }
        }
    }
}
