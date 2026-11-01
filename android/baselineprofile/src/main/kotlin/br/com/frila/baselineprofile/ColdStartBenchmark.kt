package br.com.frila.baselineprofile

import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Benchmark de medição de inicialização a frio (cold start) (Cartão 53, RNF04).
 *
 * Mede o tempo de startup até o primeiro quadro comparando compilação sem perfis
 * vs com Baseline Profiles compilados pelo ART.
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class ColdStartBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun coldStartSemCompilacao() = medirColdStart(CompilationMode.None())

    @Test
    fun coldStartComBaselineProfiles() = medirColdStart(CompilationMode.Partial())

    private fun medirColdStart(compilationMode: CompilationMode) {
        benchmarkRule.measureRepeated(
            packageName = "br.com.frila.app",
            metrics = listOf(StartupTimingMetric()),
            iterations = 5,
            startupMode = StartupMode.COLD,
            compilationMode = compilationMode,
        ) {
            pressHome()
            startActivityAndWait()
        }
    }
}
