package br.com.frila.feature.perfil

import br.com.frila.feature.perfil.MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL
import br.com.frila.feature.perfil.MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS
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
    private val aviso = ResultadoDaVerificacaoLocal.AvisoSemRosto
    private fun bloqueada(m: MotivoDeBloqueioLocal) = ResultadoDaVerificacaoLocal.Bloqueada(m)

    @Test
    fun `um rosto que ocupa uma boa parte da foto libera`() {
        assertEquals(liberada, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(600, 700)), 1600, 1600))
    }

    @Test
    fun `nenhum rosto so avisa, nao bloqueia`() {
        assertEquals(aviso, RegraDoRostoNaFoto.decidir(emptyList(), 1600, 1600))
    }

    @Test
    fun `mais de um rosto nao libera, o perfil e individual`() {
        val dois = listOf(RostoDetectado(600, 700), RostoDetectado(500, 600))
        assertEquals(bloqueada(MULTIPLOS_ROSTOS), RegraDoRostoNaFoto.decidir(dois, 1600, 1600))
    }

    @Test
    fun `rosto minusculo de fundo so avisa, abaixo de 1 por cento da area`() {
        // 1% de 1600 x 1600 = 25.600 px²: 159 x 159 = 25.281 fica abaixo; 160 x 160 = 25.600 já vale.
        assertEquals(aviso, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(159, 159)), 1600, 1600))
        assertEquals(liberada, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(160, 160)), 1600, 1600))
    }

    @Test
    fun `foto sem area nao tem rosto valido`() {
        assertEquals(aviso, RegraDoRostoNaFoto.decidir(listOf(RostoDetectado(10, 10)), 0, 0))
    }

    @Test
    fun `a area minima e de 1 por cento, como no iOS`() {
        assertEquals(0.01, RegraDoRostoNaFoto.AREA_MINIMA)
    }

    // ---- Retentativa (foto girada ou reduzida) antes do aviso ----

    @Test
    fun `se a primeira analise acha um rosto, as retentativas nem rodam`() = runBlocking {
        var rodou = false
        val resultado = RegraDoRostoNaFoto.comRetentativas({ liberada }, listOf({ rodou = true; liberada }))
        assertEquals(liberada, resultado)
        assertEquals(false, rodou)
    }

    @Test
    fun `mais de um rosto na primeira analise bloqueia sem tentar de novo`() = runBlocking {
        var rodou = false
        val resultado = RegraDoRostoNaFoto.comRetentativas({ bloqueada(MULTIPLOS_ROSTOS) }, listOf({ rodou = true; liberada }))
        assertEquals(bloqueada(MULTIPLOS_ROSTOS), resultado)
        assertEquals(false, rodou)
    }

    @Test
    fun `sem rosto na primeira, a retentativa que acha um rosto libera`() = runBlocking {
        val ordem = mutableListOf<String>()
        val resultado = RegraDoRostoNaFoto.comRetentativas(
            { ordem += "original"; aviso },
            listOf({ ordem += "reduzida"; aviso }, { ordem += "girada"; liberada }, { ordem += "outra"; liberada }),
        )
        assertEquals(liberada, resultado)
        assertEquals(listOf("original", "reduzida", "girada"), ordem)
    }

    @Test
    fun `rosto inventado pela foto girada nunca bloqueia, so a primeira analise bloqueia`() = runBlocking {
        val resultado = RegraDoRostoNaFoto.comRetentativas({ aviso }, listOf({ bloqueada(MULTIPLOS_ROSTOS) }, { aviso }))
        assertEquals(aviso, resultado)
    }

    @Test
    fun `sem rosto em nenhuma tentativa so avisa`() = runBlocking {
        assertEquals(aviso, RegraDoRostoNaFoto.comRetentativas({ aviso }, listOf({ aviso }, { aviso })))
        assertEquals(aviso, RegraDoRostoNaFoto.comRetentativas({ aviso }, emptyList()))
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
